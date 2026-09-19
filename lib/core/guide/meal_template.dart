/// 三餐模板中的单个食物项。
///
/// 份量用文字描述（如「2个」「150g」），宏量为该份的近似总量（克）。
class TemplateFoodItem {
  const TemplateFoodItem({
    required this.name,
    required this.serving,
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final String name;
  final String serving;
  final double carbs;
  final double protein;
  final double fat;
}

/// 一餐模板。
class MealTemplate {
  const MealTemplate({
    required this.name,
    required this.idea,
    required this.items,
  });

  final String name;

  /// 设计思路。
  final String idea;

  final List<TemplateFoodItem> items;

  double get carbs => items.fold(0.0, (sum, e) => sum + e.carbs);
  double get protein => items.fold(0.0, (sum, e) => sum + e.protein);
  double get fat => items.fold(0.0, (sum, e) => sum + e.fat);
}

/// 三餐模板（示例食物 + 近似宏量，实际以食物库数据为准）。
const List<MealTemplate> mealTemplates = [
  MealTemplate(
    name: '抗炎早餐',
    idea: '优质脂肪 Omega-3 + 深色果蔬 + 优质蛋白',
    items: [
      TemplateFoodItem(name: '鸡蛋', serving: '2个', carbs: 2, protein: 12, fat: 10),
      TemplateFoodItem(name: '燕麦', serving: '40g', carbs: 26, protein: 5, fat: 3),
      TemplateFoodItem(name: '蓝莓', serving: '100g', carbs: 14, protein: 0, fat: 0),
      TemplateFoodItem(name: '核桃', serving: '10g', carbs: 1, protein: 1.5, fat: 6),
    ],
  ),
  MealTemplate(
    name: '高效补给午餐',
    idea: '足量碳水 + 高蛋白 + 低脂好消化',
    items: [
      TemplateFoodItem(name: '米饭', serving: '150g', carbs: 39, protein: 4, fat: 0.5),
      TemplateFoodItem(name: '鸡胸肉', serving: '120g', carbs: 0, protein: 26, fat: 3),
      TemplateFoodItem(name: '西兰花', serving: '150g', carbs: 6, protein: 4, fat: 0),
      TemplateFoodItem(name: '橄榄油', serving: '5ml', carbs: 0, protein: 0, fat: 5),
    ],
  ),
  MealTemplate(
    name: '稳态收尾晚餐',
    idea: '慢碳水 + 蛋白 + 控脂肪，稳定夜间血糖',
    items: [
      TemplateFoodItem(name: '红薯', serving: '150g', carbs: 30, protein: 2.5, fat: 0),
      TemplateFoodItem(name: '三文鱼', serving: '100g', carbs: 0, protein: 20, fat: 10),
      TemplateFoodItem(name: '绿叶菜', serving: '200g', carbs: 5, protein: 2, fat: 0),
    ],
  ),
];
