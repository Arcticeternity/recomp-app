import 'calibration_types.dart';

/// 一次 10 天校准周期的评估结果。
class CalibrationResult {
  const CalibrationResult({
    required this.startWeightKg,
    required this.endWeightKg,
    required this.days,
    required this.weeklyRateKg,
    required this.pace,
    required this.action,
    required this.carbDeltaGrams,
    required this.newCarbsPerKg,
    required this.explanation,
  });

  final double startWeightKg;
  final double endWeightKg;
  final int days;

  /// 周均减重（kg），正=下降，负=上升。
  final double weeklyRateKg;

  final FatLossPace pace;
  final AdjustmentAction action;

  /// 每天碳水调整量（克，正=加，负=减）。
  final double carbDeltaGrams;

  /// 调整后的碳水配比（g/kg）。
  final double newCarbsPerKg;

  /// 结合性别与运动数据生成的调整说明。
  final String explanation;
}
