import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../core/macro/macro_calculator.dart';
import '../core/macro/macro_ratio.dart';
import '../core/macro/macro_ratio_settings.dart';
import '../core/macro/macro_target.dart';
/// 从设置页进入的自定义配比编辑页（单位 g/kg 体重）。
class MacroRatioPage extends StatefulWidget {
  const MacroRatioPage({super.key, required this.state});

  final AppState state;

  @override
  State<MacroRatioPage> createState() => _MacroRatioPageState();
}

class _MacroRatioPageState extends State<MacroRatioPage> {
  late MacroRatio _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.state.macroRatioSettings.ratio;
  }

  MacroRatioSettings get _settings => widget.state.macroRatioSettings;

  /// 当前档案体重（kg），用于把 g/kg 换算成每日克数。
  double get _weightKg => widget.state.profile?.weightKg ?? 0;

  /// 滑杆拖动中只改本地状态，松手才落库，避免每次像素移动都写数据库。
  Future<void> _commit(MacroRatio next) async {
    HapticFeedback.selectionClick();
    await widget.state.saveMacroRatio(next);
    // 落库后以生效值为准刷新草稿：夹取/对齐后的值可能与传入值不同。
    if (mounted) setState(() => _draft = _settings.ratio);
  }

  Future<void> _restoreRecommended() async {
    HapticFeedback.mediumImpact();
    await widget.state.clearMacroRatio();
    if (!mounted) return;
    setState(() => _draft = _settings.recommended);
    _toast('已恢复档案推荐配比');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recommended = _settings.recommended;
    // 复用计算引擎，避免与 AppState.dailyTarget 出现两套换算逻辑。
    final target = MacroCalculator().targetFor(_draft, _weightKg);
    // 「是否自定义」由数据层决定（用户是否真的存过自定义值），
    // 不用「当前草稿是否偏离推荐」判断 —— 否则把值调回推荐值时
    // 恢复按钮会自己消失，但配比其实仍是用户的自定义值。
    final isCustom = _settings.isCustom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('碳蛋脂配比'),
        actions: [
          if (isCustom)
            TextButton(
              onPressed: _restoreRecommended,
              child: const Text('恢复推荐'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _StatusBanner(
            isCustom: isCustom,
            recommended: recommended,
            trainingLabel: widget.state.profile?.training.label,
          ),
          const SizedBox(height: 16),
          _RatioSlider(
            label: '碳水',
            hint: '训练供能主力，减脂过快时优先上调',
            color: scheme.tertiary,
            value: _draft.carbsPerKg,
            min: MacroRatioBounds.minCarbs,
            max: MacroRatioBounds.maxCarbs,
            recommended: recommended.carbsPerKg,
            grams: target.carbs,
            onChanged: (v) => setState(
                () => _draft = MacroRatioBounds.clamp(_draftWithCarbs(v))),
            onChangeEnd: (v) =>
                _commit(MacroRatioBounds.clamp(_draftWithCarbs(v))),
          ),
          _RatioSlider(
            label: '蛋白质',
            hint: '保住肌肉的关键，随训练刺激上调',
            color: scheme.primary,
            value: _draft.proteinPerKg,
            min: MacroRatioBounds.minProtein,
            max: MacroRatioBounds.maxProtein,
            recommended: recommended.proteinPerKg,
            grams: target.protein,
            onChanged: (v) => setState(
                () => _draft = MacroRatioBounds.clamp(_draftWithProtein(v))),
            onChangeEnd: (v) =>
                _commit(MacroRatioBounds.clamp(_draftWithProtein(v))),
          ),
          _RatioSlider(
            label: '脂肪',
            hint: '守住激素水平，不建议低于 0.5 g/kg',
            color: scheme.secondary,
            value: _draft.fatPerKg,
            min: MacroRatioBounds.minFat,
            max: MacroRatioBounds.maxFat,
            recommended: recommended.fatPerKg,
            grams: target.fat,
            onChanged: (v) => setState(
                () => _draft = MacroRatioBounds.clamp(_draftWithFat(v))),
            onChangeEnd: (v) => _commit(MacroRatioBounds.clamp(_draftWithFat(v))),
          ),
          const SizedBox(height: 8),
          _DailyPreview(
            target: target,
            weightKg: _weightKg,
          ),
          const SizedBox(height: 16),
          const _RangeNote(),
        ],
      ),
    );
  }

  MacroRatio _draftWithCarbs(double v) =>
      MacroRatio(carbsPerKg: v, proteinPerKg: _draft.proteinPerKg, fatPerKg: _draft.fatPerKg);

  MacroRatio _draftWithProtein(double v) =>
      MacroRatio(carbsPerKg: _draft.carbsPerKg, proteinPerKg: v, fatPerKg: _draft.fatPerKg);

  MacroRatio _draftWithFat(double v) =>
      MacroRatio(carbsPerKg: _draft.carbsPerKg, proteinPerKg: _draft.proteinPerKg, fatPerKg: v);
}

/// 顶部状态条：当前是自定义还是跟随推荐。
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.isCustom,
    required this.recommended,
    required this.trainingLabel,
  });

  final bool isCustom;
  final MacroRatio recommended;
  final String? trainingLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final note = trainingLabel == null
        ? ''
        : '（当前档案：$trainingLabel）';
    return Card(
      color: isCustom ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCustom ? Icons.tune : Icons.auto_awesome,
                  size: 18,
                  color: isCustom ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  isCustom ? '正在使用自定义配比' : '正在跟随档案推荐配比',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '档案推荐值$note：碳水 ${formatNum(recommended.carbsPerKg)} / '
              '蛋白 ${formatNum(recommended.proteinPerKg)} / '
              '脂肪 ${formatNum(recommended.fatPerKg)} g/kg',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            if (isCustom) ...[
              const SizedBox(height: 8),
              Text(
                '自定义配比不会随「每周训练时长」自动调整。',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单条配比：数字输入 + 滑块微调 + 实时克数。
///
/// 布局上数字输入独占一行：此前它和「标签 + 偏离标签」挤在同一个 Row 里，
/// 而偏离标签恰恰在用户改动配比时才出现 —— 一挤就把输入框压到十几 dp，
/// 既显示不全也点不到（手机上无法输入）。单位也因此移出输入框，
/// 避免 suffix 再吃掉本就紧张的可编辑宽度。
class _RatioSlider extends StatelessWidget {
  const _RatioSlider({
    required this.label,
    required this.hint,
    required this.color,
    required this.value,
    required this.min,
    required this.max,
    required this.recommended,
    required this.grams,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final String hint;
  final Color color;
  final double value;
  final double min;
  final double max;
  final double recommended;
  final double grams;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  /// 步进 0.05：与滑块 divisions 保持一致。
  static const double step = 0.05;

  double get _clamped => value.clamp(min, max);

  /// 夹取后回写，并做 0.05 对齐，避免出现 2.233333 这类脏值。
  void _apply(double raw) {
    final snapped = (raw / step).round() * step;
    onChangeEnd(double.parse(snapped.toStringAsFixed(2)).clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = _clamped;
    final deviation = current - recommended;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (deviation.abs() >= 0.005)
                  _DeviationChip(
                    deviation: deviation,
                    recommended: recommended,
                    color: color,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            // 输入行只放「步进 + 输入框 + 单位」，其余信息另起一行：
            // 挤在一行会在窄屏上溢出（曾经在 412dp 上就溢出 13px）。
            Row(
              children: [
                _StepButton(
                  icon: Icons.remove,
                  onTap: () => _apply(current - step),
                  tooltip: '减 $step',
                ),
                const SizedBox(width: 8),
                _RatioField(
                  value: current,
                  color: color,
                  onSubmitted: _apply,
                ),
                const SizedBox(width: 8),
                Text('g/kg',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
                const Spacer(),
                _StepButton(
                  icon: Icons.add,
                  onTap: () => _apply(current + step),
                  tooltip: '加 $step',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // 用 Flexible 而非 Spacer：Spacer 会保留两侧文本的固有宽度，
                // 窄屏或大字号下会直接溢出。
                Expanded(
                  child: Text(
                    '每日 ${formatNum(grams)} g',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '推荐 ${formatNum(recommended)} g/kg',
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    style:
                        TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            SliderTheme(
              // 输入框已经承担了精确输入，滑块只做粗调，弱化它的存在感。
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: current,
                min: min,
                max: max,
                divisions: ((max - min) / step).round(),
                activeColor: color,
                label: '${formatNum(current)} g/kg',
                onChanged: onChanged,
                onChangeEnd: (v) => _apply(v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 数字输入框：失焦或回车时提交。
class _RatioField extends StatefulWidget {
  const _RatioField({
    required this.value,
    required this.color,
    required this.onSubmitted,
  });

  final double value;
  final Color color;
  final ValueChanged<double> onSubmitted;

  @override
  State<_RatioField> createState() => _RatioFieldState();
}

class _RatioFieldState extends State<_RatioField> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  /// 真正在敲字时才为 true。用 onChanged 精确追踪，而不是靠「有没有焦点」猜 ——
  /// 否则字段只是被聚焦着（系统键盘刚弹起、用户还没改），外部改值就同步不进来。
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: formatNum(widget.value));
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _RatioField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部改值（滑块/步进/恢复推荐）时刷新显示，正在敲字则不打断。
    if (!_typing && widget.value != oldWidget.value) {
      _controller.text = formatNum(widget.value);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    _typing = false;
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null) {
      _controller.text = formatNum(widget.value); // 非法输入还原
      return;
    }
    _controller.text = formatNum(parsed);
    widget.onSubmitted(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      // 固定宽度，避免输入时布局随数字位数跳动。
      width: 84,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: scheme.onSurface),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: widget.color.withValues(alpha: 0.08),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: widget.color, width: 2),
          ),
        ),
        onChanged: (_) => _typing = true,
        onSubmitted: (_) => _commit(),
        onEditingComplete: _commit,
      ),
    );
  }
}

/// 步进按钮（±0.05）。
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: scheme.surfaceContainerHighest,
          ),
          child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// 与推荐值的偏离标记（如 +0.3）。
class _DeviationChip extends StatelessWidget {
  const _DeviationChip({
    required this.deviation,
    required this.recommended,
    required this.color,
  });

  final double deviation;
  final double recommended;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sign = deviation > 0 ? '+' : '−';
    final ratioPct = recommended > 0
        ? (deviation.abs() / recommended * 100).round()
        : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$sign${formatNum(deviation.abs())} ($ratioPct%)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 底部实时预览：每日克数 + 供能占比 + 总热量。
class _DailyPreview extends StatelessWidget {
  const _DailyPreview({required this.target, required this.weightKg});

  final MacroTarget target;
  final double weightKg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = target.calories;
    final carbPct = _pct(target.carbs * MacroTarget.kcalPerGramCarb, total);
    final proPct = _pct(target.protein * MacroTarget.kcalPerGramProtein, total);
    final fatPct = _pct(target.fat * MacroTarget.kcalPerGramFat, total);

    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('每日目标预览', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _PreviewRow(
                label: '碳水',
                grams: target.carbs,
                pct: carbPct,
                color: scheme.tertiary),
            _PreviewRow(
                label: '蛋白质',
                grams: target.protein,
                pct: proPct,
                color: scheme.primary),
            _PreviewRow(
                label: '脂肪',
                grams: target.fat,
                pct: fatPct,
                color: scheme.secondary),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text('合计热量',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('${formatNum(total)} kcal',
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '按当前体重 ${formatNum(weightKg)}kg 换算',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  static int _pct(double part, double total) =>
      total <= 0 ? 0 : (part / total * 100).round();
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.grams,
    required this.pct,
    required this.color,
  });

  final String label;
  final double grams;
  final int pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(label),
          const Spacer(),
          Text('${formatNum(grams)} g',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text('$pct%',
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// 取值区间说明。
class _RangeNote extends StatelessWidget {
  const _RangeNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      '可调区间：碳水 ${formatNum(MacroRatioBounds.minCarbs)}–'
      '${formatNum(MacroRatioBounds.maxCarbs)}、蛋白质 '
      '${formatNum(MacroRatioBounds.minProtein)}–'
      '${formatNum(MacroRatioBounds.maxProtein)}、脂肪 '
      '${formatNum(MacroRatioBounds.minFat)}–'
      '${formatNum(MacroRatioBounds.maxFat)} g/kg。'
      '过低或过高的长期配比都有风险，建议小幅调整并观察周期反馈。',
      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
    );
  }
}
