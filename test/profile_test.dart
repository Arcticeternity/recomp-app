import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/calibration/calibration_types.dart';
import 'package:recomp_app/core/macro/gender.dart';
import 'package:recomp_app/core/macro/weekly_training.dart';
import 'package:recomp_app/core/profile/status_tracker.dart';
import 'package:recomp_app/core/profile/user_profile.dart';
import 'package:recomp_app/core/profile/weekly_status.dart';

void main() {
  group('UserProfile', () {
    test('生成每日宏量目标（85kg 男 2-3h）', () {
      const p = UserProfile(
        gender: Gender.male,
        weightKg: 85,
        training: WeeklyTraining.twoToThree,
      );
      final t = p.target;
      expect(t.carbs, closeTo(187, 0.1));
      expect(t.protein, closeTo(119, 0.1));
      expect(t.fat, closeTo(68, 0.1));
    });

    test('carbsPerKg 正确（6-7h → 3.0）', () {
      const p = UserProfile(
        gender: Gender.male,
        weightKg: 85,
        training: WeeklyTraining.sixToSeven,
      );
      expect(p.carbsPerKg, 3.0);
    });

    test('copyWith 更新体重后目标重算', () {
      const p = UserProfile(
        gender: Gender.male,
        weightKg: 85,
        training: WeeklyTraining.twoToThree,
      );
      final p2 = p.copyWith(weightKg: 70);
      expect(p2.weightKg, 70);
      expect(p2.gender, Gender.male); // 其他字段不变
      expect(p2.target.carbs, closeTo(154, 0.1)); // 2.2 × 70
    });

    test('女生档案按训练时长分档（2-3h → 碳水2.0）', () {
      const p = UserProfile(
        gender: Gender.female,
        weightKg: 60,
        training: WeeklyTraining.twoToThree,
      );
      expect(p.carbsPerKg, 2.0);
      expect(p.target.carbs, closeTo(120, 0.1));
    });

    test('BMR：男 85kg 175cm 25岁 → 1823.75', () {
      const p = UserProfile(
        gender: Gender.male,
        weightKg: 85,
        training: WeeklyTraining.twoToThree,
        heightCm: 175,
        age: 25,
      );
      expect(p.bmr, closeTo(1823.75, 0.1));
    });

    test('BMR：女 60kg 165cm 25岁 → 1345.25', () {
      const p = UserProfile(
        gender: Gender.female,
        weightKg: 60,
        training: WeeklyTraining.twoToThree,
        heightCm: 165,
        age: 25,
      );
      expect(p.bmr, closeTo(1345.25, 0.1));
    });

    test('BMR：未填身高年龄返回 null', () {
      const p = UserProfile(
        gender: Gender.male,
        weightKg: 85,
        training: WeeklyTraining.twoToThree,
      );
      expect(p.bmr, isNull);
    });
  });

  group('StatusTracker', () {
    test('记录并覆盖同周', () {
      final tracker = StatusTracker();
      final week = DateTime(2026, 9, 1);
      tracker.record(WeeklyStatus(
          weekStart: week, desire: TrainingDesire.high, sleep: SleepQuality.good));
      expect(tracker.records.length, 1);

      tracker.record(WeeklyStatus(
          weekStart: week, desire: TrainingDesire.low, sleep: SleepQuality.poor));
      expect(tracker.records.length, 1);
      expect(tracker.records.first.desire, TrainingDesire.low);
    });

    test('latest 返回最近一周', () {
      final tracker = StatusTracker();
      tracker.record(WeeklyStatus(
          weekStart: DateTime(2026, 9, 1),
          desire: TrainingDesire.high,
          sleep: SleepQuality.good));
      tracker.record(WeeklyStatus(
          weekStart: DateTime(2026, 9, 8),
          desire: TrainingDesire.low,
          sleep: SleepQuality.poor));
      expect(tracker.latest!.desire, TrainingDesire.low);
      expect(tracker.latest!.sleep, SleepQuality.poor);
    });

    test('空跟踪器 latest 为 null', () {
      expect(StatusTracker().latest, isNull);
    });
  });
}
