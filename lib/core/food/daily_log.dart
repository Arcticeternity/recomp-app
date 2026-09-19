import '../macro/macro_target.dart';
import 'food_entry.dart';
import 'macro_intake.dart';
import 'meal.dart';

/// 单日饮食日志：聚合各餐摄入，对比目标额度计算剩余。
///
/// 说明：摄入汇总采用全量求和而非增量缓存。单日录入量级（数十条）下
/// 求和是 O(n) 且微秒级，增量缓存反而引入缓存失效的 bug 风险，
/// 属不必要的复杂度。
class DailyLog {
  DailyLog({required this.target});

  /// 当日目标额度（来自 M1 计算引擎）。
  final MacroTarget target;

  final List<FoodEntry> _entries = [];

  List<FoodEntry> get entries => List.unmodifiable(_entries);

  void add(FoodEntry entry) => _entries.add(entry);

  /// 删除一条录入（按对象引用定位）。
  void remove(FoodEntry entry) => _entries.remove(entry);

  /// 用新录入替换旧录入（按对象引用定位），修改后自动重算。
  void replace(FoodEntry oldEntry, FoodEntry newEntry) {
    final i = _entries.indexOf(oldEntry);
    if (i != -1) _entries[i] = newEntry;
  }

  /// 全天已摄入总量。
  MacroIntake get totalIntake => _sum(_entries);

  /// 某餐已摄入总量。
  MacroIntake intakeFor(MealType meal) =>
      _sum(_entries.where((e) => e.meal == meal));

  /// 全天剩余额度 = 目标 - 已摄入。
  MacroIntake get remaining {
    final t = totalIntake;
    return MacroIntake(
      carbs: target.carbs - t.carbs,
      protein: target.protein - t.protein,
      fat: target.fat - t.fat,
    );
  }

  MacroIntake _sum(Iterable<FoodEntry> entries) {
    var carbs = 0.0;
    var protein = 0.0;
    var fat = 0.0;
    for (final e in entries) {
      carbs += e.carbs;
      protein += e.protein;
      fat += e.fat;
    }
    return MacroIntake(carbs: carbs, protein: protein, fat: fat);
  }
}
