import '../macro/gender.dart';
import '../macro/macro_calculator.dart';
import '../macro/macro_ratio.dart';
import '../macro/macro_target.dart';
import '../macro/weekly_training.dart';

/// 用户档案：性别 + 体重 + 周训练时长 + 身高 + 年龄。
class UserProfile {
  const UserProfile({
    required this.gender,
    required this.weightKg,
    required this.training,
    this.heightCm = 0,
    this.age = 0,
  });

  final Gender gender;
  final double weightKg;
  final WeeklyTraining training;

  /// 身高（cm），0 表示未填。
  final double heightCm;

  /// 年龄，0 表示未填。
  final int age;

  /// 每日宏量目标（按当前生效配比计算）。
  ///
  /// 注意：这里用的是**档案推荐配比**。用户若在设置里自定义了配比，
  /// UI 请改用 `AppState.macroRatioSettings.ratio` 再调 `MacroCalculator.targetFor`，
  /// 否则自定义配比会被旁路。
  MacroTarget get target =>
      MacroCalculator().targetFor(recommendedRatio, weightKg);

  /// 按「性别 + 每周训练时长」应得的推荐配比。
  MacroRatio get recommendedRatio =>
      MacroCalculator().recommendedFor(gender, training);

  /// 当前碳水配比（g/kg），供 M3 校准引擎使用。
  double get carbsPerKg => recommendedRatio.carbsPerKg;

  /// 静息能量消耗（Mifflin-St Jeor，kcal/天）。
  ///
  /// 公式：10×体重 + 6.25×身高 − 5×年龄 + 性别常数（男 +5 / 女 −161）。
  /// 仅估算静息消耗，不含日常活动或训练消耗，不作为热量缺口计算。
  /// 身高/年龄未填时返回 null。
  double? get bmr {
    if (heightCm <= 0 || age <= 0) return null;
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return base + (gender == Gender.male ? 5 : -161);
  }

  /// 更新字段（不可变更新，体重可动态调整）。
  UserProfile copyWith({
    Gender? gender,
    double? weightKg,
    WeeklyTraining? training,
    double? heightCm,
    int? age,
  }) =>
      UserProfile(
        gender: gender ?? this.gender,
        weightKg: weightKg ?? this.weightKg,
        training: training ?? this.training,
        heightCm: heightCm ?? this.heightCm,
        age: age ?? this.age,
      );
}
