import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/food/smart_input.dart';

void main() {
  group('parseSmartInput', () {
    test('含完整宏量：面包15g 碳水7g 蛋白3g', () {
      final r = parseSmartInput('面包15g 碳水7g 蛋白3g');
      expect(r.name, '面包');
      expect(r.weightGrams, 15);
      expect(r.carbs, 7);
      expect(r.protein, 3);
      expect(r.fat, isNull);
      expect(r.hasMacros, true);
    });

    test('仅食物名+重量：鸡胸肉200g', () {
      final r = parseSmartInput('鸡胸肉200g');
      expect(r.name, '鸡胸肉');
      expect(r.weightGrams, 200);
      expect(r.carbs, isNull);
      expect(r.protein, isNull);
      expect(r.fat, isNull);
      expect(r.hasMacros, false);
    });

    test('仅食物名：面包', () {
      final r = parseSmartInput('面包');
      expect(r.name, '面包');
      expect(r.weightGrams, isNull);
      expect(r.hasMacros, false);
    });

    test('中文单位：牛肉面 100克 蛋白质20克', () {
      final r = parseSmartInput('牛肉面 100克 蛋白质20克');
      expect(r.name, '牛肉面');
      expect(r.weightGrams, 100);
      expect(r.protein, 20);
    });

    test('脂肪也能解析', () {
      final r = parseSmartInput('牛油果50g 脂肪7g');
      expect(r.name, '牛油果');
      expect(r.weightGrams, 50);
      expect(r.fat, 7);
    });

    test('数量词：两个鸡蛋', () {
      final r = parseSmartInput('两个鸡蛋');
      expect(r.name, '鸡蛋');
      expect(r.quantity, 2);
      expect(r.weightGrams, isNull);
    });

    test('数量词：2个鸡蛋', () {
      final r = parseSmartInput('2个鸡蛋');
      expect(r.quantity, 2);
    });

    test('数量词：三个鸡腿', () {
      final r = parseSmartInput('三个鸡腿');
      expect(r.quantity, 3);
    });

    test('数量词不影响重量优先', () {
      final r = parseSmartInput('两个鸡蛋200g');
      expect(r.quantity, 2);
      expect(r.weightGrams, 200);
    });

    test('半量词：半个鸡蛋', () {
      final r = parseSmartInput('半个鸡蛋');
      expect(r.quantity, 0.5);
      expect(r.name, '鸡蛋');
    });

    test('半量词：半碗米饭', () {
      final r = parseSmartInput('半碗米饭');
      expect(r.quantity, 0.5);
      expect(r.name, '米饭');
    });

    test('小数：0.5个鸡蛋', () {
      final r = parseSmartInput('0.5个鸡蛋');
      expect(r.quantity, 0.5);
    });

    test('小数：1.5碗米饭', () {
      final r = parseSmartInput('1.5碗米饭');
      expect(r.quantity, 1.5);
    });

    test('小数：2.5份', () {
      final r = parseSmartInput('2.5份面条');
      expect(r.quantity, 2.5);
    });

    test('分数：二分之一碗', () {
      final r = parseSmartInput('二分之一碗米饭');
      expect(r.quantity, closeTo(0.5, 0.001));
    });

    test('分数：三分之一碗', () {
      final r = parseSmartInput('三分之一碗米饭');
      expect(r.quantity, closeTo(0.333, 0.001));
    });

    test('分数：三分之二', () {
      final r = parseSmartInput('三分之二个苹果');
      expect(r.quantity, closeTo(0.667, 0.001));
    });

    test('分数：四分之三', () {
      final r = parseSmartInput('四分之三个苹果');
      expect(r.quantity, closeTo(0.75, 0.001));
    });

    test('新量词：一条鱼', () {
      final r = parseSmartInput('一条鱼');
      expect(r.quantity, 1);
      expect(r.name, '鱼');
    });

    test('新量词：三根香蕉', () {
      final r = parseSmartInput('三根香蕉');
      expect(r.quantity, 3);
    });

    test('新量词：一袋面包', () {
      final r = parseSmartInput('一袋面包');
      expect(r.quantity, 1);
    });

    test('新量词：两盒牛奶', () {
      final r = parseSmartInput('两盒牛奶');
      expect(r.quantity, 2);
    });

    test('顺序无关：蛋白质100g', () {
      final r = parseSmartInput('蛋白质100g');
      expect(r.protein, 100);
    });

    test('顺序无关：100g蛋白质', () {
      final r = parseSmartInput('100g蛋白质');
      expect(r.protein, 100);
    });

    test('顺序无关：3g蛋白', () {
      final r = parseSmartInput('3g蛋白');
      expect(r.protein, 3);
    });

    test('多宏量顺序混合：碳水7g 3g蛋白', () {
      final r = parseSmartInput('碳水7g 3g蛋白');
      expect(r.carbs, 7);
      expect(r.protein, 3);
    });

    test('比例换算：30g蛋白粉每100g含60g蛋白质', () {
      final r = parseSmartInput('吃了30g蛋白粉，每100g有60g蛋白质');
      expect(r.name, '蛋白粉');
      expect(r.weightGrams, 30);
      expect(r.protein, 18); // 60 × 30/100
    });

    test('未报宏量保持 null（默认0由调用方处理）', () {
      final r = parseSmartInput('面包15g');
      expect(r.carbs, isNull);
      expect(r.protein, isNull);
      expect(r.fat, isNull);
    });
  });

  group('parseChineseNumber', () {
    test('单个数字', () {
      expect(parseChineseNumber('一'), 1);
      expect(parseChineseNumber('两'), 2);
      expect(parseChineseNumber('九'), 9);
    });

    test('十与十几', () {
      expect(parseChineseNumber('十'), 10);
      expect(parseChineseNumber('十二'), 12);
      expect(parseChineseNumber('十五'), 15);
    });

    test('几十', () {
      expect(parseChineseNumber('二十'), 20);
      expect(parseChineseNumber('三十五'), 35);
    });
  });
}
