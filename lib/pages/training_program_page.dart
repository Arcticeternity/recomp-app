import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/fitness/fitness_database.dart';
import '../widgets/status_placeholder.dart';
import 'exercise_detail_page.dart';

/// 训练计划：三分化 + 四分化（纯查看）。
class TrainingProgramPage extends StatefulWidget {
  const TrainingProgramPage({super.key, required this.state});

  final AppState state;

  @override
  State<TrainingProgramPage> createState() => _TrainingProgramPageState();
}

class _TrainingProgramPageState extends State<TrainingProgramPage> {
  TrainingProgram? _three;
  TrainingProgram? _four;
  int _tab = 0; // 0=四分化, 1=三分化

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = widget.state.fitnessDb;
    final three = await db?.program('three');
    final four = await db?.program('four');
    if (!mounted) return;
    setState(() {
      _three = three;
      _four = four;
    });
  }

  Future<void> _openDetail(String id) async {
    final db = widget.state.fitnessDb;
    final d = await db?.detail(id);
    if (d != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ExerciseDetailPage(detail: d, state: widget.state)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prog = _tab == 0 ? _four : _three;
    return Scaffold(
      appBar: AppBar(title: const Text('训练计划')),
      body: prog == null
          ? const LoadingPlaceholder()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('四分化')),
                      ButtonSegment(value: 1, label: Text('三分化')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Text(prog.title,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(prog.subtitle,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const SizedBox(height: 16),
                      for (final day in prog.days) _DayCard(day: day, onTap: _openDetail),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.onTap});

  final TrainingDay day;
  final void Function(String actionId) onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day.title, style: Theme.of(context).textTheme.titleMedium),
            if (day.note.isNotEmpty)
              Text(day.note,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            for (final item in day.items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: item.phase == '热身'
                    ? Icon(Icons.local_fire_department_outlined,
                        size: 18, color: Theme.of(context).colorScheme.tertiary)
                    : const Icon(Icons.fitness_center, size: 18),
                title: Text(item.displayName),
                subtitle: Text(item.dosageText),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => onTap(item.actionId),
              ),
          ],
        ),
      ),
    );
  }
}
