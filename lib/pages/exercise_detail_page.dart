import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../core/fitness/fitness_database.dart';
import 'favorites_page.dart';
import 'training_program_page.dart';

/// 动作详情页：演示图、概要、肌群、步骤、关键点、呼吸、感受、变体、所属计划/分组。
class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({super.key, required this.detail, required this.state});

  final ExerciseDetail detail;
  final AppState state;

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  List<ProgramLocation> _programs = [];
  List<String> _groupNames = [];

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    final db = widget.state.fitnessDb;
    final programs =
        await db?.findProgramsContaining(widget.detail.exercise.id) ?? [];
    final groupNames = <String>[];
    for (final g in widget.state.favoriteGroups) {
      final ids = await widget.state.loadFavoritesInGroup(g.id);
      if (ids.contains(widget.detail.exercise.id)) {
        groupNames.add(g.name);
      }
    }
    if (!mounted) return;
    setState(() {
      _programs = programs;
      _groupNames = groupNames;
    });
  }

  Future<void> _openBilibili() async {
    final d = widget.detail;
    final url = d.bvid != null
        ? 'https://www.bilibili.com/video/${d.bvid}'
        : 'https://search.bilibili.com/all?keyword=${Uri.encodeComponent(d.exercise.name)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final ex = d.exercise;
    return Scaffold(
      appBar: AppBar(title: Text(ex.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (d.hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/action_images/${ex.id}.jpg'),
            ),
          const SizedBox(height: 12),
          if (d.summary.isNotEmpty)
            _Section(title: '概要', child: Text(d.summary)),
          if (ex.muscles.isNotEmpty)
            _Section(
              title: '目标肌群',
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [for (final m in ex.muscles) Chip(label: Text(m))],
              ),
            ),
          if (ex.equipment.isNotEmpty)
            _Section(
              title: '所需器械',
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [for (final e in ex.equipment) Chip(label: Text(e))],
              ),
            ),
          if (d.steps.isNotEmpty)
            _Section(
              title: '动作步骤',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in d.steps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (s.text.isNotEmpty) Text(s.text),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (d.keyPoints.isNotEmpty)
            _Section(
              title: '关键点',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final k in d.keyPoints)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.title,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (k.text.isNotEmpty) Text(k.text),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (d.breathing.isNotEmpty)
            _Section(title: '呼吸', child: Text(d.breathing)),
          if (d.feel.isNotEmpty)
            _Section(title: '感受', child: Text(d.feel)),
          if (d.variants.isNotEmpty)
            _Section(
              title: '变体',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final v in d.variants) Text('· $v')],
              ),
            ),
          if (_programs.isNotEmpty || _groupNames.isNotEmpty)
            _Section(
              title: '所属计划 / 分组',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final p in _programs)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_note, size: 18),
                      title: Text('${p.programTitle} · ${p.dayTitle}'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                TrainingProgramPage(state: widget.state)),
                      ),
                    ),
                  for (final g in _groupNames)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.favorite, size: 18),
                      title: Text(g),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => FavoritesPage(state: widget.state)),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openBilibili,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('去B站看'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
