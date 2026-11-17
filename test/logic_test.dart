import 'package:flutter_test/flutter_test.dart';
import 'package:weighwell/data/food_database.dart';
import 'package:weighwell/models/models.dart';
import 'package:weighwell/services/food_lookup.dart';
import 'package:weighwell/services/nutrition.dart';
import 'package:weighwell/services/scale/scale_types.dart';

void main() {
  group('Food math', () {
    test('banana 118 g', () {
      final banana = builtInFoods.firstWhere((f) => f.name == 'Banana');
      final n = banana.forGrams(118);
      expect(n.kcal.round(), 105);
      expect(n.protein, closeTo(1.3, 0.05));
    });

    test('nutrition adds up', () {
      const a = Nutrition(kcal: 100, protein: 5);
      const b = Nutrition(kcal: 50, protein: 2.5);
      final s = a + b;
      expect(s.kcal, 150);
      expect(s.protein, 7.5);
    });
  });

  group('Daily targets', () {
    test('stay-same woman, 40, 72 kg, 170 cm, some activity', () {
      const p = Profile();
      final t = targetsFor(p);
      // BMR = 720 + 1062.5 - 200 - 161 = 1421.5; x1.5 = 2132 -> 2150
      expect(t.kcal, 2150);
      expect(t.protein, 86);
    });

    test('losing weight never goes below the safe floor', () {
      const p = Profile(age: 80, weightKg: 40, heightCm: 140, activity: Activity.low, goal: Goal.lose);
      expect(targetsFor(p).kcal, 1200);
    });

    test('plan splits add up to about the daily target', () {
      const t = DailyTargets(kcal: 2000, protein: 100);
      final plan = dailyPlan(t);
      expect(plan.length, 4);
      expect(plan.first.meal, Meal.breakfast);
      final sum = plan.fold<int>(0, (s, m) => s + m.kcal);
      expect(sum, inInclusiveRange(1980, 2020));
    });
  });

  group('Bluetooth weight parsing', () {
    test('kilograms: 0x0BB8 * 0.005 kg = 15 kg', () {
      expect(parseWeightMeasurement([0x00, 0xB8, 0x0B]), 15000);
    });

    test('pounds flag', () {
      // 1000 * 0.01 lb = 10 lb = 4535.9 g
      expect(parseWeightMeasurement([0x01, 0xE8, 0x03]), closeTo(4535.9, 0.1));
    });

    test('short or failed packets are ignored', () {
      expect(parseWeightMeasurement([0x00, 0x01]), isNull);
      expect(parseWeightMeasurement([0x00, 0xFF, 0xFF]), isNull);
    });
  });

  group('Open Food Facts parsing', () {
    test('reads kcal, protein and brand', () {
      final f = OpenFoodFacts.parseProduct({
        'product_name': 'Greek yogurt',
        'brands': 'Acme, Other',
        'nutriments': {'energy-kcal_100g': 59, 'proteins_100g': 10.3, 'carbohydrates_100g': 3.6, 'fat_100g': '0.4'},
        'serving_quantity': '170',
      }, barcode: '123');
      expect(f, isNotNull);
      expect(f!.name, 'Greek yogurt (Acme)');
      expect(f.kcalPer100, 59);
      expect(f.fatPer100, 0.4);
      expect(f.typicalServingGrams, 170);
      expect(f.barcode, '123');
    });

    test('falls back to kJ when kcal missing', () {
      final f = OpenFoodFacts.parseProduct({'nutriments': {'energy_100g': 418.4}});
      expect(f!.kcalPer100, closeTo(100, 0.01));
      expect(f.name, 'Packaged food');
    });

    test('no energy means no food', () {
      expect(OpenFoodFacts.parseProduct({'nutriments': {}}), isNull);
    });
  });

  group('Search and storage', () {
    test('search ranks prefix matches first', () {
      final r = searchBuiltIn('rice');
      expect(r.first.name, contains('rice'));
      expect(searchBuiltIn('chick').map((f) => f.name), contains('Chicken breast (cooked)'));
    });

    test('log entry survives JSON round trip', () {
      final e = LogEntry(
        id: '1',
        food: builtInFoods.first,
        grams: 120,
        meal: Meal.lunch,
        time: DateTime(2026, 11, 15, 13),
        fromScale: true,
      );
      final back = LogEntry.fromJson(e.toJson());
      expect(back.food.name, e.food.name);
      expect(back.meal, Meal.lunch);
      expect(back.fromScale, isTrue);
      expect(back.nutrition.kcal, closeTo(e.nutrition.kcal, 0.001));
    });

    test('number formatting', () {
      expect(fmtInt(1240), '1,240');
      expect(fmtInt(999), '999');
      expect(fmtInt(1234567), '1,234,567');
      expect(fmt1(1.26), '1.3');
      expect(fmt1(12.4), '12');
    });
  });
}
