import '../macro/macro_target.dart';

/// 宏量摄入量（克），用于表达「已摄入」与「剩余额度」。
///
/// 与 [MacroTarget] 结构相同但语义不同：这里是实际值，非目标值。
/// 剩余额度为负表示已超出目标。
class MacroIntake {
  const MacroIntake({
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final double carbs;
  final double protein;
  final double fat;

  double get calories =>
      carbs * MacroTarget.kcalPerGramCarb +
      protein * MacroTarget.kcalPerGramProtein +
      fat * MacroTarget.kcalPerGramFat;
}
