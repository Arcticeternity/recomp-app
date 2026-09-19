import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/food/food_rules.dart';
import 'package:recomp_app/core/food/local_food_database.dart';

void main() {
  test('本地库模糊匹配查询', () async {
    final db =
        await LocalFoodDatabase.openFromFile('assets/food_composition.db');

    final chicken = await db.search('鸡胸');
    expect(chicken, isNotEmpty);
    expect(chicken.first.name, contains('鸡胸'));
    expect(chicken.first.proteinPer100g, greaterThan(0));

    final rice = await db.search('米饭');
    expect(rice, isNotEmpty);
    expect(rice.first.carbsPer100g, greaterThan(0));

    final none = await db.search('不存在的食物xyz');
    expect(none, isEmpty);

    await db.close();
  });

  test('精确匹配优先：鸡蛋返回全蛋非蛋清', () async {
    final db =
        await LocalFoodDatabase.openFromFile('assets/food_composition.db');

    final hits = await db.search('鸡蛋');
    expect(hits, isNotEmpty);
    expect(hits.first.name, '鸡蛋'); // 精确匹配排最前
    expect(hits.first.fatPer100g, closeTo(10, 0.5)); // 全蛋脂肪≈10，非蛋清 0.1

    await db.close();
  });

  test('牛奶能查到（本地库基础名）', () async {
    final db =
        await LocalFoodDatabase.openFromFile('assets/food_composition.db');

    final hits = await db.search('牛奶');
    expect(hits, isNotEmpty);
    expect(hits.first.name, '牛奶');

    await db.close();
  });

  test('单份营养值校准：一颗鸡蛋 → 蛋白7/脂肪5', () async {
    final db =
        await LocalFoodDatabase.openFromFile('assets/food_composition.db');

    final egg = (await db.search('鸡蛋')).first;
    final unit = lookupUnitWeight('鸡蛋')!; // 50g
    expect(egg.proteinPer100g * unit / 100, closeTo(7, 0.1));
    expect(egg.fatPer100g * unit / 100, closeTo(5, 0.1));

    await db.close();
  });

  test('单份营养值校准：鸡胸肉/鸡腿/面包', () async {
    final db =
        await LocalFoodDatabase.openFromFile('assets/food_composition.db');

    final chicken = (await db.search('鸡胸')).first;
    expect(chicken.name, '鸡胸肉');
    expect(chicken.proteinPer100g, closeTo(24, 0.1));
    expect(chicken.fatPer100g, closeTo(1, 0.1));

    final thigh = (await db.search('鸡腿')).first;
    expect(thigh.proteinPer100g, closeTo(22, 0.1));
    expect(thigh.fatPer100g, closeTo(3, 0.1));

    final bread = (await db.search('面包')).first;
    final breadUnit = lookupUnitWeight('面包')!; // 30g
    expect(bread.proteinPer100g * breadUnit / 100, closeTo(2.5, 0.1));
    expect(bread.fatPer100g * breadUnit / 100, closeTo(1, 0.1));

    await db.close();
  });
}
