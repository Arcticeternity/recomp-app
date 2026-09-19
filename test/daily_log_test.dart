import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/food/daily_log.dart';
import 'package:recomp_app/core/food/food_entry.dart';
import 'package:recomp_app/core/food/food_item.dart';
import 'package:recomp_app/core/food/meal.dart';
import 'package:recomp_app/core/macro/gender.dart';
import 'package:recomp_app/core/macro/macro_calculator.dart';
import 'package:recomp_app/core/macro/weekly_training.dart';

void main() {
  // 85kg 男生 2-3h → 碳水187 / 蛋白119 / 脂肪68
  final target = MacroCalculator()
      .calculate(Gender.male, 85, WeeklyTraining.twoToThree);

  FoodItem food(String name) => switch (name) {
        '米饭(熟)' => const FoodItem(
            name: '米饭(熟)',
            carbsPer100g: 26,
            proteinPer100g: 2.6,
            fatPer100g: 0.3),
        '鸡胸肉' => const FoodItem(
            name: '鸡胸肉',
            carbsPer100g: 0,
            proteinPer100g: 24,
            fatPer100g: 2),
        '鸡蛋' => const FoodItem(
            name: '鸡蛋',
            carbsPer100g: 1,
            proteinPer100g: 13,
            fatPer100g: 10),
        '红薯' => const FoodItem(
            name: '红薯',
            carbsPer100g: 20,
            proteinPer100g: 1.6,
            fatPer100g: 0.2),
        '橄榄油' => const FoodItem(
            name: '橄榄油',
            carbsPer100g: 0,
            proteinPer100g: 0,
            fatPer100g: 100),
        _ => throw ArgumentError(name),
      };

  group('FoodEntry 摄入折算', () {
    test('米饭150g → 碳水39 / 蛋白3.9 / 脂肪0.45', () {
      final e = FoodEntry(
        food: food('米饭(熟)'),
        weightGrams: 150,
        meal: MealType.lunch,
      );
      expect(e.carbs, closeTo(39, 0.01));
      expect(e.protein, closeTo(3.9, 0.01));
      expect(e.fat, closeTo(0.45, 0.01));
    });
  });

  group('DailyLog 统计', () {
    test('全天摄入与分餐统计', () {
      final log = DailyLog(target: target);
      log.add(FoodEntry(food: food('米饭(熟)'), weightGrams: 150, meal: MealType.lunch));
      log.add(FoodEntry(food: food('鸡胸肉'), weightGrams: 120, meal: MealType.lunch));
      log.add(FoodEntry(food: food('鸡蛋'), weightGrams: 100, meal: MealType.breakfast));

      final total = log.totalIntake;
      expect(total.carbs, closeTo(40, 0.01)); // 39 + 0 + 1
      expect(total.protein, closeTo(45.7, 0.01)); // 3.9 + 28.8 + 13
      expect(total.fat, closeTo(12.85, 0.01)); // 0.45 + 2.4 + 10

      final lunch = log.intakeFor(MealType.lunch);
      expect(lunch.carbs, closeTo(39, 0.01));
      expect(lunch.protein, closeTo(32.7, 0.01)); // 3.9 + 28.8
      expect(lunch.fat, closeTo(2.85, 0.01)); // 0.45 + 2.4
    });

    test('剩余额度 = 目标 - 已摄入', () {
      final log = DailyLog(target: target);
      log.add(FoodEntry(food: food('鸡胸肉'), weightGrams: 200, meal: MealType.lunch));
      // 鸡胸200g → 碳水0 / 蛋白48 / 脂肪4
      final r = log.remaining;
      expect(r.carbs, closeTo(187, 0.01));
      expect(r.protein, closeTo(71, 0.01)); // 119 - 48
      expect(r.fat, closeTo(64, 0.01)); // 68 - 4
    });

    test('修改录入后自动重算', () {
      final log = DailyLog(target: target);
      final old = FoodEntry(food: food('米饭(熟)'), weightGrams: 100, meal: MealType.lunch);
      log.add(old);
      expect(log.totalIntake.carbs, closeTo(26, 0.01));

      final updated = FoodEntry(food: food('红薯'), weightGrams: 100, meal: MealType.lunch);
      log.replace(old, updated);
      expect(log.totalIntake.carbs, closeTo(20, 0.01)); // 红薯 20
    });

    test('删除录入后自动重算', () {
      final log = DailyLog(target: target);
      final a = FoodEntry(food: food('米饭(熟)'), weightGrams: 100, meal: MealType.lunch);
      final b = FoodEntry(food: food('鸡胸肉'), weightGrams: 100, meal: MealType.lunch);
      log.add(a);
      log.add(b);
      expect(log.totalIntake.protein, closeTo(26.6, 0.01)); // 2.6 + 24

      log.remove(a);
      expect(log.totalIntake.protein, closeTo(24, 0.01));
    });

    test('超标时剩余为负', () {
      final log = DailyLog(target: target);
      log.add(FoodEntry(food: food('橄榄油'), weightGrams: 100, meal: MealType.dinner));
      // 橄榄油100g → 脂肪100，超出 68
      expect(log.remaining.fat, closeTo(-32, 0.01));
    });
  });
}
