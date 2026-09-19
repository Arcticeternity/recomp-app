import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/food/food_database.dart';
import 'package:recomp_app/core/food/food_item.dart';

void main() {
  late FoodDatabase db;

  setUp(() => db = FoodDatabase());

  group('搜索', () {
    test('模糊匹配自定义食物', () {
      db.addCustom(const FoodItem(
          name: '鸡胸肉', carbsPer100g: 0, proteinPer100g: 24, fatPer100g: 2));
      db.addCustom(const FoodItem(
          name: '鸡蛋', carbsPer100g: 1, proteinPer100g: 13, fatPer100g: 10));
      final names = db.search('鸡').map((f) => f.name).toList();
      expect(names, contains('鸡胸肉'));
      expect(names, contains('鸡蛋'));
    });

    test('空库返回空', () {
      expect(db.search(''), isEmpty);
    });

    test('无匹配返回空', () {
      expect(db.search('不存在的食物xyz'), isEmpty);
    });
  });

  group('自定义食物', () {
    test('添加后可被搜索到', () {
      db.addCustom(const FoodItem(
        name: '螺旋藻粉',
        carbsPer100g: 8,
        proteinPer100g: 60,
        fatPer100g: 5,
      ));
      final r = db.search('螺旋藻');
      expect(r.length, 1);
      expect(r.first.proteinPer100g, 60);
    });

    test('fromTotal 按整份总宏量反推每100g', () {
      final f = FoodDatabase.fromTotal(
        name: '某能量棒',
        weightGrams: 60,
        carbs: 30,
        protein: 12,
        fat: 6,
      );
      expect(f.carbsPer100g, closeTo(50, 0.01));
      expect(f.proteinPer100g, closeTo(20, 0.01));
      expect(f.fatPer100g, closeTo(10, 0.01));
    });
  });
}
