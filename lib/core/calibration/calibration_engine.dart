import '../format.dart';
import '../macro/gender.dart';
import '../macro/weekly_training.dart';
import 'calibration_result.dart';
import 'calibration_types.dart';

/// 动态校准引擎：10 天周期评估体重趋势，输出碳水调整建议与说明。
class CalibrationEngine {
  /// 每周期碳水小幅调整量（克/天）。
  static const double carbDeltaGrams = 10;

  /// 周降幅阈值（kg/周），经验值，可调。
  ///
  /// 周降 > [tooFastWeeklyRate] 判过快（疑似肌肉/水分流失）；
  /// 周降 < [tooSlowWeeklyRate] 判过慢。
  static const double tooFastWeeklyRate = 1.5;
  static const double tooSlowWeeklyRate = 0.3;

  /// 评估一个校准周期。
  ///
  /// [currentWeightKg] 为周期终点体重（用于换算新配比）；
  /// [currentCarbsPerKg] 为当前碳水配比（可能已非原始表值，因调整是累积的）；
  /// [desire]/[sleep] 可选，仅当两者都提供时才参与辅助修正。
  CalibrationResult evaluate({
    required Gender gender,
    required double currentWeightKg,
    required WeeklyTraining training,
    required double currentCarbsPerKg,
    required double startWeightKg,
    required double endWeightKg,
    int days = 10,
    TrainingDesire? desire,
    SleepQuality? sleep,
  }) {
    final change = endWeightKg - startWeightKg; // 负=下降
    final safeDays = days < 1 ? 1 : days; // 防除零
    final weeklyRate = -change / safeDays * 7; // 正=在减

    var pace = _paceFromRate(weeklyRate);

    // 辅助信号修正：体重趋势为主，训练欲望/睡眠为辅。
    if (desire != null && sleep != null) {
      if (pace == FatLossPace.onTrack &&
          desire == TrainingDesire.low &&
          sleep == SleepQuality.poor) {
        pace = FatLossPace.tooFast; // 恢复不足，疑似掉肌肉
      } else if (pace == FatLossPace.tooSlow &&
          desire == TrainingDesire.high &&
          sleep == SleepQuality.good) {
        pace = FatLossPace.onTrack; // 可能增肌抵消体重下降
      }
    }

    final action = _actionFromPace(pace);
    final delta = switch (action) {
      AdjustmentAction.increaseCarbs => carbDeltaGrams,
      AdjustmentAction.decreaseCarbs => -carbDeltaGrams,
      AdjustmentAction.maintain => 0.0,
    };

    final currentCarbsGrams = currentCarbsPerKg * currentWeightKg;
    final newCarbsPerKg = (currentCarbsGrams + delta) / currentWeightKg;

    final explanation = _explain(
      gender: gender,
      training: training,
      startWeightKg: startWeightKg,
      change: change,
      weeklyRate: weeklyRate,
      pace: pace,
      action: action,
      currentCarbsPerKg: currentCarbsPerKg,
      newCarbsPerKg: newCarbsPerKg,
      delta: delta,
      desire: desire,
      sleep: sleep,
    );

    return CalibrationResult(
      startWeightKg: startWeightKg,
      endWeightKg: endWeightKg,
      days: days,
      weeklyRateKg: weeklyRate,
      pace: pace,
      action: action,
      carbDeltaGrams: delta,
      newCarbsPerKg: newCarbsPerKg,
      explanation: explanation,
    );
  }

  FatLossPace _paceFromRate(double weeklyRate) {
    if (weeklyRate > tooFastWeeklyRate) return FatLossPace.tooFast;
    if (weeklyRate < tooSlowWeeklyRate) return FatLossPace.tooSlow;
    return FatLossPace.onTrack;
  }

  AdjustmentAction _actionFromPace(FatLossPace pace) => switch (pace) {
        FatLossPace.tooFast => AdjustmentAction.increaseCarbs,
        FatLossPace.tooSlow => AdjustmentAction.decreaseCarbs,
        FatLossPace.onTrack => AdjustmentAction.maintain,
      };

  String _explain({
    required Gender gender,
    required WeeklyTraining training,
    required double startWeightKg,
    required double change,
    required double weeklyRate,
    required FatLossPace pace,
    required AdjustmentAction action,
    required double currentCarbsPerKg,
    required double newCarbsPerKg,
    required double delta,
    required TrainingDesire? desire,
    required SleepQuality? sleep,
  }) {
    final trainingPart = gender == Gender.male ? '，结合你每周训练 ${training.label}' : '';

    final changeDesc = change < -0.05
        ? '下降 ${formatNum(change.abs())}kg'
        : change > 0.05
            ? '上升 ${formatNum(change)}kg'
            : '基本无变化';

    final head = '过去 10 天体重从 ${formatNum(startWeightKg)}kg'
        ' $changeDesc（周均约 ${formatNum(weeklyRate.abs())}kg）$trainingPart。';

    final String verdict;
    final String advice;
    switch (action) {
      case AdjustmentAction.increaseCarbs:
        verdict = '减脂过快，可能伴随肌肉或水分流失';
        advice = '建议小幅提碳水：从 ${formatNum(currentCarbsPerKg)} 上调到约 '
            '${formatNum(newCarbsPerKg)} g/kg（约 +${formatNum(delta)}g/天），蛋白和脂肪不变。';
      case AdjustmentAction.decreaseCarbs:
        verdict = '减脂过慢，供能结构偏保守';
        advice = '建议小幅降碳水：从 ${formatNum(currentCarbsPerKg)} 下调到约 '
            '${formatNum(newCarbsPerKg)} g/kg（约 ${formatNum(delta)}g/天），蛋白和脂肪不变。';
      case AdjustmentAction.maintain:
        verdict = '节奏正常，供能结构合理';
        advice = '维持当前配比（碳水 ${formatNum(currentCarbsPerKg)} g/kg）不变，继续观察体态变化。';
    }

    final signal = _signalDesc(desire, sleep);

    final next = action == AdjustmentAction.maintain
        ? '下个周期继续记录体重与体态，保持稳定。'
        : '下个周期观察体重降幅是否回落到每周 0.3~1.5kg 的合理区间。';

    return '$head$verdict。$signal$advice$next';
  }

  String _signalDesc(TrainingDesire? desire, SleepQuality? sleep) {
    if (desire == null || sleep == null) return '';
    final parts = <String>[];
    if (desire == TrainingDesire.low) parts.add('训练欲望偏低');
    if (sleep == SleepQuality.poor) parts.add('睡眠质量偏差');
    if (parts.isEmpty) return '';
    return '同时本周${parts.join('、')}，恢复不足信号明显。';
  }
}
