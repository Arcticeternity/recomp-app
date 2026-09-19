import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/macro/gender.dart';
import '../core/macro/weekly_training.dart';
import '../core/profile/user_profile.dart';
import '../widgets/choice_card.dart';

/// 首次引导：性别 → 体重 → 训练时长。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.state});

  final AppState state;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  Gender? _gender;
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  WeeklyTraining? _training;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _finish() {
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    final age = int.tryParse(_ageController.text);
    if (_gender == null || _training == null || weight == null || weight <= 0) {
      return;
    }
    widget.state.saveProfile(UserProfile(
      gender: _gender!,
      weightKg: weight,
      training: _training!,
      heightCm: height ?? 0,
      age: age ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('开始 · ${_step + 1}/5')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.25, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _buildStep(),
                ),
              ),
            ),
            Row(
              children: [
                if (_step > 0)
                  TextButton(
                    onPressed: () => setState(() => _step--),
                    child: const Text('上一步'),
                  ),
                const Spacer(),
                if (_step < 4)
                  FilledButton(
                    onPressed: () => setState(() => _step++),
                    child: const Text('下一步'),
                  )
                else
                  FilledButton(onPressed: _finish, child: const Text('完成')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _choiceStep<Gender>(
          title: '你的性别',
          values: Gender.values,
          label: (g) => g == Gender.male ? '男' : '女',
          selected: _gender,
          onSelect: (g) => setState(() => _gender = g),
        );
      case 1:
        return _numberStep('你的体重（公斤）', _weightController, 'kg', '例如 85');
      case 2:
        return _numberStep('你的身高（厘米）', _heightController, 'cm', '例如 175');
      case 3:
        return _numberStep('你的年龄', _ageController, '岁', '例如 25');
      default:
        return _choiceStep<WeeklyTraining>(
          title: '每周训练时长',
          values: WeeklyTraining.values,
          label: (t) => t.label,
          selected: _training,
          onSelect: (t) => setState(() => _training = t),
        );
    }
  }

  Widget _numberStep(
      String title, TextEditingController controller, String suffix, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            suffixText: suffix,
            hintText: hint,
          ),
        ),
      ],
    );
  }

  Widget _choiceStep<T>({
    required String title,
    required List<T> values,
    required String Function(T) label,
    required T? selected,
    required ValueChanged<T> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        for (final v in values)
          ChoiceCard(
            title: label(v),
            selected: v == selected,
            onTap: () => onSelect(v),
          ),
      ],
    );
  }
}
