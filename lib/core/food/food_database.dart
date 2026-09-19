import 'food_item.dart';

/// 食物数据库：预置库（已清空）+ 用户自定义食物。
///
/// v4.0 起预置库清空，食物由用户手动添加或 AI 识别转存进入，
/// 两者共用同一个自定义食物库。
class FoodDatabase {
  final List<FoodItem> _custom = [];

  /// 预置食物库（v4.0 起清空，由用户自己添加）。
  static const List<FoodItem> seedFoods = [];

  /// 全部可检索食物：预置库 + 自定义。
  List<FoodItem> get all => [...seedFoods, ..._custom];

  /// 添加用户自定义食物。
  void addCustom(FoodItem item) => _custom.add(item);

  /// 按名称模糊搜索（不区分大小写，包含匹配）。
  /// 空查询返回全部。
  List<FoodItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  /// 由「整份总宏量 + 重量」反推每 100g 宏量，构造食物。
  ///
  /// 适合录入小众食物时按营养标签的整份数据填写。
  static FoodItem fromTotal({
    required String name,
    required double weightGrams,
    required double carbs,
    required double protein,
    required double fat,
  }) {
    return FoodItem(
      name: name,
      carbsPer100g: carbs / weightGrams * 100,
      proteinPer100g: protein / weightGrams * 100,
      fatPer100g: fat / weightGrams * 100,
    );
  }
}
