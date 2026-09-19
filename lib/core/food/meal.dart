/// 餐别枚举。
enum MealType {
  breakfast('早餐'),
  lunch('午餐'),
  dinner('晚餐'),
  snack('加餐');

  const MealType(this.label);

  /// 面向用户的展示文案。
  final String label;
}
