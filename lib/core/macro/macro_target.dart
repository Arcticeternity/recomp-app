/// 每日宏量目标（克）与总热量（千卡）。
class MacroTarget {
  const MacroTarget({
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final double carbs;
  final double protein;
  final double fat;

  /// 热量换算常数（kcal/g）。
  static const double kcalPerGramCarb = 4;
  static const double kcalPerGramProtein = 4;
  static const double kcalPerGramFat = 9;

  /// 每日总热量。
  double get calories =>
      carbs * kcalPerGramCarb +
      protein * kcalPerGramProtein +
      fat * kcalPerGramFat;
}
