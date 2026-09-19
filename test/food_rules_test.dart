import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/food/food_rules.dart';

void main() {
  group('parseProcessing', () {
    test('去皮鸡腿', () {
      final r = parseProcessing('去皮鸡腿');
      expect(r.baseName, '鸡腿');
      expect(r.peel, true);
      expect(r.noYolk, false);
    });

    test('去蛋黄鸡蛋', () {
      final r = parseProcessing('去蛋黄鸡蛋');
      expect(r.baseName, '鸡蛋');
      expect(r.noYolk, true);
      expect(r.peel, false);
    });

    test('无加工词', () {
      final r = parseProcessing('鸡胸肉');
      expect(r.baseName, '鸡胸肉');
      expect(r.peel, false);
      expect(r.noYolk, false);
    });

    test('去骨鸡腿', () {
      final r = parseProcessing('去骨鸡腿');
      expect(r.baseName, '鸡腿');
      expect(r.boneOut, true);
      expect(r.peel, false);
    });

    test('低脂牛奶', () {
      final r = parseProcessing('低脂牛奶');
      expect(r.baseName, '牛奶');
      expect(r.lowFat, true);
    });

    test('脱脂牛奶', () {
      final r = parseProcessing('脱脂牛奶');
      expect(r.baseName, '牛奶');
      expect(r.skim, true);
    });
  });

  group('applyProcessing', () {
    test('去皮：脂肪减半，蛋白碳水不变', () {
      final r = applyProcessing(0, 20, 10, peel: true, noYolk: false);
      expect(r.carbs, 0);
      expect(r.protein, 20);
      expect(r.fat, 5);
    });

    test('去蛋黄：按蛋清算', () {
      final r = applyProcessing(1, 13, 10, peel: false, noYolk: true);
      expect(r.carbs, 1);
      expect(r.protein, 10);
      expect(r.fat, 0);
    });

    test('无加工：原样返回', () {
      final r = applyProcessing(2, 3, 4, peel: false, noYolk: false);
      expect(r.carbs, 2);
      expect(r.protein, 3);
      expect(r.fat, 4);
    });

    test('去骨：脂肪×0.8', () {
      final r =
          applyProcessing(0, 20, 10, peel: false, noYolk: false, boneOut: true);
      expect(r.fat, 8);
    });

    test('低脂：脂肪×0.4', () {
      final r =
          applyProcessing(5, 3, 3.5, peel: false, noYolk: false, lowFat: true);
      expect(r.fat, closeTo(1.4, 0.01));
    });

    test('脱脂：脂肪近似0', () {
      final r =
          applyProcessing(5, 3, 3.5, peel: false, noYolk: false, skim: true);
      expect(r.fat, closeTo(0.105, 0.01));
    });

    test('去蛋黄鸡蛋 ≠ 鸡蛋（蛋清算）', () {
      final whole = applyProcessing(1, 13, 10, peel: false, noYolk: false);
      final yolkless = applyProcessing(1, 13, 10, peel: false, noYolk: true);
      expect(whole.fat, 10); // 完整鸡蛋含蛋黄
      expect(yolkless.fat, 0); // 去蛋黄后脂肪≈0
      expect(yolkless.protein, 10);
    });
  });

  group('unitWeights', () {
    test('鸡蛋 50g/个', () => expect(lookupUnitWeight('鸡蛋'), 50));
    test('鸡腿 100g/只', () => expect(lookupUnitWeight('鸡腿'), 100));
    test('鸭腿 110g/只', () => expect(lookupUnitWeight('鸭腿'), 110));
    test('面包 30g/片', () => expect(lookupUnitWeight('面包'), 30));
    test('未知返回 null', () => expect(lookupUnitWeight('未知食物'), isNull));
  });
}
