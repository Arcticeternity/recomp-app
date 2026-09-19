import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/macro/gender.dart';
import 'package:recomp_app/core/macro/macro_calculator.dart';
import 'package:recomp_app/core/macro/macro_target.dart';
import 'package:recomp_app/core/macro/weekly_training.dart';

void main() {
  final calc = MacroCalculator();

  group('男生配比表（85kg 逐一断言）', () {
    test('2-3小时 → 碳水187 / 蛋白119 / 脂肪68', () {
      final t = calc.calculate(Gender.male, 85, WeeklyTraining.twoToThree);
      expect(t.carbs, closeTo(187, 0.1));
      expect(t.protein, closeTo(119, 0.1));
      expect(t.fat, closeTo(68, 0.1));
    });

    test('4-5小时 → 碳水212.5 / 蛋白136 / 脂肪76.5', () {
      final t = calc.calculate(Gender.male, 85, WeeklyTraining.fourToFive);
      expect(t.carbs, closeTo(212.5, 0.1));
      expect(t.protein, closeTo(136, 0.1));
      expect(t.fat, closeTo(76.5, 0.1));
    });

    test('6-7小时 → 碳水255 / 蛋白144.5 / 脂肪85', () {
      final t = calc.calculate(Gender.male, 85, WeeklyTraining.sixToSeven);
      expect(t.carbs, closeTo(255, 0.1));
      expect(t.protein, closeTo(144.5, 0.1));
      expect(t.fat, closeTo(85, 0.1));
    });

    test('8-9小时 → 碳水297.5 / 蛋白153 / 脂肪85', () {
      final t = calc.calculate(Gender.male, 85, WeeklyTraining.eightToNine);
      expect(t.carbs, closeTo(297.5, 0.1));
      expect(t.protein, closeTo(153, 0.1));
      expect(t.fat, closeTo(85, 0.1));
    });
  });

  group('女生配比（按训练时长 4 档细分，60kg）', () {
    test('2-3小时 → 碳水120 / 蛋白84 / 脂肪60', () {
      final t = calc.calculate(Gender.female, 60, WeeklyTraining.twoToThree);
      expect(t.carbs, closeTo(120, 0.1));
      expect(t.protein, closeTo(84, 0.1));
      expect(t.fat, closeTo(60, 0.1));
    });

    test('4-5小时 → 碳水132 / 蛋白96 / 脂肪66', () {
      final t = calc.calculate(Gender.female, 60, WeeklyTraining.fourToFive);
      expect(t.carbs, closeTo(132, 0.1));
      expect(t.protein, closeTo(96, 0.1));
      expect(t.fat, closeTo(66, 0.1));
    });

    test('6-7小时 → 碳水150 / 蛋白102 / 脂肪66', () {
      final t = calc.calculate(Gender.female, 60, WeeklyTraining.sixToSeven);
      expect(t.carbs, closeTo(150, 0.1));
      expect(t.protein, closeTo(102, 0.1));
      expect(t.fat, closeTo(66, 0.1));
    });

    test('8-9小时 → 碳水180 / 蛋白108 / 脂肪72', () {
      final t = calc.calculate(Gender.female, 60, WeeklyTraining.eightToNine);
      expect(t.carbs, closeTo(180, 0.1));
      expect(t.protein, closeTo(108, 0.1));
      expect(t.fat, closeTo(72, 0.1));
    });
  });

  group('热量换算（4/4/9）', () {
    test('85kg 男生 2-3小时 → 1836 kcal', () {
      final t = calc.calculate(Gender.male, 85, WeeklyTraining.twoToThree);
      expect(t.calories, closeTo(1836, 1));
    });

    test('常量值正确', () {
      expect(MacroTarget.kcalPerGramCarb, 4);
      expect(MacroTarget.kcalPerGramProtein, 4);
      expect(MacroTarget.kcalPerGramFat, 9);
    });
  });

  group('配比说明生成', () {
    test('男生说明含数值推导 + 训练时长 + 性别原因', () {
      final s = calc.explain(Gender.male, 85, WeeklyTraining.twoToThree);
      expect(s, contains('85kg'));
      expect(s, contains('2-3小时/周'));
      expect(s, contains('2.2'));
      expect(s, contains('187'));
      expect(s, contains('糖原补充'));
    });

    test('女生说明含训练时长细分 + 原片系数表', () {
      final s = calc.explain(Gender.female, 60, WeeklyTraining.twoToThree);
      expect(s, contains('2-3小时/周'));
      expect(s, contains('2.0'));
      expect(s, contains('计算依据'));
      expect(s, contains('女生'));
    });
  });
}
