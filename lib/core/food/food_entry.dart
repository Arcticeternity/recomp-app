import 'food_item.dart';
import 'meal.dart';

/// 一条食物录入记录：某食物 × 某重量，归属某餐。
class FoodEntry {
  const FoodEntry({
    required this.food,
    required this.weightGrams,
    required this.meal,
  });

  final FoodItem food;
  final double weightGrams;
  final MealType meal;

  /// 该条录入贡献的碳水（克）。
  double get carbs => _scaled(food.carbsPer100g);

  /// 该条录入贡献的蛋白质（克）。
  double get protein => _scaled(food.proteinPer100g);

  /// 该条录入贡献的脂肪（克）。
  double get fat => _scaled(food.fatPer100g);

  double _scaled(double per100) => per100 * weightGrams / 100;
}
