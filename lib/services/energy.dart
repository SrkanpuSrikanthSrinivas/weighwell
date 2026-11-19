import '../models/fitness.dart';
import '../models/models.dart';

/// Calories in vs. calories out for a day. All "out" numbers are estimates
/// built from standard formulas; phone health data is used when available
/// because it is measured, not guessed.

/// Resting calories per day (Mifflin–St Jeor).
double bmr(Profile p, {double? weightKg}) {
  final w = weightKg ?? p.weightKg;
  final base = 10 * w + 6.25 * p.heightCm - 5 * p.age;
  return p.sex == Sex.male ? base + 5 : base - 161;
}

/// Net extra calories for an activity, above resting (ACSM formula:
/// kcal/min = MET × 3.5 × kg / 200). Resting is subtracted so it is not
/// counted twice.
double exerciseKcal({required double met, required double weightKg, required double minutes}) {
  final net = (met - 1).clamp(0.0, 30.0).toDouble();
  return net * 3.5 * weightKg / 200 * minutes;
}

/// Strength work is mostly rest between sets: about 2.5 minutes per set.
double strengthMinutes(int sets) => sets * 2.5;

/// Stride length estimate from height (metres per step).
double strideMetres(double heightCm) => heightCm * 0.414 / 100;

double stepsToKm(int steps, double heightCm) => steps * strideMetres(heightCm) / 1000;

/// Net walking cost ≈ 0.5 kcal per kg per km.
double walkingKcal({required double km, required double weightKg}) => 0.5 * weightKg * km;

class EnergyDay {
  const EnergyDay({
    required this.eaten,
    required this.resting,
    required this.dailyLiving,
    required this.walking,
    required this.exercise,
    required this.usedHealthData,
    required this.steps,
    required this.distanceKm,
  });

  final Nutrition eaten;
  final double resting;
  final double dailyLiving;
  final double walking;
  final double exercise;
  final bool usedHealthData;
  final int steps;
  final double distanceKm;

  double get active => walking + exercise;
  double get burned => resting + dailyLiving + active;

  /// Positive = ate more than burned (weight gain direction).
  double get balance => eaten.kcal - burned;
}

/// Builds a day's energy picture.
///
/// - Resting: BMR (using today's weigh-in if there is one).
/// - Daily living: 15 % of BMR for digesting food and light moving around.
/// - Walking: from steps / distance.
/// - Exercise: sum of logged workouts.
/// - If the phone reports active calories that are higher than our
///   walking + exercise estimate, we trust the phone instead.
EnergyDay energyFor({
  required Profile profile,
  required Nutrition eaten,
  required List<WorkoutEntry> workouts,
  DayCheckIn? checkIn,
}) {
  final weight = checkIn?.bodyWeightKg ?? profile.weightKg;
  final rest = bmr(profile, weightKg: weight);
  final living = rest * 0.15;

  final steps = checkIn?.steps ?? 0;
  final km = checkIn?.distanceKm ?? (steps > 0 ? stepsToKm(steps, profile.heightCm) : 0.0);

  // Walking workouts are already counted in steps on most phones, so
  // exercise excludes logged walking when steps are present.
  final exercise = workouts.fold<double>(0, (s, w) {
    final isWalk = w.name.toLowerCase().contains('walk');
    if (isWalk && steps > 0) return s;
    return s + w.kcal;
  });
  final walk = walkingKcal(km: km, weightKg: weight);

  var active = walk + exercise;
  var used = false;
  final phone = checkIn?.healthActiveKcal;
  if (phone != null && phone > active) {
    active = phone;
    used = true;
  }
  final shownExercise = exercise > active ? active : exercise;
  return EnergyDay(
    eaten: eaten,
    resting: rest,
    dailyLiving: living,
    walking: used ? active - shownExercise : walk,
    exercise: shownExercise,
    usedHealthData: used,
    steps: steps,
    distanceKm: km,
  );
}

/// About 7,700 kcal of balance ≈ 1 kg of body weight.
double expectedWeightChangeKg(double totalBalanceKcal) => totalBalanceKcal / 7700;

/// Calories for one logged exercise.
double kcalForEntry({
  required ExerciseType type,
  required double weightKg,
  double? minutes,
  int sets = 0,
}) {
  final mins = minutes ?? (type.kind == ExerciseKind.strength ? strengthMinutes(sets) : 0);
  return exerciseKcal(met: type.met, weightKg: weightKg, minutes: mins);
}
