import '../models/models.dart';

/// Built-in foods so the app works offline and without any API key.
/// Values are per 100 g, rounded from USDA FoodData Central and common
/// label data. They are typical values — real foods vary.
const List<Food> builtInFoods = [
  // Fruit
  Food(name: 'Banana', kcalPer100: 89, proteinPer100: 1.1, carbsPer100: 22.8, fatPer100: 0.3, category: 'Fruit', typicalServingGrams: 118),
  Food(name: 'Apple', kcalPer100: 52, proteinPer100: 0.3, carbsPer100: 13.8, fatPer100: 0.2, category: 'Fruit', typicalServingGrams: 182),
  Food(name: 'Orange', kcalPer100: 47, proteinPer100: 0.9, carbsPer100: 11.8, fatPer100: 0.1, category: 'Fruit', typicalServingGrams: 131),
  Food(name: 'Grapes', kcalPer100: 69, proteinPer100: 0.7, carbsPer100: 18.1, fatPer100: 0.2, category: 'Fruit', typicalServingGrams: 150),
  Food(name: 'Strawberries', kcalPer100: 32, proteinPer100: 0.7, carbsPer100: 7.7, fatPer100: 0.3, category: 'Fruit', typicalServingGrams: 150),
  Food(name: 'Blueberries', kcalPer100: 57, proteinPer100: 0.7, carbsPer100: 14.5, fatPer100: 0.3, category: 'Fruit', typicalServingGrams: 150),
  Food(name: 'Mango', kcalPer100: 60, proteinPer100: 0.8, carbsPer100: 15.0, fatPer100: 0.4, category: 'Fruit', typicalServingGrams: 165),
  Food(name: 'Watermelon', kcalPer100: 30, proteinPer100: 0.6, carbsPer100: 7.6, fatPer100: 0.2, category: 'Fruit', typicalServingGrams: 280),
  Food(name: 'Pineapple', kcalPer100: 50, proteinPer100: 0.5, carbsPer100: 13.1, fatPer100: 0.1, category: 'Fruit', typicalServingGrams: 165),
  Food(name: 'Papaya', kcalPer100: 43, proteinPer100: 0.5, carbsPer100: 10.8, fatPer100: 0.3, category: 'Fruit', typicalServingGrams: 145),
  Food(name: 'Avocado', kcalPer100: 160, proteinPer100: 2.0, carbsPer100: 8.5, fatPer100: 14.7, category: 'Fruit', typicalServingGrams: 100),

  // Vegetables
  Food(name: 'Broccoli', kcalPer100: 34, proteinPer100: 2.8, carbsPer100: 6.6, fatPer100: 0.4, category: 'Vegetables', typicalServingGrams: 90),
  Food(name: 'Carrot', kcalPer100: 41, proteinPer100: 0.9, carbsPer100: 9.6, fatPer100: 0.2, category: 'Vegetables', typicalServingGrams: 60),
  Food(name: 'Tomato', kcalPer100: 18, proteinPer100: 0.9, carbsPer100: 3.9, fatPer100: 0.2, category: 'Vegetables', typicalServingGrams: 120),
  Food(name: 'Cucumber', kcalPer100: 15, proteinPer100: 0.7, carbsPer100: 3.6, fatPer100: 0.1, category: 'Vegetables', typicalServingGrams: 100),
  Food(name: 'Spinach', kcalPer100: 23, proteinPer100: 2.9, carbsPer100: 3.6, fatPer100: 0.4, category: 'Vegetables', typicalServingGrams: 60),
  Food(name: 'Green salad', kcalPer100: 17, proteinPer100: 1.2, carbsPer100: 3.3, fatPer100: 0.2, category: 'Vegetables', typicalServingGrams: 150),
  Food(name: 'Potato (boiled)', kcalPer100: 87, proteinPer100: 1.9, carbsPer100: 20.1, fatPer100: 0.1, category: 'Vegetables', typicalServingGrams: 150),
  Food(name: 'Sweet potato (baked)', kcalPer100: 90, proteinPer100: 2.0, carbsPer100: 20.7, fatPer100: 0.2, category: 'Vegetables', typicalServingGrams: 150),
  Food(name: 'Green peas', kcalPer100: 81, proteinPer100: 5.4, carbsPer100: 14.5, fatPer100: 0.4, category: 'Vegetables', typicalServingGrams: 80),
  Food(name: 'Sweet corn', kcalPer100: 86, proteinPer100: 3.3, carbsPer100: 19.0, fatPer100: 1.4, category: 'Vegetables', typicalServingGrams: 100),
  Food(name: 'Onion', kcalPer100: 40, proteinPer100: 1.1, carbsPer100: 9.3, fatPer100: 0.1, category: 'Vegetables', typicalServingGrams: 70),

  // Grains & breads
  Food(name: 'White rice (cooked)', kcalPer100: 130, proteinPer100: 2.7, carbsPer100: 28.2, fatPer100: 0.3, category: 'Grains', typicalServingGrams: 160),
  Food(name: 'Brown rice (cooked)', kcalPer100: 112, proteinPer100: 2.3, carbsPer100: 23.5, fatPer100: 0.8, category: 'Grains', typicalServingGrams: 160),
  Food(name: 'Oats (dry)', kcalPer100: 379, proteinPer100: 13.2, carbsPer100: 67.7, fatPer100: 6.5, category: 'Grains', typicalServingGrams: 40),
  Food(name: 'White bread', kcalPer100: 265, proteinPer100: 9.0, carbsPer100: 49.0, fatPer100: 3.2, category: 'Grains', typicalServingGrams: 30),
  Food(name: 'Whole wheat bread', kcalPer100: 247, proteinPer100: 13.0, carbsPer100: 41.0, fatPer100: 3.4, category: 'Grains', typicalServingGrams: 30),
  Food(name: 'Pasta (cooked)', kcalPer100: 158, proteinPer100: 5.8, carbsPer100: 30.9, fatPer100: 0.9, category: 'Grains', typicalServingGrams: 140),
  Food(name: 'Roti / chapati', kcalPer100: 297, proteinPer100: 9.8, carbsPer100: 46.0, fatPer100: 7.5, category: 'Grains', typicalServingGrams: 40),
  Food(name: 'Idli', kcalPer100: 146, proteinPer100: 4.5, carbsPer100: 30.0, fatPer100: 0.5, category: 'Grains', typicalServingGrams: 40),
  Food(name: 'Dosa (plain)', kcalPer100: 168, proteinPer100: 3.9, carbsPer100: 29.0, fatPer100: 3.7, category: 'Grains', typicalServingGrams: 90),
  Food(name: 'Quinoa (cooked)', kcalPer100: 120, proteinPer100: 4.4, carbsPer100: 21.3, fatPer100: 1.9, category: 'Grains', typicalServingGrams: 150),
  Food(name: 'Corn flakes', kcalPer100: 357, proteinPer100: 7.5, carbsPer100: 84.0, fatPer100: 0.4, category: 'Grains', typicalServingGrams: 30),

  // Protein
  Food(name: 'Chicken breast (cooked)', kcalPer100: 165, proteinPer100: 31.0, carbsPer100: 0, fatPer100: 3.6, category: 'Protein', typicalServingGrams: 120),
  Food(name: 'Egg (boiled)', kcalPer100: 155, proteinPer100: 12.6, carbsPer100: 1.1, fatPer100: 10.6, category: 'Protein', typicalServingGrams: 50),
  Food(name: 'Salmon (cooked)', kcalPer100: 206, proteinPer100: 22.0, carbsPer100: 0, fatPer100: 12.4, category: 'Protein', typicalServingGrams: 120),
  Food(name: 'Tuna (canned in water)', kcalPer100: 116, proteinPer100: 25.5, carbsPer100: 0, fatPer100: 0.8, category: 'Protein', typicalServingGrams: 85),
  Food(name: 'Shrimp (cooked)', kcalPer100: 99, proteinPer100: 24.0, carbsPer100: 0.2, fatPer100: 0.3, category: 'Protein', typicalServingGrams: 85),
  Food(name: 'Ground beef 85% (cooked)', kcalPer100: 250, proteinPer100: 26.0, carbsPer100: 0, fatPer100: 15.0, category: 'Protein', typicalServingGrams: 100),
  Food(name: 'Turkey breast (cooked)', kcalPer100: 147, proteinPer100: 30.0, carbsPer100: 0, fatPer100: 2.0, category: 'Protein', typicalServingGrams: 100),
  Food(name: 'Tofu (firm)', kcalPer100: 144, proteinPer100: 17.3, carbsPer100: 2.8, fatPer100: 8.7, category: 'Protein', typicalServingGrams: 100),
  Food(name: 'Paneer', kcalPer100: 265, proteinPer100: 18.3, carbsPer100: 1.2, fatPer100: 20.8, category: 'Protein', typicalServingGrams: 80),
  Food(name: 'Dal (cooked lentils)', kcalPer100: 116, proteinPer100: 9.0, carbsPer100: 20.1, fatPer100: 0.4, category: 'Protein', typicalServingGrams: 150),
  Food(name: 'Chickpeas (cooked)', kcalPer100: 164, proteinPer100: 8.9, carbsPer100: 27.4, fatPer100: 2.6, category: 'Protein', typicalServingGrams: 150),
  Food(name: 'Black beans (cooked)', kcalPer100: 132, proteinPer100: 8.9, carbsPer100: 23.7, fatPer100: 0.5, category: 'Protein', typicalServingGrams: 150),
  Food(name: 'Roasted chana', kcalPer100: 369, proteinPer100: 20.0, carbsPer100: 58.0, fatPer100: 6.0, category: 'Protein', typicalServingGrams: 30),

  // Dairy
  Food(name: 'Milk (whole)', kcalPer100: 61, proteinPer100: 3.2, carbsPer100: 4.8, fatPer100: 3.3, category: 'Dairy', typicalServingGrams: 240),
  Food(name: 'Milk (2%)', kcalPer100: 50, proteinPer100: 3.3, carbsPer100: 4.8, fatPer100: 2.0, category: 'Dairy', typicalServingGrams: 240),
  Food(name: 'Greek yogurt (plain, nonfat)', kcalPer100: 59, proteinPer100: 10.2, carbsPer100: 3.6, fatPer100: 0.4, category: 'Dairy', typicalServingGrams: 170),
  Food(name: 'Yogurt / curd (plain)', kcalPer100: 61, proteinPer100: 3.5, carbsPer100: 4.7, fatPer100: 3.3, category: 'Dairy', typicalServingGrams: 150),
  Food(name: 'Cheddar cheese', kcalPer100: 403, proteinPer100: 24.9, carbsPer100: 1.3, fatPer100: 33.1, category: 'Dairy', typicalServingGrams: 28),
  Food(name: 'Cottage cheese', kcalPer100: 98, proteinPer100: 11.1, carbsPer100: 3.4, fatPer100: 4.3, category: 'Dairy', typicalServingGrams: 110),
  Food(name: 'Butter', kcalPer100: 717, proteinPer100: 0.9, carbsPer100: 0.1, fatPer100: 81.0, category: 'Dairy', typicalServingGrams: 10),

  // Nuts, oils & extras
  Food(name: 'Almonds', kcalPer100: 579, proteinPer100: 21.2, carbsPer100: 21.6, fatPer100: 49.9, category: 'Nuts & extras', typicalServingGrams: 28),
  Food(name: 'Peanuts', kcalPer100: 567, proteinPer100: 25.8, carbsPer100: 16.1, fatPer100: 49.2, category: 'Nuts & extras', typicalServingGrams: 28),
  Food(name: 'Peanut butter', kcalPer100: 588, proteinPer100: 25.0, carbsPer100: 20.0, fatPer100: 50.0, category: 'Nuts & extras', typicalServingGrams: 32),
  Food(name: 'Walnuts', kcalPer100: 654, proteinPer100: 15.2, carbsPer100: 13.7, fatPer100: 65.2, category: 'Nuts & extras', typicalServingGrams: 28),
  Food(name: 'Cashews', kcalPer100: 553, proteinPer100: 18.2, carbsPer100: 30.2, fatPer100: 43.9, category: 'Nuts & extras', typicalServingGrams: 28),
  Food(name: 'Olive oil', kcalPer100: 884, proteinPer100: 0, carbsPer100: 0, fatPer100: 100, category: 'Nuts & extras', typicalServingGrams: 14),
  Food(name: 'Dark chocolate (70%)', kcalPer100: 598, proteinPer100: 7.8, carbsPer100: 45.9, fatPer100: 42.6, category: 'Nuts & extras', typicalServingGrams: 20),
  Food(name: 'Honey', kcalPer100: 304, proteinPer100: 0.3, carbsPer100: 82.4, fatPer100: 0, category: 'Nuts & extras', typicalServingGrams: 21),
  Food(name: 'Orange juice', kcalPer100: 45, proteinPer100: 0.7, carbsPer100: 10.4, fatPer100: 0.2, category: 'Nuts & extras', typicalServingGrams: 240),
  Food(name: 'Pizza (cheese)', kcalPer100: 266, proteinPer100: 11.4, carbsPer100: 33.0, fatPer100: 9.7, category: 'Nuts & extras', typicalServingGrams: 107),
];

/// Simple ranked search: names that start with the query come first.
List<Food> searchBuiltIn(String query, {List<Food> extra = const []}) {
  final q = query.trim().toLowerCase();
  final all = [...extra, ...builtInFoods];
  if (q.isEmpty) return all;
  final starts = <Food>[];
  final contains = <Food>[];
  final seen = <String>{};
  for (final f in all) {
    final n = f.name.toLowerCase();
    if (!seen.add(n)) continue;
    if (n.startsWith(q) || n.split(RegExp(r'[\s/(]+')).any((w) => w.startsWith(q))) {
      starts.add(f);
    } else if (n.contains(q)) {
      contains.add(f);
    }
  }
  return [...starts, ...contains];
}

/// Best built-in match for a name returned by photo recognition.
Food? matchBuiltIn(String name) {
  final results = searchBuiltIn(name);
  return results.isEmpty ? null : results.first;
}
