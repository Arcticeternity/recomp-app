import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../core/macro/macro_calculator.dart';
import '../core/macro/weekly_training.dart';
import '../core/profile/user_profile.dart';
import 'settings_page.dart';

/// 计算页：展示配比结果与说明，支持编辑体重/训练时长。
class CalculatePage extends StatelessWidget {
  const CalculatePage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final profile = state.profile;
        if (profile == null) return const SizedBox.shrink();
        final calc = MacroCalculator();
        final target = state.dailyTarget;
        final ratioState = state.macroRatioSettings;

        return Scaffold(
          appBar: AppBar(
            title: const Text('计算'),
            actions: [settingsButton(context, state)],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('每日目标',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _MacroRow(label: '碳水', grams: target.carbs),
                      _MacroRow(label: '蛋白质', grams: target.protein),
                      _MacroRow(label: '脂肪', grams: target.fat),
                      const Divider(),
                      Text('总热量 ${formatNum(target.calories)} kcal',
                          style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('配比说明',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(calc.explain(
                          profile.gender,
                          profile.weightKg,
                          profile.training,
                          ratioState)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('静息能量消耗参考',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (profile.bmr != null)
                        Text('${formatNum(profile.bmr!)} kcal/天',
                            style: Theme.of(context).textTheme.headlineSmall)
                      else
                        Text('填写身高、年龄后显示',
                            style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text(
                        '仅估算静息能量消耗，不含日常活动或训练消耗，不作为热量缺口计算。',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _WeightEditor(state: state, profile: profile),
              const SizedBox(height: 16),
              _TrainingEditor(state: state, profile: profile),
            ],
          ),
        );
      },
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.label, required this.grams});

  final String label;
  final double grams;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label)),
          Text('${formatNum(grams)} g',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _WeightEditor extends StatefulWidget {
  const _WeightEditor({required this.state, required this.profile});

  final AppState state;
  final UserProfile profile;

  @override
  State<_WeightEditor> createState() => _WeightEditorState();
}

class _WeightEditorState extends State<_WeightEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: formatNum(widget.profile.weightKg));
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
            FilledButton(onPressed: _save, child: const Text('更新体重')),
          ],
        ),
      ),
    );
  }
}

class _TrainingEditor extends StatelessWidget {
  const _TrainingEditor({required this.state, required this.profile});

  final AppState state;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('每周训练时长', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in WeeklyTraining.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: t == profile.training,
                    onSelected: (_) => state
                        .saveProfile(profile.copyWith(training: t)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
