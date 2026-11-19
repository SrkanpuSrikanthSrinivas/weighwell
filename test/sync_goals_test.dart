import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weighwell/data/food_database.dart';
import 'package:weighwell/models/fitness.dart';
import 'package:weighwell/models/models.dart';
import 'package:weighwell/services/cloud_sync.dart';
import 'package:weighwell/services/goals.dart';
import 'package:weighwell/state/app_state.dart';

/// In-memory stand-in for Supabase.
class FakeCloud implements CloudBackend {
  FakeCloud(this.rows);
  final Map<String, CloudRecord> rows;
  int uploads = 0;

  @override
  String? get userId => 'user-1';

  @override
  Future<List<CloudRecord>> fetchAll() async => rows.values.toList();

  @override
  Future<void> upsert(List<CloudRecord> records) async {
    uploads++;
    for (final r in records) {
      rows[r.key] = r;
    }
  }

  @override
  Future<void> deleteEverything() async => rows.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mergeRecords', () {
    test('cloud wins, local-only is uploaded, cloud deletes remove local', () {
      final local = [
        const CloudRecord(kind: 'food', id: 'a', data: {'v': 'local'}),
        const CloudRecord(kind: 'food', id: 'b', data: {'v': 'local'}),
        const CloudRecord(kind: 'food', id: 'c', data: {'v': 'local'}),
      ];
      final cloud = [
        const CloudRecord(kind: 'food', id: 'a', data: {'v': 'cloud'}),
        const CloudRecord(kind: 'food', id: 'c', deleted: true),
        const CloudRecord(kind: 'workout', id: 'w', data: {'v': 'cloud'}),
      ];
      final m = mergeRecords(local: local, cloud: cloud);
      expect(m.records['food/a']!.data['v'], 'cloud');
      expect(m.records.containsKey('food/b'), isTrue);
      expect(m.records.containsKey('food/c'), isFalse);
      expect(m.records.containsKey('workout/w'), isTrue);
      expect(m.toUpload.map((r) => r.key), ['food/b']);
    });
  });

  group('AppState sync', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('data logged before sign-in is uploaded; cloud data comes down', () async {
      final s = AppState();
      await s.load();
      s.updateProfile(const Profile(age: 50), finishSetup: true);
      s.addEntry(food: builtInFoods.first, grams: 100, meal: Meal.lunch);

      final cloud = FakeCloud({
        'workout/w1': CloudRecord(
          kind: 'workout',
          id: 'w1',
          data: WorkoutEntry(
            id: 'w1',
            time: DateTime.now(),
            name: 'Squats',
            kind: ExerciseKind.strength,
            met: 5,
            minutes: 10,
            kcal: 50,
          ).toJson(),
        ),
      });
      await s.attachCloud(cloud);

      expect(s.workoutsOn(DateTime.now()).length, 1);
      expect(s.entriesOn(DateTime.now()).length, 1);
      expect(cloud.rows.keys, containsAll(['profile/me', 'workout/w1']));
      expect(cloud.rows.keys.where((k) => k.startsWith('food/')).length, 1);
      expect(s.syncStatus, SyncStatus.synced);

      // A change after sign-in is queued and uploaded.
      s.addWater(DateTime.now(), 2);
      await s.flush();
      expect(cloud.rows.keys.where((k) => k.startsWith('checkin/')).length, 1);

      // Deleting removes it in the cloud too.
      final id = s.entriesOn(DateTime.now()).first.id;
      s.removeEntry(id);
      await s.flush();
      expect(cloud.rows['food/$id']!.deleted, isTrue);
    });

    test('signing out wipes this device', () async {
      final s = AppState();
      await s.load();
      await s.attachCloud(FakeCloud({}));
      s.updateProfile(const Profile(age: 33), finishSetup: true);
      await s.detachCloud();
      expect(s.setupDone, isFalse);
      expect(s.profile.age, const Profile().age);
    });
  });

  group('Daily goals', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('seven goals that fill in as the day goes', () async {
      final s = AppState();
      await s.load();
      s.updateProfile(const Profile(stepGoal: 5000, waterGoal: 2), finishSetup: true);
      final today = DateTime.now();

      var goals = dailyGoals(s, today);
      expect(goals.length, 7);
      expect(goals.where((g) => g.done), isEmpty);

      s.addWater(today, 2);
      s.saveCheckIn(s.checkInOn(today).copyWith(steps: 6000, sleepHours: 7.5, bodyWeightKg: 70));
      goals = dailyGoals(s, today);
      bool done(GoalId id) => goals.firstWhere((g) => g.id == id).done;
      expect(done(GoalId.water), isTrue);
      expect(done(GoalId.steps), isTrue);
      expect(done(GoalId.sleep), isTrue);
      expect(done(GoalId.weighIn), isTrue);
      expect(done(GoalId.calories), isFalse);
    });
  });
}
