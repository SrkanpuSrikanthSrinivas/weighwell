import 'package:flutter_test/flutter_test.dart';
import 'package:weighwell/data/exercise_catalog.dart';
import 'package:weighwell/models/fitness.dart';
import 'package:weighwell/models/models.dart';
import 'package:weighwell/services/energy.dart';

void main() {
  const p = Profile(); // woman, 40, 72 kg, 170 cm

  group('Exercise calories', () {
    test('30 min brisk walking at 72 kg', () {
      // (5.0 - 1) * 3.5 * 72 / 200 * 30 = 151.2
      expect(exerciseKcal(met: 5.0, weightKg: 72, minutes: 30), closeTo(151.2, 0.01));
    });

    test('strength time comes from sets', () {
      final squats = findExercise('Squats')!;
      // 4 sets → 10 min; (5 - 1) * 3.5 * 72 / 200 * 10 = 50.4
      expect(kcalForEntry(type: squats, weightKg: 72, sets: 4), closeTo(50.4, 0.01));
    });

    test('catalog lookups', () {
      expect(findExercise('bench press')!.kind, ExerciseKind.strength);
      expect(searchExercises('yoga').length, greaterThanOrEqualTo(2));
      expect(exerciseCatalog.map((e) => e.name).toSet().length, exerciseCatalog.length);
    });
  });

  group('Walking', () {
    test('steps to km and kcal', () {
      final km = stepsToKm(10000, 170);
      expect(km, closeTo(7.04, 0.01));
      expect(walkingKcal(km: km, weightKg: 72), closeTo(253, 1));
    });
  });

  group('Energy day', () {
    test('resting + living + walking + exercise', () {
      final e = energyFor(
        profile: p,
        eaten: const Nutrition(kcal: 1800),
        workouts: [
          WorkoutEntry(id: '1', time: DateTime(2026, 11, 17), name: 'Squats', kind: ExerciseKind.strength, met: 5, minutes: 10, kcal: 50),
        ],
        checkIn: const DayCheckIn(day: '2026-11-17', steps: 5000),
      );
      expect(e.resting, closeTo(1421.5, 0.01));
      expect(e.dailyLiving, closeTo(213.2, 0.1));
      expect(e.exercise, 50);
      expect(e.walking, closeTo(126.7, 0.5));
      expect(e.balance, closeTo(1800 - e.burned, 0.001));
      expect(e.usedHealthData, isFalse);
    });

    test('logged walking is not double counted when steps exist', () {
      final e = energyFor(
        profile: p,
        eaten: const Nutrition(),
        workouts: [
          WorkoutEntry(id: '1', time: DateTime(2026, 11, 17), name: 'Brisk walking (6.5 km/h)', kind: ExerciseKind.cardio, met: 5, minutes: 30, kcal: 151),
        ],
        checkIn: const DayCheckIn(day: '2026-11-17', steps: 8000),
      );
      expect(e.exercise, 0);
    });

    test('phone active calories win when higher', () {
      final e = energyFor(
        profile: p,
        eaten: const Nutrition(),
        workouts: const [],
        checkIn: const DayCheckIn(day: '2026-11-17', steps: 2000, healthActiveKcal: 600),
      );
      expect(e.usedHealthData, isTrue);
      expect(e.active, 600);
    });

    test('today\'s weigh-in is used for resting calories', () {
      final e = energyFor(
        profile: p,
        eaten: const Nutrition(),
        workouts: const [],
        checkIn: const DayCheckIn(day: '2026-11-17', bodyWeightKg: 70),
      );
      expect(e.resting, closeTo(1401.5, 0.01));
    });

    test('7700 kcal ≈ 1 kg', () {
      expect(expectedWeightChangeKg(-3850), closeTo(-0.5, 0.0001));
    });
  });

  group('JSON', () {
    test('weekly plan round trip', () {
      final plan = WeeklyPlan({
        1: [const PlannedExercise(name: 'Squats', sets: 3, reps: 12, weightKg: 20)],
        3: [const PlannedExercise(name: 'Yoga (gentle)', minutes: 20)],
      });
      final back = WeeklyPlan.fromJson(plan.toJson());
      expect(back.days[1]!.single.weightKg, 20);
      expect(back.days[3]!.single.minutes, 20);
      expect(back.days[7], isEmpty);
      expect(back.isEmpty, isFalse);
    });

    test('check-in round trip', () {
      const c = DayCheckIn(day: '2026-11-17', bodyWeightKg: 71.4, steps: 6000, water: 6, sleepHours: 7.5, habits: {'Ate fruit'});
      final back = DayCheckIn.fromJson(c.toJson());
      expect(back.bodyWeightKg, 71.4);
      expect(back.habits, contains('Ate fruit'));
      expect(back.sleepHours, 7.5);
    });

    test('workout round trip and volume', () {
      final w = WorkoutEntry(
        id: '9',
        time: DateTime(2026, 11, 17, 7),
        name: 'Bench press',
        kind: ExerciseKind.strength,
        met: 5,
        sets: const [WorkoutSet(reps: 10, weightKg: 40), WorkoutSet(reps: 8, weightKg: 45)],
        minutes: 10,
        kcal: 50,
      );
      final back = WorkoutEntry.fromJson(w.toJson());
      expect(back.volumeKg, 760);
      expect(back.kind, ExerciseKind.strength);
    });

    test('day key', () {
      expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });
}
