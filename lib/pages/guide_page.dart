import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../core/guide/meal_template.dart';
import '../core/guide/rebound_notice.dart';
import '../core/guide/sodium_guide.dart';
import 'exercise_library_page.dart';
import 'settings_page.dart';
import 'training_program_page.dart';

/// 指南页：三餐模板、钠盐管理、防反弹说明。
class GuidePage extends StatelessWidget {
  const GuidePage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('指南'),
        actions: [settingsButton(context, state)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _EntryCard(
                  icon: Icons.fitness_center,
                  title: '动作库',
                  subtitle: '196 个动作',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ExerciseLibraryPage(state: state)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EntryCard(
                  icon: Icons.event_note,
                  title: '训练计划',
                  subtitle: '三分化 / 四分化',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TrainingProgramPage(state: state)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('三餐模板', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final t in mealTemplates) _MealTemplateCard(template: t),
          const SizedBox(height: 16),
          Text('钠盐管理', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const _SodiumCard(),
          const SizedBox(height: 16),
          Text('防反弹', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(reboundNotice),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealTemplateCard extends StatelessWidget {
  const _MealTemplateCard({required this.template});

  final MealTemplate template;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(template.name),
        subtitle: Text(template.idea),
        children: [
          for (final item in template.items)
            ListTile(
              dense: true,
              title: Text('${item.name} · ${item.serving}'),
              subtitle: Text(
                '碳水 ${formatNum(item.carbs)} · 蛋白 ${formatNum(item.protein)} · 脂肪 ${formatNum(item.fat)}',
              ),
            ),
          const Divider(),
          ListTile(
            dense: true,
            title: const Text('小计', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '碳水 ${formatNum(template.carbs)}g · 蛋白 ${formatNum(template.protein)}g · 脂肪 ${formatNum(template.fat)}g',
            ),
          ),
        ],
      ),
    );
  }
}

class _SodiumCard extends StatelessWidget {
  const _SodiumCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '每日盐摄入目标：${formatNum(SodiumGuide.minSaltGrams)}-${formatNum(SodiumGuide.maxSaltGrams)} 克（盐，非钠）',
            ),
            const SizedBox(height: 8),
            const Text('换算：1g 钠 = 2.5g 盐（盐 = 钠 × 2.5）'),
            const SizedBox(height: 12),
            Text('常见高隐形盐食物：',
                style: Theme.of(context).textTheme.titleMedium),
            for (final f in hiddenSaltFoods)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${f.name}（${f.serving}）'),
                trailing: Text('≈ ${formatNum(f.saltGrams)}g 盐'),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: scheme.primaryContainer,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
