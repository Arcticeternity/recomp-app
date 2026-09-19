import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/calibration/calibration_engine.dart';
import 'package:recomp_app/core/calibration/calibration_types.dart';
import 'package:recomp_app/core/macro/gender.dart';
import 'package:recomp_app/core/macro/weekly_training.dart';

void main() {
  final engine = CalibrationEngine();

  group('体重趋势判定', () {
    test('10天降2.5kg → 过快 → 提碳水 +10g', () {
      final r = engine.evaluate(
        gender: Gender.male,
        currentWeightKg: 82.5,
        training: WeeklyTraining.sixToSeven,
        currentCarbsPerKg: 3.0,
        startWeightKg: 85,
        endWeightKg: 82.5,
      );
      expect(r.weeklyRateKg, closeTo(1.75, 0.01));
      expect(r.pace, FatLossPace.tooFast);
      expect(r.action, AdjustmentAction.increaseCarbs);
      expect(r.carbDeltaGrams, 10);
      expect(r.newCarbsPerKg, closeTo(3.12, 0.01)); // (3.0*82.5+10)/82.5
    });

    test('10天降0.2kg → 过慢 → 降碳水 -10g', () {
      final r = engine.evaluate(
        gender: Gender.male,
        currentWeightKg: 84.8,
        training: WeeklyTraining.twoToThree,
        currentCarbsPerKg: 2.2,
        startWeightKg: 85,
        endWeightKg: 84.8,
      );
      expect(r.weeklyRateKg, closeTo(0.14, 0.01));
      expect(r.pace, FatLossPace.tooSlow);
      expect(r.action, AdjustmentAction.decreaseCarbs);
      expect(r.carbDeltaGrams, -10);
      expect(r.newCarbsPerKg, closeTo(2.08, 0.01)); // (2.2*84.8-10)/84.8
    });

    test('10天降1kg → 正常 → 维持', () {
      final r = engine.evaluate(
        gender: Gender.male,
        currentWeightKg: 84,
        training: WeeklyTraining.twoToThree,
        currentCarbsPerKg: 2.2,
        startWeightKg: 85,
        endWeightKg: 84,
      );
      expect(r.weeklyRateKg, closeTo(0.7, 0.01));
      expect(r.pace, FatLossPace.onTrack);
      expect(r.action, AdjustmentAction.maintain);
      expect(r.carbDeltaGrams, 0);
      expect(r.newCarbsPerKg, 2.2);
    });

    test('体重上升 → 过慢', () {
      final r = engine.evaluate(
        gender: Gender.male,
        currentWeightKg: 86,
        training: WeeklyTraining.twoToThree,
        currentCarbsPerKg: 2.2,
        startWeightKg: 85,
        endWeightKg: 86,
      );
      expect(r.weeklyRateKg, closeTo(-0.7, 0.01));
      expect(r.pace, FatLossPace.tooSlow);
    });
  });

  group('辅助信号修正', () {
    test('体重正常但训练欲望低+睡眠差 → 上修为过快', () {
      final r = engine.evaluate(
        gender: Gender.male,
        currentWeightKg: 84,
        training: WeeklyTraining.twoToThree,
        currentCarbsPerKg: 2.2,
        startWeightKg: 85,
        endWeightKg: 84,
        desire: TrainingDesire.low,
        sleep: SleepQuality.poor,
      );
      expect(r.pace, FatLossPace.tooFast);
      expect(r.action, AdjustmentAction.increaseCarbs);
    });

    test('体重过慢但训练欲望高+睡眠好 → 上修为正常', () {
      final r = engine.evaluate(
        gender: Gender.male,
        currentWeightKg: 84.8,
        training: WeeklyTraining.twoToThree,
        currentCarbsPerKg: 2.2,
        startWeightKg: 85,
        endWeightKg: 84.8,
        desire: TrainingDesire.high,
        sleep: SleepQuality.good,
      );
      expect(r.pace, FatLossPace.onTrack);
      expect(r.action, AdjustmentAction.maintain);
    });
  });

  group('调整说明生成', () {
    test('男生说明含训练时长与提碳水建议', () {
      final s = engine.evaluate(
        gender: Gender.male,
        currentWeightKg: 82.5,
        training: WeeklyTraining.sixToSeven,
        currentCarbsPerKg: 3.0,
        startWeightKg: 85,
        endWeightKg: 82.5,
      ).explanation;
      expect(s, contains('每周训练 6-7小时/周'));
      expect(s, contains('提碳水'));
      expect(s, contains('肌肉'));
    });

    test('女生说明不含训练时长细分', () {
      final s = engine.evaluate(
        gender: Gender.female,
        currentWeightKg: 59,
        training: WeeklyTraining.twoToThree,
        currentCarbsPerKg: 2.25,
        startWeightKg: 60,
        endWeightKg: 59,
      ).explanation;
      expect(s, isNot(contains('每周训练')));
      expect(s, contains('维持'));
    });

    test('辅助信号写入说明', () {
      final s = engine.evaluate(
        gender: Gender.male,
        currentWeightKg: 84,
        training: WeeklyTraining.twoToThree,
        currentCarbsPerKg: 2.2,
        startWeightKg: 85,
        endWeightKg: 84,
        desire: TrainingDesire.low,
        sleep: SleepQuality.poor,
      ).explanation;
      expect(s, contains('训练欲望偏低'));
      expect(s, contains('睡眠质量偏差'));
    });
  });
}
