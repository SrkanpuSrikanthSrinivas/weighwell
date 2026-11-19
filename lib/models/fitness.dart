/// Exercise, workout and daily check-in data.
library;

enum ExerciseKind { strength, cardio, flexibility }

extension ExerciseKindLabel on ExerciseKind {
  String get label => switch (this) {
        ExerciseKind.strength => 'Strength',
        ExerciseKind.cardio => 'Cardio',
        ExerciseKind.flexibility => 'Stretch & yoga',
      };
}

/// An exercise from the built-in list. [met] is the energy cost from the
/// Compendium of Physical Activities (1 MET = sitting still).
class ExerciseType {
  const ExerciseType(this.name, this.kind, this.met, {this.hasDistance = false});
  final String name;
  final ExerciseKind kind;
  final double met;
  final bool hasDistance;
}

/// One line in the weekly schedule.
class PlannedExercise {
  const PlannedExercise({
    required this.name,
    this.sets = 3,
    this.reps = 10,
    this.weightKg,
    this.minutes,
  });

  final String name;
  final int sets;
  final int reps;
  final double? weightKg;
  final int? minutes;

  Map<String, dynamic> toJson() => {
        'name': name,
        'sets': sets,
        'reps': reps,
        'weightKg': weightKg,
        'minutes': minutes,
      };

  factory PlannedExercise.fromJson(Map<String, dynamic> j) => PlannedExercise(
        name: j['name'] as String,
        sets: (j['sets'] as num? ?? 3).toInt(),
        reps: (j['reps'] as num? ?? 10).toInt(),
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        minutes: (j['minutes'] as num?)?.toInt(),
      );
}

/// Weekly schedule: weekday (1 = Monday … 7 = Sunday) → exercises.
class WeeklyPlan {
  WeeklyPlan([Map<int, List<PlannedExercise>>? days])
      : days = {for (var d = 1; d <= 7; d++) d: List.of(days?[d] ?? const [])};

  final Map<int, List<PlannedExercise>> days;

  bool get isEmpty => days.values.every((l) => l.isEmpty);

  Map<String, dynamic> toJson() =>
      {for (final e in days.entries) '${e.key}': e.value.map((p) => p.toJson()).toList()};

  factory WeeklyPlan.fromJson(Map<String, dynamic> j) => WeeklyPlan({
        for (var d = 1; d <= 7; d++)
          d: ((j['$d'] as List?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(PlannedExercise.fromJson)
              .toList(),
      });
}

class WorkoutSet {
  const WorkoutSet({required this.reps, this.weightKg});
  final int reps;
  final double? weightKg;

  Map<String, dynamic> toJson() => {'reps': reps, 'weightKg': weightKg};
  factory WorkoutSet.fromJson(Map<String, dynamic> j) => WorkoutSet(
        reps: (j['reps'] as num? ?? 0).toInt(),
        weightKg: (j['weightKg'] as num?)?.toDouble(),
      );
}

/// One finished exercise.
class WorkoutEntry {
  WorkoutEntry({
    required this.id,
    required this.time,
    required this.name,
    required this.kind,
    required this.met,
    this.sets = const [],
    required this.minutes,
    this.distanceKm,
    required this.kcal,
  });

  final String id;
  final DateTime time;
  final String name;
  final ExerciseKind kind;
  final double met;
  final List<WorkoutSet> sets;
  final double minutes;
  final double? distanceKm;

  /// Extra calories burned above resting (net), estimated when logged.
  final double kcal;

  double get volumeKg => sets.fold(0, (s, x) => s + x.reps * (x.weightKg ?? 0));

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'name': name,
        'kind': kind.name,
        'met': met,
        'sets': sets.map((s) => s.toJson()).toList(),
        'minutes': minutes,
        'distanceKm': distanceKm,
        'kcal': kcal,
      };

  factory WorkoutEntry.fromJson(Map<String, dynamic> j) => WorkoutEntry(
        id: j['id'] as String,
        time: DateTime.parse(j['time'] as String),
        name: j['name'] as String,
        kind: ExerciseKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => ExerciseKind.cardio),
        met: (j['met'] as num? ?? 4).toDouble(),
        sets: ((j['sets'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WorkoutSet.fromJson)
            .toList(),
        minutes: (j['minutes'] as num? ?? 0).toDouble(),
        distanceKm: (j['distanceKm'] as num?)?.toDouble(),
        kcal: (j['kcal'] as num? ?? 0).toDouble(),
      );
}

/// Simple daily habits people can tick off.
const dailyHabits = [
  'Ate vegetables',
  'Ate fruit',
  'No sugary drinks',
  'Home-cooked meals',
  'No late-night snacking',
  'Took a walk',
];

/// What the person recorded (or the phone synced) for one day.
class DayCheckIn {
  const DayCheckIn({
    required this.day,
    this.bodyWeightKg,
    this.steps,
    this.distanceKm,
    this.healthActiveKcal,
    this.water = 0,
    this.sleepHours,
    this.habits = const {},
    this.note = '',
    this.stepsFromHealth = false,
  });

  /// 'yyyy-mm-dd'
  final String day;
  final double? bodyWeightKg;
  final int? steps;
  final double? distanceKm;

  /// Active calories reported by Apple Health / Health Connect.
  final double? healthActiveKcal;
  final int water;
  final double? sleepHours;
  final Set<String> habits;
  final String note;
  final bool stepsFromHealth;

  DayCheckIn copyWith({
    double? bodyWeightKg,
    int? steps,
    double? distanceKm,
    double? healthActiveKcal,
    int? water,
    double? sleepHours,
    Set<String>? habits,
    String? note,
    bool? stepsFromHealth,
    bool clearWeight = false,
  }) =>
      DayCheckIn(
        day: day,
        bodyWeightKg: clearWeight ? null : (bodyWeightKg ?? this.bodyWeightKg),
        steps: steps ?? this.steps,
        distanceKm: distanceKm ?? this.distanceKm,
        healthActiveKcal: healthActiveKcal ?? this.healthActiveKcal,
        water: water ?? this.water,
        sleepHours: sleepHours ?? this.sleepHours,
        habits: habits ?? this.habits,
        note: note ?? this.note,
        stepsFromHealth: stepsFromHealth ?? this.stepsFromHealth,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'weight': bodyWeightKg,
        'steps': steps,
        'distanceKm': distanceKm,
        'activeKcal': healthActiveKcal,
        'water': water,
        'sleep': sleepHours,
        'habits': habits.toList(),
        'note': note,
        'stepsFromHealth': stepsFromHealth,
      };

  factory DayCheckIn.fromJson(Map<String, dynamic> j) => DayCheckIn(
        day: j['day'] as String,
        bodyWeightKg: (j['weight'] as num?)?.toDouble(),
        steps: (j['steps'] as num?)?.toInt(),
        distanceKm: (j['distanceKm'] as num?)?.toDouble(),
        healthActiveKcal: (j['activeKcal'] as num?)?.toDouble(),
        water: (j['water'] as num? ?? 0).toInt(),
        sleepHours: (j['sleep'] as num?)?.toDouble(),
        habits: ((j['habits'] as List?) ?? const []).whereType<String>().toSet(),
        note: j['note'] as String? ?? '',
        stepsFromHealth: j['stepsFromHealth'] as bool? ?? false,
      );
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
