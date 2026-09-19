import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/guide/meal_template.dart';
import 'package:recomp_app/core/guide/rebound_notice.dart';
import 'package:recomp_app/core/guide/sodium_guide.dart';

void main() {
  group('三餐模板', () {
    test('包含三个模板', () {
      expect(mealTemplates.length, 3);
      expect(mealTemplates.map((m) => m.name),
          containsAll(['抗炎早餐', '高效补给午餐', '稳态收尾晚餐']));
    });

    test('抗炎早餐小计 → 碳水43 / 蛋白18.5 / 脂肪19', () {
      final t = mealTemplates.firstWhere((m) => m.name == '抗炎早餐');
      expect(t.carbs, closeTo(43, 0.01)); // 2+26+14+1
      expect(t.protein, closeTo(18.5, 0.01)); // 12+5+0+1.5
      expect(t.fat, closeTo(19, 0.01)); // 10+3+0+6
    });

    test('高效补给午餐小计 → 碳水45 / 蛋白34 / 脂肪8.5', () {
      final t = mealTemplates.firstWhere((m) => m.name == '高效补给午餐');
      expect(t.carbs, closeTo(45, 0.01)); // 39+0+6+0
      expect(t.protein, closeTo(34, 0.01)); // 4+26+4+0
      expect(t.fat, closeTo(8.5, 0.01)); // 0.5+3+0+5
    });

    test('稳态收尾晚餐小计 → 碳水35 / 蛋白24.5 / 脂肪10', () {
      final t = mealTemplates.firstWhere((m) => m.name == '稳态收尾晚餐');
      expect(t.carbs, closeTo(35, 0.01)); // 30+0+5
      expect(t.protein, closeTo(24.5, 0.01)); // 2.5+20+2
      expect(t.fat, closeTo(10, 0.01)); // 0+10+0
    });
  });

  group('钠盐管理', () {
    test('盐 → 钠换算（1g盐 ≈ 0.4g钠）', () {
      expect(SodiumGuide.saltToSodium(10), closeTo(4, 0.001));
    });

    test('钠 → 盐换算（1g钠 ≈ 2.5g盐）', () {
      expect(SodiumGuide.sodiumToSalt(2), closeTo(5, 0.001));
    });

    test('每日盐目标 6-8g', () {
      expect(SodiumGuide.minSaltGrams, 6);
      expect(SodiumGuide.maxSaltGrams, 8);
    });

    test('高隐形盐清单含关键项', () {
      final names = hiddenSaltFoods.map((f) => f.name).toList();
      expect(names, contains('生抽'));
      expect(names, contains('泡面酱包'));
      expect(hiddenSaltFoods.firstWhere((f) => f.name == '生抽').saltGrams,
          closeTo(2, 0.01));
    });
  });

  group('防反弹说明', () {
    test('包含核心观点', () {
      expect(reboundNotice, contains('减脂 ≠ 减重'));
      expect(reboundNotice, contains('供能结构'));
      expect(reboundNotice, contains('代谢'));
    });
  });
}
