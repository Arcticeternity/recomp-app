import '../calibration/calibration_types.dart';

/// 某一周的状态跟踪记录。
class WeeklyStatus {
  const WeeklyStatus({
    required this.weekStart,
    required this.desire,
    required this.sleep,
  });

  /// 该周起始日期。
  final DateTime weekStart;

  final TrainingDesire desire;
  final SleepQuality sleep;
}
