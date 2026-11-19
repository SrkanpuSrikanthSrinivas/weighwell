/// Core data types. Nutrition is always stored "per 100 g" so any weight
/// can be converted with one multiplication.
library;

enum Meal { breakfast, lunch, snack, dinner }

extension MealLabel on Meal {
  String get label => switch (this) {
        Meal.breakfast => 'Breakfast',
        Meal.lunch => 'Lunch',
        Meal.snack => 'Snack',
        Meal.dinner => 'Dinner',
      };

  /// A sensible default meal for the time of day.
  static Meal forHour(int hour) {
    if (hour < 11) return Meal.breakfast;
    if (hour < 15) return Meal.lunch;
    if (hour < 18) return Meal.snack;
    return Meal.dinner;
  }
}

enum FoodSource { builtIn, barcode, photo, search, custom }

class Food {
  const Food({
    required this.name,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.carbsPer100,
    required this.fatPer100,
    this.category = 'Other',
    this.source = FoodSource.builtIn,
    this.barcode,
    this.typicalServingGrams,
  });

  final String name;
  final double kcalPer100;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;
  final String category;
  final FoodSource source;
  final String? barcode;
  final double? typicalServingGrams;

  Nutrition forGrams(double grams) => Nutrition(
        kcal: kcalPer100 * grams / 100,
        protein: proteinPer100 * grams / 100,
        carbs: carbsPer100 * grams / 100,
        fat: fatPer100 * grams / 100,
      );

  Food copyWith({FoodSource? source, String? barcode}) => Food(
        name: name,
        kcalPer100: kcalPer100,
        proteinPer100: proteinPer100,
        carbsPer100: carbsPer100,
        fatPer100: fatPer100,
        category: category,
        source: source ?? this.source,
        barcode: barcode ?? this.barcode,
        typicalServingGrams: typicalServingGrams,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'kcal': kcalPer100,
        'protein': proteinPer100,
        'carbs': carbsPer100,
        'fat': fatPer100,
        'category': category,
        'source': source.name,
        'barcode': barcode,
        'serving': typicalServingGrams,
      };

  factory Food.fromJson(Map<String, dynamic> j) => Food(
        name: j['name'] as String,
        kcalPer100: (j['kcal'] as num).toDouble(),
        proteinPer100: (j['protein'] as num).toDouble(),
        carbsPer100: (j['carbs'] as num? ?? 0).toDouble(),
        fatPer100: (j['fat'] as num? ?? 0).toDouble(),
        category: j['category'] as String? ?? 'Other',
        source: FoodSource.values.firstWhere(
          (s) => s.name == j['source'],
          orElse: () => FoodSource.custom,
        ),
        barcode: j['barcode'] as String?,
        typicalServingGrams: (j['serving'] as num?)?.toDouble(),
      );
}

class Nutrition {
  const Nutrition({
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  Nutrition operator +(Nutrition o) => Nutrition(
        kcal: kcal + o.kcal,
        protein: protein + o.protein,
        carbs: carbs + o.carbs,
        fat: fat + o.fat,
      );
}

/// One weighed food that was eaten.
class LogEntry {
  LogEntry({
    required this.id,
    required this.food,
    required this.grams,
    required this.meal,
    required this.time,
    this.fromScale = false,
  });

  final String id;
  final Food food;
  final double grams;
  final Meal meal;
  final DateTime time;
  final bool fromScale;

  Nutrition get nutrition => food.forGrams(grams);

  Map<String, dynamic> toJson() => {
        'id': id,
        'food': food.toJson(),
        'grams': grams,
        'meal': meal.name,
        'time': time.toIso8601String(),
        'scale': fromScale,
      };

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        id: j['id'] as String,
        food: Food.fromJson(j['food'] as Map<String, dynamic>),
        grams: (j['grams'] as num).toDouble(),
        meal: Meal.values.firstWhere((m) => m.name == j['meal'],
            orElse: () => Meal.snack),
        time: DateTime.parse(j['time'] as String),
        fromScale: j['scale'] as bool? ?? false,
      );
}

enum Sex { female, male }

enum Activity { low, some, very }

enum Goal { lose, stay, gain }

extension ActivityInfo on Activity {
  String get label => switch (this) {
        Activity.low => 'A little',
        Activity.some => 'Some',
        Activity.very => 'Very',
      };
  String get hint => switch (this) {
        Activity.low => 'Mostly sitting',
        Activity.some => 'Walks, light exercise',
        Activity.very => 'Sports or hard work',
      };
  double get factor => switch (this) {
        Activity.low => 1.3,
        Activity.some => 1.5,
        Activity.very => 1.75,
      };
}

extension GoalInfo on Goal {
  String get label => switch (this) {
        Goal.lose => 'Lose weight',
        Goal.stay => 'Stay same',
        Goal.gain => 'Build muscle',
      };
}

class Profile {
  const Profile({
    this.age = 40,
    this.weightKg = 72,
    this.heightCm = 170,
    this.sex = Sex.female,
    this.activity = Activity.some,
    this.goal = Goal.stay,
    this.textScale = 1.0,
    this.useKg = true,
    this.stepGoal = 8000,
    this.waterGoal = 8,
  });

  final int age;
  final double weightKg;
  final double heightCm;
  final Sex sex;
  final Activity activity;
  final Goal goal;

  /// 1.0 normal, 1.2 large, 1.4 extra large — for easy reading at any age.
  final double textScale;
  final bool useKg;

  /// Daily step target (8,000 is a good everyday goal for most adults).
  final int stepGoal;

  /// Glasses of water per day.
  final int waterGoal;

  Profile copyWith({
    int? age,
    double? weightKg,
    double? heightCm,
    Sex? sex,
    Activity? activity,
    Goal? goal,
    double? textScale,
    bool? useKg,
    int? stepGoal,
    int? waterGoal,
  }) =>
      Profile(
        age: age ?? this.age,
        weightKg: weightKg ?? this.weightKg,
        heightCm: heightCm ?? this.heightCm,
        sex: sex ?? this.sex,
        activity: activity ?? this.activity,
        goal: goal ?? this.goal,
        textScale: textScale ?? this.textScale,
        useKg: useKg ?? this.useKg,
        stepGoal: stepGoal ?? this.stepGoal,
        waterGoal: waterGoal ?? this.waterGoal,
      );

  Map<String, dynamic> toJson() => {
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'sex': sex.name,
        'activity': activity.name,
        'goal': goal.name,
        'textScale': textScale,
        'useKg': useKg,
        'stepGoal': stepGoal,
        'waterGoal': waterGoal,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        age: j['age'] as int? ?? 40,
        weightKg: (j['weightKg'] as num? ?? 72).toDouble(),
        heightCm: (j['heightCm'] as num? ?? 170).toDouble(),
        sex: Sex.values.firstWhere((s) => s.name == j['sex'],
            orElse: () => Sex.female),
        activity: Activity.values.firstWhere((a) => a.name == j['activity'],
            orElse: () => Activity.some),
        goal: Goal.values.firstWhere((g) => g.name == j['goal'],
            orElse: () => Goal.stay),
        textScale: (j['textScale'] as num? ?? 1.0).toDouble(),
        useKg: j['useKg'] as bool? ?? true,
        stepGoal: (j['stepGoal'] as num? ?? 8000).toInt(),
        waterGoal: (j['waterGoal'] as num? ?? 8).toInt(),
      );
}

class DailyTargets {
  const DailyTargets({required this.kcal, required this.protein});
  final int kcal;
  final int protein;
}
