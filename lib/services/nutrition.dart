import '../models/models.dart';

/// Daily targets from the Mifflin–St Jeor equation, adjusted for activity
/// and goal. These are general estimates, not medical advice.
DailyTargets targetsFor(Profile p) {
  final base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age;
  final bmr = p.sex == Sex.male ? base + 5 : base - 161;
  var kcal = bmr * p.activity.factor;
  kcal += switch (p.goal) {
    Goal.lose => -400,
    Goal.stay => 0,
    Goal.gain => 300,
  };
  // Never suggest an unsafe low target.
  final floor = p.sex == Sex.male ? 1500.0 : 1200.0;
  if (kcal < floor) kcal = floor;

  final proteinPerKg = switch (p.goal) {
    Goal.lose => 1.6,
    Goal.stay => 1.2,
    Goal.gain => 1.8,
  };
  return DailyTargets(
    kcal: (kcal / 50).round() * 50,
    protein: (p.weightKg * proteinPerKg).round(),
  );
}

class PlannedMeal {
  const PlannedMeal({
    required this.meal,
    required this.time,
    required this.kcal,
    required this.protein,
    required this.ideas,
  });
  final Meal meal;
  final String time;
  final int kcal;
  final int protein;
  final List<String> ideas;
}

const _split = {
  Meal.breakfast: 0.25,
  Meal.lunch: 0.35,
  Meal.snack: 0.10,
  Meal.dinner: 0.30,
};

const _times = {
  Meal.breakfast: '8 am',
  Meal.lunch: '1 pm',
  Meal.snack: '4 pm',
  Meal.dinner: '7 pm',
};

const _ideas = {
  Meal.breakfast: [
    'Eggs, toast and fruit',
    'Oatmeal with milk and banana',
    'Idli with sambar',
    'Greek yogurt with berries and nuts',
  ],
  Meal.lunch: [
    'Rice, dal and vegetables',
    'Chicken rice bowl with salad',
    'Roti, paneer curry and salad',
    'Whole-grain sandwich with turkey',
  ],
  Meal.snack: [
    'Yogurt or a handful of nuts',
    'Apple with peanut butter',
    'Roasted chana',
    'A glass of milk',
  ],
  Meal.dinner: [
    'Roti, vegetables and paneer',
    'Fish or tofu with rice',
    'Lentil soup with bread',
    'Grilled chicken with vegetables',
  ],
};

/// Splits the day's targets across four meals with simple food ideas.
/// [dayIndex] rotates the ideas so the plan changes day to day.
List<PlannedMeal> dailyPlan(DailyTargets t, {int dayIndex = 0}) {
  return Meal.values.map((m) {
    final share = _split[m]!;
    final ideas = _ideas[m]!;
    return PlannedMeal(
      meal: m,
      time: _times[m]!,
      kcal: ((t.kcal * share) / 10).round() * 10,
      protein: (t.protein * share).round(),
      ideas: [ideas[dayIndex % ideas.length], ideas[(dayIndex + 1) % ideas.length]],
    );
  }).toList()
    ..sort((a, b) => _order(a.meal).compareTo(_order(b.meal)));
}

int _order(Meal m) => switch (m) {
      Meal.breakfast => 0,
      Meal.lunch => 1,
      Meal.snack => 2,
      Meal.dinner => 3,
    };

String fmtInt(num n) {
  final s = n.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String fmt1(double n) =>
    n >= 10 ? n.round().toString() : n.toStringAsFixed(1);
