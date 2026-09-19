/// 钠盐管理指南。
///
/// 关键换算：1g 钠 = 2.5g 盐（NaCl 分子量 58.5，钠 23，故 盐 = 钠 × 2.5）。
class SodiumGuide {
  /// 每日盐摄入目标（克，盐，非钠）。
  static const double minSaltGrams = 6;
  static const double maxSaltGrams = 8;

  /// 盐 → 钠：1g 盐 ≈ 0.4g 钠。
  static double saltToSodium(double saltGrams) => saltGrams * 0.4;

  /// 钠 → 盐：1g 钠 ≈ 2.5g 盐。
  static double sodiumToSalt(double sodiumGrams) => sodiumGrams * 2.5;
}

/// 常见高隐形盐食物（盐含量为近似值）。
class HiddenSaltFood {
  const HiddenSaltFood({
    required this.name,
    required this.serving,
    required this.saltGrams,
  });

  final String name;
  final String serving;

  /// 该份约含盐（克）。
  final double saltGrams;
}

/// 常见高隐形盐食物清单（近似值，实际以包装标注为准）。
const List<HiddenSaltFood> hiddenSaltFoods = [
  HiddenSaltFood(name: '生抽', serving: '15ml', saltGrams: 2),
  HiddenSaltFood(name: '泡面酱包', serving: '1包', saltGrams: 4),
  HiddenSaltFood(name: '香肠/火腿', serving: '100g', saltGrams: 2.5),
  HiddenSaltFood(name: '榨菜', serving: '50g', saltGrams: 3),
  HiddenSaltFood(name: '豆瓣酱', serving: '15g', saltGrams: 1.5),
  HiddenSaltFood(name: '蚝油', serving: '15g', saltGrams: 1),
  HiddenSaltFood(name: '鸡精', serving: '5g', saltGrams: 1),
  HiddenSaltFood(name: '薯片', serving: '100g', saltGrams: 1.5),
  HiddenSaltFood(name: '话梅', serving: '50g', saltGrams: 3),
];
