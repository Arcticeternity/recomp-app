import 'macro_ratio.dart';

/// 配比的有效状态：「生效配比」+「档案推荐配比」+ 是否已自定义。
///
/// 运行期组合视图，不直接持久化 —— 推荐值是「性别 + 训练时长」的函数，
/// 用户改了训练时长它就变，存下来会过期。持久化只存用户设定的配比本身
/// （见 `AppRepository.saveMacroRatio`）。
class MacroRatioSettings {
  const MacroRatioSettings._({
    required this.ratio,
    required this.recommended,
    required this.isCustom,
  });

  /// 未自定义：生效配比即档案推荐值。
  const MacroRatioSettings.recommended(MacroRatio recommended)
      : this._(ratio: recommended, recommended: recommended, isCustom: false);

  /// 已自定义：生效配比为用户设定值，推荐值由档案实时算出。
  const MacroRatioSettings.custom({
    required MacroRatio ratio,
    required MacroRatio recommended,
  }) : this._(ratio: ratio, recommended: recommended, isCustom: true);

  /// 当前生效的配比（计算引擎用它算每日目标）。
  final MacroRatio ratio;

  /// 按当前性别与训练时长应得的推荐配比。
  final MacroRatio recommended;

  final bool isCustom;

  /// 推荐值是否已被用户带偏（用于提示「当前配比与档案推荐不同」）。
  bool get differsFromRecommended => !ratio.sameAs(recommended);
}
