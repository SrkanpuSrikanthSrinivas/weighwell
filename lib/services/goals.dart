import '../models/fitness.dart';
import '../state/app_state.dart';
import 'nutrition.dart';

enum GoalId { calories, protein, steps, exercise, water, sleep, weighIn }

/// One of the daily goals shown on the Today screen.
class DailyGoal {
  const DailyGoal({
    required this.id,
    required this.title,
    required this.progress,
    required this.done,
    required this.valueText,
    required this.statusText,
    required this.why,
  });

  final GoalId id;
  final String title;

  /// 0..1 for the progress bar.
  final double progress;
  final bool done;

  /// e.g. "1,240 / 2,000 kcal"
  final String valueText;

  /// e.g. "760 kcal left" or "Done"
  final String statusText;

  /// One plain sentence on why this matters.
  final String why;
}

/// The seven simple things that add up to a healthy day.
List<DailyGoal> dailyGoals(AppState s, DateTime day) {
  final p = s.profile;
  final t = s.targets;
  final eaten = s.totalOn(day);
  final c = s.checkInOn(day);
  final energy = s.energyOn(day);

  // 1. Calories — inside a healthy range around the target.
  final kcal = eaten.kcal;
  final low = t.kcal * 0.85;
  final high = t.kcal * 1.10;
  final calDone = kcal >= low && kcal <= high;
  final calStatus = kcal > high
      ? '${fmtInt(kcal - t.kcal)} kcal over'
      : calDone
          ? 'On target'
          : '${fmtInt(t.kcal - kcal)} kcal to go';

  // 2. Protein
  final protein = eaten.protein;
  final proteinDone = protein >= t.protein;

  // 3. Steps
  final steps = energy.steps;
  final stepsDone = steps >= p.stepGoal;

  // 4. Exercise — today's plan, or 30 active minutes on a free day.
  final planned = s.plan.days[day.weekday] ?? const <PlannedExercise>[];
  final workouts = s.workoutsOn(day);
  final String exValue;
  final String exStatus;
  final double exProgress;
  final bool exDone;
  if (planned.isNotEmpty) {
    final doneNames = workouts.map((w) => w.name).toSet();
    final n = planned.where((x) => doneNames.contains(x.name)).length;
    exValue = '$n / ${planned.length} exercises';
    exDone = n >= planned.length;
    exProgress = n / planned.length;
    exStatus = exDone ? 'Done' : '${planned.length - n} to do';
  } else {
    final mins = workouts.fold<double>(0, (a, w) => a + w.minutes);
    exValue = '${mins.round()} / 30 min';
    exDone = mins >= 30;
    exProgress = mins / 30;
    exStatus = exDone ? 'Done' : 'No plan today — 30 min of any activity';
  }

  // 5. Water
  final waterDone = c.water >= p.waterGoal;

  // 6. Sleep
  final sleep = c.sleepHours;
  final maxSleep = p.age >= 65 ? 8.0 : 9.0;
  final sleepDone = sleep != null && sleep >= 7 && sleep <= maxSleep + 1;

  // 7. Weigh-in
  final weighed = c.bodyWeightKg != null;

  return [
    DailyGoal(
      id: GoalId.calories,
      title: 'Eat the right amount',
      progress: t.kcal == 0 ? 0 : kcal / t.kcal,
      done: calDone,
      valueText: '${fmtInt(kcal)} / ${fmtInt(t.kcal)} kcal',
      statusText: calStatus,
      why: 'Staying near your calorie target is what moves your weight toward your goal.',
    ),
    DailyGoal(
      id: GoalId.protein,
      title: 'Get enough protein',
      progress: t.protein == 0 ? 0 : protein / t.protein,
      done: proteinDone,
      valueText: '${protein.round()} / ${t.protein} g',
      statusText: proteinDone ? 'Done' : '${(t.protein - protein).round()} g to go',
      why: 'Protein keeps you full and protects your muscles, especially while losing weight.',
    ),
    DailyGoal(
      id: GoalId.steps,
      title: 'Walk ${fmtInt(p.stepGoal)} steps',
      progress: p.stepGoal == 0 ? 0 : steps / p.stepGoal,
      done: stepsDone,
      valueText: '${fmtInt(steps)} / ${fmtInt(p.stepGoal)} steps',
      statusText: stepsDone ? 'Done' : '${fmtInt(p.stepGoal - steps)} to go',
      why: 'Daily walking is one of the best things for your heart, mood and weight.',
    ),
    DailyGoal(
      id: GoalId.exercise,
      title: 'Exercise',
      progress: exProgress,
      done: exDone,
      valueText: exValue,
      statusText: exStatus,
      why: 'Strength and cardio a few times a week keep your body strong as you age.',
    ),
    DailyGoal(
      id: GoalId.water,
      title: 'Drink ${p.waterGoal} glasses of water',
      progress: p.waterGoal == 0 ? 0 : c.water / p.waterGoal,
      done: waterDone,
      valueText: '${c.water} / ${p.waterGoal} glasses',
      statusText: waterDone ? 'Done' : '${p.waterGoal - c.water} to go',
      why: 'Water helps energy and digestion, and is often mistaken for hunger.',
    ),
    DailyGoal(
      id: GoalId.sleep,
      title: 'Sleep 7–${maxSleep.round()} hours',
      progress: sleep == null ? 0 : sleep / 7,
      done: sleepDone,
      valueText: sleep == null ? 'Not logged' : '${sleep.toStringAsFixed(1)} h',
      statusText: sleep == null ? 'Log last night' : (sleepDone ? 'Done' : (sleep < 7 ? 'A bit short' : 'A lot of sleep')),
      why: 'Good sleep makes it much easier to control appetite and recover from exercise.',
    ),
    DailyGoal(
      id: GoalId.weighIn,
      title: 'Weigh yourself',
      progress: weighed ? 1 : 0,
      done: weighed,
      valueText: weighed ? 'Logged' : 'Not yet',
      statusText: weighed ? 'Done' : 'Once a day, in the morning',
      why: 'A daily weigh-in shows your real trend over weeks.',
    ),
  ];
}
