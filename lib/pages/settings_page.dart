import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../core/format.dart';
import '../core/macro/gender.dart';
import '../core/macro/weekly_training.dart';
import '../core/profile/user_profile.dart';
import '../widgets/choice_card.dart';
import 'macro_ratio_page.dart';

/// 右上角齿轮按钮（各页面 AppBar 使用）。
Widget settingsButton(BuildContext context, AppState state) {
  return IconButton(
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsPage(state: state)),
    ),
  );
}

/// 设置页：饮食目标、档案、AI 配置、外观、关于。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final current = themeById(state.themeName);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const _SectionTitle('饮食目标'),
              _MacroRatioCard(state: state),
              const SizedBox(height: 20),
              const _SectionTitle('我的档案'),
              _ProfileSection(state: state),
              const SizedBox(height: 20),
              const _SectionTitle('AI 识别'),
              _ApiKeySection(state: state),
              const SizedBox(height: 20),
              const _SectionTitle('外观'),
              for (final t in appThemes)
                _ThemeTile(
                  theme: t,
                  selected: t.id == current.id,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    state.saveTheme(t.id);
                  },
                ),
              const SizedBox(height: 24),
              const _VersionSection(),
            ],
          );
        },
      ),
    );
  }
}

/// 分区标题：统一设置页的信息层级。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

/// 饮食目标：当前碳蛋脂配比 + 进入编辑页。
class _MacroRatioCard extends StatelessWidget {
  const _MacroRatioCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final settings = state.macroRatioSettings;
    final ratio = settings.ratio;
    final target = state.dailyTarget;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MacroRatioPage(state: state)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text('碳蛋脂配比',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(isCustom: settings.isCustom),
                  const Spacer(),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MacroCell(
                        label: '碳水',
                        perKg: ratio.carbsPerKg,
                        grams: target.carbs),
                  ),
                  Expanded(
                    child: _MacroCell(
                        label: '蛋白质',
                        perKg: ratio.proteinPerKg,
                        grams: target.protein),
                  ),
                  Expanded(
                    child: _MacroCell(
                        label: '脂肪',
                        perKg: ratio.fatPerKg,
                        grams: target.fat),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                settings.isCustom
                    ? '自定义配比 · 不会随训练时长自动调整'
                    : '跟随档案推荐值（按性别 + 每周训练时长）',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isCustom});

  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isCustom ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isCustom ? '自定义' : '推荐',
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MacroCell extends StatelessWidget {
  const _MacroCell({
    required this.label,
    required this.perKg,
    required this.grams,
  });

  final String label;
  final double perKg;
  final double grams;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text('${formatNum(perKg)} g/kg',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text('${formatNum(grams)} g/天',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _ApiKeySection extends StatefulWidget {
  const _ApiKeySection({required this.state});

  final AppState state;

  @override
  State<_ApiKeySection> createState() => _ApiKeySectionState();
}

class _ApiKeySectionState extends State<_ApiKeySection> {
  late final TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.apiKey ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    widget.state.saveApiKey(_controller.text.trim());
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('API Key 已保存')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('智谱 API Key',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('用于 AI 识别营养（glm-4-flash，免费）',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _save, child: const Text('保存')),
          ],
        ),
      ),
    );
  }
}

/// 档案修改：性别 / 体重 / 每周训练时长，改后重算配比。
class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    if (profile == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('我的档案', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('性别'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('男'),
                  selected: profile.gender == Gender.male,
                  onSelected: (_) => state
                      .saveProfile(profile.copyWith(gender: Gender.male)),
                ),
                ChoiceChip(
                  label: const Text('女'),
                  selected: profile.gender == Gender.female,
                  onSelected: (_) => state
                      .saveProfile(profile.copyWith(gender: Gender.female)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _WeightField(state: state, profile: profile),
            const SizedBox(height: 16),
            _HeightAgeField(state: state, profile: profile),
            const SizedBox(height: 16),
            Text('每周训练时长'),
            Wrap(
              spacing: 8,
              children: [
                for (final t in WeeklyTraining.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: t == profile.training,
                    onSelected: (_) =>
                        state.saveProfile(profile.copyWith(training: t)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightField extends StatefulWidget {
  const _WeightField({required this.state, required this.profile});

  final AppState state;
  final UserProfile profile;

  @override
  State<_WeightField> createState() => _WeightFieldState();
}

class _WeightFieldState extends State<_WeightField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: formatNum(widget.profile.weightKg));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final w = double.tryParse(_controller.text);
    if (w == null || w <= 0) return;
    widget.state.saveProfile(widget.profile.copyWith(weightKg: w));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '体重（kg）',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(onPressed: _save, child: const Text('更新')),
      ],
    );
  }
}

class _HeightAgeField extends StatefulWidget {
  const _HeightAgeField({required this.state, required this.profile});

  final AppState state;
  final UserProfile profile;

  @override
  State<_HeightAgeField> createState() => _HeightAgeFieldState();
}

class _HeightAgeFieldState extends State<_HeightAgeField> {
  late final TextEditingController _heightController;
  late final TextEditingController _ageController;

  @override
  void initState() {
    super.initState();
    _heightController = TextEditingController(
        text: widget.profile.heightCm > 0
            ? formatNum(widget.profile.heightCm)
            : '');
    _ageController = TextEditingController(
        text: widget.profile.age > 0 ? '${widget.profile.age}' : '');
  }

  @override
  void dispose() {
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _save() {
    final h = double.tryParse(_heightController.text) ?? 0;
    final a = int.tryParse(_ageController.text) ?? 0;
    widget.state
        .saveProfile(widget.profile.copyWith(heightCm: h, age: a));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _heightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '身高（cm）',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '年龄',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(onPressed: _save, child: const Text('更新')),
      ],
    );
  }
}

/// 主题选项：复用 ChoiceCard，前置色点 + 选中标记。
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final AppThemeDef theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceCard(
      title: theme.label,
      subtitle: theme.brightness == Brightness.dark ? '深色' : '浅色',
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(shape: BoxShape.circle, color: theme.seed),
      ),
      trailing: selected ? Icon(Icons.check_circle, color: scheme.primary) : null,
    );
  }
}

/// 版本号展示（读取 pubspec 的 version 字段）。
class _VersionSection extends StatefulWidget {
  const _VersionSection();

  @override
  State<_VersionSection> createState() => _VersionSectionState();
}

class _VersionSectionState extends State<_VersionSection> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '版本 v$_version',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
