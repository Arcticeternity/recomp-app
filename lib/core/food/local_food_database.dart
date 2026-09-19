import 'package:sqflite/sqflite.dart' show Database;

import '../storage/static_db_loader.dart';
import 'food_item.dart';

/// 本地《中国食物成分表》查询（约 1700 种，源自 cn-food-mcp）。
class LocalFoodDatabase {
  LocalFoodDatabase(this._db);

  final Database _db;

  /// 打开内置食物成分表（生产用）。
  ///
  /// 移动/桌面复制 `.db` 到可写目录；Web 把 SQL dump 灌进内存库。
  static Future<LocalFoodDatabase> openFromAsset() async {
    final db = await openStaticDatabase(
      dbAsset: 'assets/food_composition.db',
      sqlAsset: 'assets/food_composition.sql',
    );
    return LocalFoodDatabase(db);
  }

  /// 直接打开指定文件（测试用；Web 不支持）。
  static Future<LocalFoodDatabase> openFromFile(String path) async {
    final db = await openStaticDatabaseFromFile(path);
    return LocalFoodDatabase(db);
  }

  /// 模糊匹配，返回最接近的 [FoodItem] 列表（短名字优先，最多 10 条）。
  Future<List<FoodItem>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final rows = await _db.query(
      'food',
      where: 'name LIKE ?',
      whereArgs: ['%$q%'],
      limit: 50,
    );
    final items = rows
        .map((r) => FoodItem(
              name: r['name'] as String,
              carbsPer100g: (r['carbohydrate'] as num).toDouble(),
              proteinPer100g: (r['protein'] as num).toDouble(),
              fatPer100g: (r['fat'] as num).toDouble(),
            ))
        .toList();

    // 精确匹配 > 前缀匹配 > 其他，同级按名称长度升序。
    // 避免「鸡蛋」被「鸡蛋白」抢位（反例：蛋清脂肪≈0 vs 全蛋脂肪≈11）。
    int rank(String name) {
      if (name == q) return 0;
      if (name.startsWith(q)) return 1;
      return 2;
    }

    items.sort((a, b) {
      final ra = rank(a.name);
      final rb = rank(b.name);
      if (ra != rb) return ra.compareTo(rb);
      return a.name.length.compareTo(b.name.length);
    });
    return items.take(10).toList();
  }

  Future<void> close() => _db.close();
}
