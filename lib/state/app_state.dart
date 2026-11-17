import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/nutrition.dart';

/// All app data, saved on the device (phone storage or browser storage).
class AppState extends ChangeNotifier {
  static const _kProfile = 'profile';
  static const _kLog = 'log';
  static const _kMyFoods = 'my_foods';
  static const _kSetupDone = 'setup_done';

  SharedPreferences? _prefs;

  Profile _profile = const Profile();
  final List<LogEntry> _log = [];
  final List<Food> _myFoods = [];
  bool _setupDone = false;
  bool _loaded = false;

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
  }

  void updateProfile(Profile p, {bool finishSetup = false}) {
    _profile = p;
    if (finishSetup) _setupDone = true;
    notifyListeners();
    _save();
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
    // Remember packaged and photo foods so they are quick to find next time.
    if (food.source != FoodSource.builtIn &&
        !_myFoods.any((f) => f.name.toLowerCase() == food.name.toLowerCase())) {
      _myFoods.insert(0, food);
      if (_myFoods.length > 100) _myFoods.removeLast();
    }
    notifyListeners();
    _save();
  }

  void removeEntry(String id) {
    _log.removeWhere((e) => e.id == id);
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

  Future<void> resetAll() async {
    _log.clear();
    _myFoods.clear();
    _profile = const Profile();
    _setupDone = false;
    await _prefs?.clear();
    notifyListeners();
  }
}
