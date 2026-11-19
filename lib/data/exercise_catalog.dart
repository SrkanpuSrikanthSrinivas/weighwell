import '../models/fitness.dart';

/// Built-in exercises. MET values are rounded from the 2024 Adult
/// Compendium of Physical Activities (moderate effort unless noted).
const List<ExerciseType> exerciseCatalog = [
  // Strength
  ExerciseType('Squats', ExerciseKind.strength, 5.0),
  ExerciseType('Bench press', ExerciseKind.strength, 5.0),
  ExerciseType('Deadlift', ExerciseKind.strength, 6.0),
  ExerciseType('Shoulder press', ExerciseKind.strength, 5.0),
  ExerciseType('Dumbbell rows', ExerciseKind.strength, 5.0),
  ExerciseType('Lat pulldown', ExerciseKind.strength, 4.0),
  ExerciseType('Leg press', ExerciseKind.strength, 5.0),
  ExerciseType('Lunges', ExerciseKind.strength, 4.0),
  ExerciseType('Bicep curls', ExerciseKind.strength, 3.5),
  ExerciseType('Tricep dips', ExerciseKind.strength, 3.8),
  ExerciseType('Push-ups', ExerciseKind.strength, 3.8),
  ExerciseType('Pull-ups', ExerciseKind.strength, 8.0),
  ExerciseType('Plank', ExerciseKind.strength, 3.8),
  ExerciseType('Sit-ups / crunches', ExerciseKind.strength, 3.8),
  ExerciseType('Kettlebell swings', ExerciseKind.strength, 6.0),
  ExerciseType('Resistance bands', ExerciseKind.strength, 3.5),

  // Cardio
  ExerciseType('Walking (easy, 5 km/h)', ExerciseKind.cardio, 3.5, hasDistance: true),
  ExerciseType('Brisk walking (6.5 km/h)', ExerciseKind.cardio, 5.0, hasDistance: true),
  ExerciseType('Running (8 km/h)', ExerciseKind.cardio, 8.3, hasDistance: true),
  ExerciseType('Running (10 km/h)', ExerciseKind.cardio, 9.8, hasDistance: true),
  ExerciseType('Cycling (moderate)', ExerciseKind.cardio, 6.8, hasDistance: true),
  ExerciseType('Stationary bike', ExerciseKind.cardio, 6.8),
  ExerciseType('Swimming (moderate)', ExerciseKind.cardio, 5.8, hasDistance: true),
  ExerciseType('Elliptical', ExerciseKind.cardio, 5.0),
  ExerciseType('Rowing machine', ExerciseKind.cardio, 7.0),
  ExerciseType('Jump rope', ExerciseKind.cardio, 11.8),
  ExerciseType('Stair climbing', ExerciseKind.cardio, 8.0),
  ExerciseType('Dancing', ExerciseKind.cardio, 5.0),
  ExerciseType('Badminton', ExerciseKind.cardio, 5.5),
  ExerciseType('Tennis', ExerciseKind.cardio, 7.3),
  ExerciseType('Cricket', ExerciseKind.cardio, 4.8),
  ExerciseType('Basketball', ExerciseKind.cardio, 6.5),
  ExerciseType('Football / soccer', ExerciseKind.cardio, 7.0),
  ExerciseType('Hiking', ExerciseKind.cardio, 6.0, hasDistance: true),

  // Flexibility
  ExerciseType('Yoga (gentle)', ExerciseKind.flexibility, 2.5),
  ExerciseType('Power yoga', ExerciseKind.flexibility, 4.0),
  ExerciseType('Surya namaskar', ExerciseKind.flexibility, 3.3),
  ExerciseType('Stretching', ExerciseKind.flexibility, 2.3),
  ExerciseType('Pilates', ExerciseKind.flexibility, 3.0),
  ExerciseType('Tai chi', ExerciseKind.flexibility, 3.0),
];

ExerciseType? findExercise(String name) {
  final n = name.trim().toLowerCase();
  for (final e in exerciseCatalog) {
    if (e.name.toLowerCase() == n) return e;
  }
  for (final e in exerciseCatalog) {
    if (e.name.toLowerCase().startsWith(n) || n.startsWith(e.name.toLowerCase().split(' (').first)) return e;
  }
  return null;
}

List<ExerciseType> searchExercises(String q) {
  final n = q.trim().toLowerCase();
  if (n.isEmpty) return exerciseCatalog;
  return exerciseCatalog.where((e) => e.name.toLowerCase().contains(n)).toList();
}
