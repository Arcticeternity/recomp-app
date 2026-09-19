/// 一个食物条目，宏量按每 100g 计。
///
/// 同时承载「食物库内置」与「用户自定义小众食物」两类来源。
class FoodItem {
  const FoodItem({
    required this.name,
    required this.carbsPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
  });

  final String name;
  final double carbsPer100g;
  final double proteinPer100g;
  final double fatPer100g;
}
