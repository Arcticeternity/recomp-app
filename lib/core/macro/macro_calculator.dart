import '../format.dart';
import 'gender.dart';
import 'macro_ratio.dart';
import 'macro_ratio_settings.dart';
import 'macro_target.dart';
import 'weekly_training.dart';

/// 宏量计算引擎：输入性别/体重/训练时长，输出每日目标与配比说明。
class MacroCalculator {
  /// 依据性别与训练时长取推荐配比。
  MacroRatio ratioFor(Gender gender, WeeklyTraining training) {
    return gender == Gender.male ? maleRatios[training]! : femaleRatios[training]!;
  }

  /// 按性别与训练时长取推荐配比（[ratioFor] 的语义化别名）。
  MacroRatio recommendedFor(Gender gender, WeeklyTraining training) =>
      ratioFor(gender, training);

  /// 按给定配比与体重计算每日目标（保留 1 位小数）。
  ///
  /// 配比由调用方决定（档案推荐值或用户自定义值），
  /// 计算引擎不再自己去查表，避免自定义配比被旁路。
  MacroTarget targetFor(MacroRatio ratio, double weightKg) => MacroTarget(
        carbs: _round1(weightKg * ratio.carbsPerKg),
        protein: _round1(weightKg * ratio.proteinPerKg),
        fat: _round1(weightKg * ratio.fatPerKg),
      );

  /// 按档案推荐配比计算每日目标（便捷入口，等价于
  /// `targetFor(recommendedFor(gender, training), weightKg)`）。
  MacroTarget calculate(
    Gender gender,
    double weightKg,
    WeeklyTraining training,
  ) =>
      targetFor(recommendedFor(gender, training), weightKg);

  /// 生成配比说明：数值推导 + 性别差异化原因 + 原片系数表。
  String explain(
    Gender gender,
    double weightKg,
    WeeklyTraining training, [
    MacroRatioSettings? settings,
  ]) {
    final ratio = settings?.ratio ?? ratioFor(gender, training);
    final target = targetFor(ratio, weightKg);
    final custom = settings?.isCustom ?? false;

    final derivation = custom
        ? '按你自定义的配比、当前 ${formatNum(weightKg)}kg（${training.label}）：'
            '碳水 ${formatNum(ratio.carbsPerKg)}×${formatNum(weightKg)}=${formatNum(target.carbs)}g、'
            '蛋白质 ${formatNum(ratio.proteinPerKg)}×${formatNum(weightKg)}=${formatNum(target.protein)}g、'
            '脂肪 ${formatNum(ratio.fatPerKg)}×${formatNum(weightKg)}=${formatNum(target.fat)}g。'
        : '按你当前 ${formatNum(weightKg)}kg、${training.label}：'
            '碳水 ${formatNum(ratio.carbsPerKg)}×${formatNum(weightKg)}=${formatNum(target.carbs)}g、'
            '蛋白质 ${formatNum(ratio.proteinPerKg)}×${formatNum(weightKg)}=${formatNum(target.protein)}g、'
            '脂肪 ${formatNum(ratio.fatPerKg)}×${formatNum(weightKg)}=${formatNum(target.fat)}g。';

    final carbKcal = target.carbs * MacroTarget.kcalPerGramCarb;
    final total = target.calories;
    final carbPct = total > 0 ? (carbKcal / total * 100) : 0.0;
    final energy = '碳水供能 ${carbKcal.round()} kcal，'
        '占比约 ${carbPct.round()}%。';

    final reason = custom
        ? _customReason(settings!)
        : (gender == Gender.male ? _maleReason() : _femaleReason());

    const basis = '计算依据（单位 g/kg，数据以视频最终系数表为准）：\n'
        '男生：2-3h 碳水2.2/蛋白1.4/脂肪0.8；4-5h 2.5/1.6/0.9；'
        '6-7h 3.0/1.7/1.0；8-9h 3.5/1.8/1.0。\n'
        '女生：2-3h 碳水2.0/蛋白1.4/脂肪1.0；4-5h 2.2/1.6/1.1；'
        '6-7h 2.5/1.7/1.1；8-9h 3.0/1.8/1.2。';

    return '$derivation$energy\n\n$reason\n\n$basis';
  }

  /// 自定义配比的说明：与档案推荐值逐项对比，给出偏离方向。
  String _customReason(MacroRatioSettings settings) {
    final r = settings.recommended;
    final c = settings.ratio;
    final parts = <String>[
      _deltaText('碳水', r.carbsPerKg, c.carbsPerKg),
      _deltaText('蛋白质', r.proteinPerKg, c.proteinPerKg),
      _deltaText('脂肪', r.fatPerKg, c.fatPerKg),
    ];
    return '你正在使用自定义配比（档案推荐值：'
        '碳水 ${formatNum(r.carbsPerKg)} / 蛋白 ${formatNum(r.proteinPerKg)} / '
        '脂肪 ${formatNum(r.fatPerKg)} g/kg）。'
        '相对推荐值：${parts.join('，')}。'
        '自定义配比不会自动跟随「每周训练时长」变化调整，如需回到推荐值请在设置里恢复。';
  }

  String _deltaText(String label, double recommended, double actual) {
    final diff = actual - recommended;
    if (diff.abs() < 0.001) return '$label持平';
    final sign = diff > 0 ? '+' : '−';
    return '$label$sign${formatNum(diff.abs())}';
  }

  String _maleReason() =>
      '男生配比按每周训练时长逐级上调碳水与蛋白质：训练量越大，'
      '糖原补充与肌肉修复需求越高。';

  String _femaleReason() =>
      '女生配比同样按每周训练时长 4 档细分。脂肪下限略高于男生：'
      '脂肪摄入过低会干扰雌激素与月经周期，需保留更高安全下限。';

  static double _round1(double v) => (v * 10).roundToDouble() / 10;
}
