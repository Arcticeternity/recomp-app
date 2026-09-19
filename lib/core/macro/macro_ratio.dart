import 'weekly_training.dart';

/// 宏量营养素配比（克 / 公斤体重 / 天）。
class MacroRatio {
  const MacroRatio({
    required this.carbsPerKg,
    required this.proteinPerKg,
    required this.fatPerKg,
  });

  final double carbsPerKg;
  final double proteinPerKg;
  final double fatPerKg;

  /// 从 JSON 还原；字段缺失或类型不符时抛 [FormatException]。
  factory MacroRatio.fromJson(Map<String, dynamic> json) => MacroRatio(
        carbsPerKg: _readPositive(json, 'carbsPerKg'),
        proteinPerKg: _readPositive(json, 'proteinPerKg'),
        fatPerKg: _readPositive(json, 'fatPerKg'),
      );

  Map<String, dynamic> toJson() => {
        'carbsPerKg': carbsPerKg,
        'proteinPerKg': proteinPerKg,
        'fatPerKg': fatPerKg,
      };

  /// 三宏量克数是否与 [other] 一致（容差 0.001，规避浮点误差）。
  bool sameAs(MacroRatio other) =>
      (carbsPerKg - other.carbsPerKg).abs() < 0.001 &&
      (proteinPerKg - other.proteinPerKg).abs() < 0.001 &&
      (fatPerKg - other.fatPerKg).abs() < 0.001;

  static double _readPositive(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v is! num || v <= 0 || !v.isFinite) {
      throw FormatException('配比字段 $key 非法：$v');
    }
    return v.toDouble();
  }
}

/// 各宏量配比的允许范围（g/kg），用于 UI 滑块与输入校验。
///
/// 下限取自配比表最小值并留出下调空间，上限覆盖高训练量人群。
class MacroRatioBounds {
  const MacroRatioBounds._();

  static const double minCarbs = 1.0;
  static const double maxCarbs = 6.0;
  static const double minProtein = 1.0;
  static const double maxProtein = 3.0;
  static const double minFat = 0.5;
  static const double maxFat = 2.0;

  /// 配比逐项夹取到合法区间，避免非法值流入计算引擎。
  static MacroRatio clamp(MacroRatio r) => MacroRatio(
        carbsPerKg: r.carbsPerKg.clamp(minCarbs, maxCarbs),
        proteinPerKg: r.proteinPerKg.clamp(minProtein, maxProtein),
        fatPerKg: r.fatPerKg.clamp(minFat, maxFat),
      );
}

/// 男生配比表：按每周训练时长逐级上调。
const Map<WeeklyTraining, MacroRatio> maleRatios = {
  WeeklyTraining.twoToThree:
      MacroRatio(carbsPerKg: 2.2, proteinPerKg: 1.4, fatPerKg: 0.8),
  WeeklyTraining.fourToFive:
      MacroRatio(carbsPerKg: 2.5, proteinPerKg: 1.6, fatPerKg: 0.9),
  WeeklyTraining.sixToSeven:
      MacroRatio(carbsPerKg: 3.0, proteinPerKg: 1.7, fatPerKg: 1.0),
  WeeklyTraining.eightToNine:
      MacroRatio(carbsPerKg: 3.5, proteinPerKg: 1.8, fatPerKg: 1.0),
};

/// 女生配比表：按每周训练时长 4 档细分（以原片最终系数表为准）。
const Map<WeeklyTraining, MacroRatio> femaleRatios = {
  WeeklyTraining.twoToThree:
      MacroRatio(carbsPerKg: 2.0, proteinPerKg: 1.4, fatPerKg: 1.0),
  WeeklyTraining.fourToFive:
      MacroRatio(carbsPerKg: 2.2, proteinPerKg: 1.6, fatPerKg: 1.1),
  WeeklyTraining.sixToSeven:
      MacroRatio(carbsPerKg: 2.5, proteinPerKg: 1.7, fatPerKg: 1.1),
  WeeklyTraining.eightToNine:
      MacroRatio(carbsPerKg: 3.0, proteinPerKg: 1.8, fatPerKg: 1.2),
};
