import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/fitness.dart';
import '../models/models.dart';
import '../services/cloud_sync.dart';
import '../services/energy.dart';
import '../services/nutrition.dart';

enum SyncStatus { off, syncing, synced, offline }

/// All app data. Saved on the device (phone or browser storage) and, when
/// signed in, copied to the cloud so it is safe and shared across devices.
class AppState extends ChangeNotifier {
  static const _kProfile = 'profile';
  static const _kLog = 'log';
  static const _kMyFoods = 'my_foods';
  static const _kSetupDone = 'setup_done';
  static const _kWorkouts = 'workouts';
  static const _kPlan = 'weekly_plan';
  static const _kCheckIns = 'check_ins';
  static const _kQueue = 'sync_queue';
  static const _kOwner = 'data_owner';

  SharedPreferences? _prefs;

  Profile _profile = const Profile();
  final List<LogEntry> _log = [];
  final List<Food> _myFoods = [];
  bool _setupDone = false;
  bool _loaded = false;
  final List<WorkoutEntry> _workouts = [];
  WeeklyPlan _plan = WeeklyPlan();
  final Map<String, DayCheckIn> _checkIns = {};

  // Cloud sync
  CloudBackend? _cloud;
  final Map<String, CloudRecord> _queue = {};
  Timer? _flushTimer;
  SyncStatus _syncStatus = SyncStatus.off;
  DateTime? _lastSynced;

  SyncStatus get syncStatus => _syncStatus;
  DateTime? get lastSynced => _lastSynced;
  int get pendingChanges => _queue.length;

  Profile get profile => _profile;
  bool get setupDone => _setupDone;
  bool get loaded => _loaded;
  List<Food> get myFoods => List.unmodifiable(_myFoods);
  DailyTargets get targets => targetsFor(_profile);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    final profileJson = p.getString(_kProfile);
    if (profileJson != null) {
      _profile = Profile.fromJson(jsonDecode(profileJson) as Map<String, dynamic>);
    }
    final logJson = p.getString(_kLog);
    if (logJson != null) {
      _log
        ..clear()
        ..addAll((jsonDecode(logJson) as List)
            .map((e) => LogEntry.fromJson(e as Map<String, dynamic>)));
    }
    final foodsJson = p.getString(_kMyFoods);
    if (foodsJson != null) {
      _myFoods
        ..clear()
        ..addAll((jsonDecode(foodsJson) as List)
            .map((e) => Food.fromJson(e as Map<String, dynamic>)));
    }
    _setupDone = p.getBool(_kSetupDone) ?? false;
    final workoutsJson = p.getString(_kWorkouts);
    if (workoutsJson != null) {
      _workouts
        ..clear()
        ..addAll((jsonDecode(workoutsJson) as List)
            .map((e) => WorkoutEntry.fromJson(e as Map<String, dynamic>)));
    }
    final planJson = p.getString(_kPlan);
    if (planJson != null) {
      _plan = WeeklyPlan.fromJson(jsonDecode(planJson) as Map<String, dynamic>);
    }
    final checkJson = p.getString(_kCheckIns);
    if (checkJson != null) {
      _checkIns
        ..clear()
        ..addEntries((jsonDecode(checkJson) as List)
            .map((e) => DayCheckIn.fromJson(e as Map<String, dynamic>))
            .map((c) => MapEntry(c.day, c)));
    }
    final queueJson = p.getString(_kQueue);
    if (queueJson != null) {
      for (final e in jsonDecode(queueJson) as List) {
        final r = CloudRecord.fromJson(e as Map<String, dynamic>);
        _queue[r.key] = r;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kProfile, jsonEncode(_profile.toJson()));
    await p.setString(_kLog, jsonEncode(_log.map((e) => e.toJson()).toList()));
    await p.setString(_kMyFoods, jsonEncode(_myFoods.map((e) => e.toJson()).toList()));
    await p.setBool(_kSetupDone, _setupDone);
    await p.setString(_kWorkouts, jsonEncode(_workouts.map((e) => e.toJson()).toList()));
    await p.setString(_kPlan, jsonEncode(_plan.toJson()));
    await p.setString(_kCheckIns, jsonEncode(_checkIns.values.map((e) => e.toJson()).toList()));
    await p.setString(_kQueue, jsonEncode(_queue.values.map((e) => e.toJson()).toList()));
  }

  void updateProfile(Profile p, {bool finishSetup = false}) {
    _profile = p;
    if (finishSetup) _setupDone = true;
    _record(_profileRecord());
    notifyListeners();
    _save();
  }

  // ------------------------------------------------------------ Cloud

  CloudRecord _profileRecord() =>
      CloudRecord(kind: 'profile', id: 'me', data: {..._profile.toJson(), 'setupDone': _setupDone});
  CloudRecord _planRecord() => CloudRecord(kind: 'plan', id: 'me', data: _plan.toJson());
  CloudRecord _myFoodsRecord() =>
      CloudRecord(kind: 'myfoods', id: 'me', data: {'items': _myFoods.map((f) => f.toJson()).toList()});

  List<CloudRecord> _allLocalRecords() => [
        if (_setupDone) _profileRecord(),
        if (!_plan.isEmpty) _planRecord(),
        if (_myFoods.isNotEmpty) _myFoodsRecord(),
        for (final e in _log) CloudRecord(kind: 'food', id: e.id, data: e.toJson()),
        for (final w in _workouts) CloudRecord(kind: 'workout', id: w.id, data: w.toJson()),
        for (final c in _checkIns.values) CloudRecord(kind: 'checkin', id: c.day, data: c.toJson()),
      ];

  /// Remember a change so it is uploaded (now if online, later if not).
  void _record(CloudRecord r) {
    if (_cloud == null && _prefs?.getString(_kOwner) == null) return; // never signed in
    _queue[r.key] = r;
    _scheduleFlush();
  }

  void _recordDelete(String kind, String id) =>
      _record(CloudRecord(kind: kind, id: id, deleted: true));

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 1500), flush);
  }

  /// Upload waiting changes. Safe to call any time.
  Future<void> flush() async {
    final cloud = _cloud;
    if (cloud == null || cloud.userId == null || _queue.isEmpty) return;
    final batch = _queue.values.toList();
    _setStatus(SyncStatus.syncing);
    try {
      await cloud.upsert(batch);
      for (final r in batch) {
        // Only clear if not changed again while uploading.
        if (identical(_queue[r.key], r)) _queue.remove(r.key);
      }
      _lastSynced = DateTime.now();
      _setStatus(_queue.isEmpty ? SyncStatus.synced : SyncStatus.syncing);
      await _save();
      if (_queue.isNotEmpty) _scheduleFlush();
    } catch (e) {
      debugPrint('Sync upload failed: $e');
      _setStatus(SyncStatus.offline);
      _flushTimer?.cancel();
      _flushTimer = Timer(const Duration(seconds: 30), flush);
    }
  }

  void _setStatus(SyncStatus s) {
    if (_syncStatus == s) return;
    _syncStatus = s;
    notifyListeners();
  }

  /// Called after sign-in. Brings this device and the cloud in line.
  Future<void> attachCloud(CloudBackend cloud) async {
    final uid = cloud.userId;
    if (uid == null) return;
    _cloud = cloud;
    final owner = _prefs?.getString(_kOwner);
    if (owner != null && owner != uid) {
      // Someone else used this device before: start clean.
      _clearLocal();
    }
    await _prefs?.setString(_kOwner, uid);
    _setStatus(SyncStatus.syncing);
    try {
      await flush();
      final cloudRecords = await cloud.fetchAll();
      final local = _allLocalRecords();
      final merged = mergeRecords(local: local, cloud: cloudRecords);
      _applyRecords(merged.records.values);
      if (merged.toUpload.isNotEmpty) {
        for (final r in merged.toUpload) {
          _queue[r.key] = r;
        }
      }
      await _save();
      notifyListeners();
      await flush();
      _lastSynced = DateTime.now();
      _setStatus(_queue.isEmpty ? SyncStatus.synced : SyncStatus.offline);
    } catch (e) {
      debugPrint('Sync download failed: $e');
      _setStatus(SyncStatus.offline);
    }
  }

  void _applyRecords(Iterable<CloudRecord> records) {
    _log.clear();
    _workouts.clear();
    _checkIns.clear();
    for (final r in records) {
      try {
        switch (r.kind) {
          case 'profile':
            _profile = Profile.fromJson(r.data);
            _setupDone = r.data['setupDone'] as bool? ?? true;
          case 'plan':
            _plan = WeeklyPlan.fromJson(r.data);
          case 'myfoods':
            _myFoods
              ..clear()
              ..addAll(((r.data['items'] as List?) ?? const [])
                  .whereType<Map<String, dynamic>>()
                  .map(Food.fromJson));
          case 'food':
            _log.add(LogEntry.fromJson(r.data));
          case 'workout':
            _workouts.add(WorkoutEntry.fromJson(r.data));
          case 'checkin':
            final c = DayCheckIn.fromJson(r.data);
            _checkIns[c.day] = c;
        }
      } catch (e) {
        debugPrint('Skipped bad record ${r.key}: $e');
      }
    }
  }

  void _clearLocal() {
    _log.clear();
    _workouts.clear();
    _checkIns.clear();
    _myFoods.clear();
    _plan = WeeklyPlan();
    _profile = const Profile();
    _setupDone = false;
    _queue.clear();
  }

  /// Sign-out: upload what is left, then wipe this device.
  Future<void> detachCloud() async {
    await flush();
    _flushTimer?.cancel();
    _cloud = null;
    _clearLocal();
    await _prefs?.remove(_kOwner);
    await _save();
    _setStatus(SyncStatus.off);
    notifyListeners();
  }

  /// Permanently delete this person's cloud data and local data.
  Future<void> deleteCloudData() async {
    final cloud = _cloud;
    if (cloud != null) await cloud.deleteEverything();
    _queue.clear();
    await detachCloud();
  }

  void addEntry({
    required Food food,
    required double grams,
    required Meal meal,
    bool fromScale = false,
    DateTime? when,
  }) {
    final now = when ?? DateTime.now();
    _log.add(LogEntry(
      id: '${now.microsecondsSinceEpoch}',
      food: food,
      grams: grams,
      meal: meal,
      time: now,
      fromScale: fromScale,
    ));
    _record(CloudRecord(kind: 'food', id: _log.last.id, data: _log.last.toJson()));
    // Remember packaged and photo foods so they are quick to find next time.
    if (food.source != FoodSource.builtIn &&
        !_myFoods.any((f) => f.name.toLowerCase() == food.name.toLowerCase())) {
      _myFoods.insert(0, food);
      if (_myFoods.length > 100) _myFoods.removeLast();
      _record(_myFoodsRecord());
    }
    notifyListeners();
    _save();
  }

  void removeEntry(String id) {
    _log.removeWhere((e) => e.id == id);
    _recordDelete('food', id);
    notifyListeners();
    _save();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<LogEntry> entriesOn(DateTime day) =>
      _log.where((e) => _sameDay(e.time, day)).toList()
        ..sort((a, b) => a.time.compareTo(b.time));

  List<LogEntry> entriesFor(DateTime day, Meal meal) =>
      entriesOn(day).where((e) => e.meal == meal).toList();

  Nutrition totalOn(DateTime day) =>
      entriesOn(day).fold(const Nutrition(), (sum, e) => sum + e.nutrition);

  Nutrition totalFor(DateTime day, Meal meal) =>
      entriesFor(day, meal).fold(const Nutrition(), (sum, e) => sum + e.nutrition);

  /// Calories for each of the last 7 days, oldest first, ending today.
  List<(DateTime, double)> lastSevenDays() {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final d = DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i));
      return (d, totalOn(d).kcal);
    });
  }

  // ------------------------------------------------------------ Fitness

  WeeklyPlan get plan => _plan;

  void savePlan(WeeklyPlan plan) {
    _plan = plan;
    _record(_planRecord());
    notifyListeners();
    _save();
  }

  /// Body weight to use for calorie maths on a day: that day's weigh-in,
  /// else the most recent earlier one, else the profile weight.
  double weightOn(DateTime day) {
    final key = dayKey(day);
    final keys = _checkIns.keys.where((k) => k.compareTo(key) <= 0).toList()..sort();
    for (final k in keys.reversed) {
      final w = _checkIns[k]!.bodyWeightKg;
      if (w != null) return w;
    }
    return _profile.weightKg;
  }

  void addWorkout(WorkoutEntry w) {
    _workouts.add(w);
    _record(CloudRecord(kind: 'workout', id: w.id, data: w.toJson()));
    notifyListeners();
    _save();
  }

  void removeWorkout(String id) {
    _workouts.removeWhere((w) => w.id == id);
    _recordDelete('workout', id);
    notifyListeners();
    _save();
  }

  List<WorkoutEntry> workoutsOn(DateTime day) =>
      _workouts.where((w) => _sameDay(w.time, day)).toList()..sort((a, b) => a.time.compareTo(b.time));

  DayCheckIn checkInOn(DateTime day) => _checkIns[dayKey(day)] ?? DayCheckIn(day: dayKey(day));

  bool hasCheckIn(DateTime day) => _checkIns.containsKey(dayKey(day));

  void saveCheckIn(DayCheckIn c) {
    _checkIns[c.day] = c;
    // A new weigh-in today also updates the profile so targets follow.
    _record(CloudRecord(kind: 'checkin', id: c.day, data: c.toJson()));
    if (c.bodyWeightKg != null && c.day == dayKey(DateTime.now()) && c.bodyWeightKg != _profile.weightKg) {
      _profile = _profile.copyWith(weightKg: c.bodyWeightKg);
      _record(_profileRecord());
    }
    notifyListeners();
    _save();
  }

  void addWater(DateTime day, int delta) {
    final c = checkInOn(day);
    saveCheckIn(c.copyWith(water: (c.water + delta).clamp(0, 30).toInt()));
  }

  /// Merge numbers synced from Apple Health / Health Connect.
  void applyHealth(DateTime day, {int? steps, double? distanceKm, double? activeKcal, double? weightKg}) {
    final c = checkInOn(day);
    saveCheckIn(c.copyWith(
      steps: steps,
      distanceKm: distanceKm,
      healthActiveKcal: activeKcal,
      stepsFromHealth: steps != null ? true : null,
      // Only use the phone's weight when the person did not type one.
      bodyWeightKg: c.bodyWeightKg == null ? weightKg : null,
    ));
  }

  EnergyDay energyOn(DateTime day) => energyFor(
        profile: _profile,
        eaten: totalOn(day),
        workouts: workoutsOn(day),
        checkIn: _checkIns[dayKey(day)],
      );

  /// Weigh-ins over the last [days] days, oldest first.
  List<(DateTime, double)> weightHistory({int days = 30}) {
    final now = DateTime.now();
    final out = <(DateTime, double)>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final w = _checkIns[dayKey(d)]?.bodyWeightKg;
      if (w != null) out.add((d, w));
    }
    return out;
  }

  /// A compact summary of the last 7 days for the AI coach. Contains no
  /// names or identifiers — only numbers and food names.
  Map<String, dynamic> weekSummaryForCoach() {
    final now = DateTime.now();
    final t = targets;
    final days = <Map<String, dynamic>>[];
    for (var i = 6; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final e = energyOn(d);
      final c = _checkIns[dayKey(d)];
      final foods = entriesOn(d);
      days.add({
        'date': dayKey(d),
        'kcalEaten': e.eaten.kcal.round(),
        'proteinG': e.eaten.protein.round(),
        'carbsG': e.eaten.carbs.round(),
        'fatG': e.eaten.fat.round(),
        'kcalBurnedEstimate': e.burned.round(),
        'activeKcal': e.active.round(),
        'steps': e.steps,
        'walkKm': double.parse(e.distanceKm.toStringAsFixed(1)),
        'bodyWeightKg': c?.bodyWeightKg,
        'waterGlasses': c?.water,
        'sleepHours': c?.sleepHours,
        'habits': c?.habits.toList() ?? const [],
        'foods': foods.map((f) => '${f.food.name} ${f.grams.round()}g').toList(),
        'workouts': workoutsOn(d)
            .map((w) => {
                  'name': w.name,
                  'minutes': w.minutes.round(),
                  if (w.sets.isNotEmpty) 'sets': w.sets.length,
                  if (w.volumeKg > 0) 'volumeKg': w.volumeKg.round(),
                  'kcal': w.kcal.round(),
                })
            .toList(),
        'loggedFood': foods.isNotEmpty,
      });
    }
    return {
      'profile': {
        'age': _profile.age,
        'sex': _profile.sex.name,
        'heightCm': _profile.heightCm.round(),
        'weightKg': _profile.weightKg.round(),
        'goal': _profile.goal.name,
        'activity': _profile.activity.name,
      },
      'targets': {'kcal': t.kcal, 'proteinG': t.protein},
      'days': days,
    };
  }

  Future<void> resetAll() async {
    _workouts.clear();
    _plan = WeeklyPlan();
    _checkIns.clear();
    _log.clear();
    _myFoods.clear();
    _profile = const Profile();
    _setupDone = false;
    await _prefs?.clear();
    notifyListeners();
  }
}
