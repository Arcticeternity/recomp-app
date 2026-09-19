import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/fitness/favorite.dart';
import '../core/fitness/fitness_database.dart';
import '../widgets/status_placeholder.dart';
import 'exercise_detail_page.dart';

/// 我的收藏：分组列表 + 动作列表（结构同训练计划）。
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, required this.state});

  final AppState state;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = widget.state.fitnessDb;
    if (db == null) return;
    await db.listAll(); // 触发数据加载（fitnessDb 已在 main 打开）
    if (mounted) setState(() {});
  }

  Future<void> _createGroup() async {
    final name = await _promptName('新建分组');
    if (name != null && name.isNotEmpty) {
      await widget.state.addFavoriteGroup(name);
    }
  }

  Future<void> _renameGroup(int id, String oldName) async {
    final name = await _promptName('重命名', initial: oldName);
    if (name != null && name.isNotEmpty) {
      await widget.state.renameFavoriteGroup(id, name);
    }
  }

  Future<void> _deleteGroup(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分组'),
        content: const Text('删除分组会同时移除其中所有收藏，确定吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) await widget.state.deleteFavoriteGroup(id);
  }

  Future<String?> _promptName(String title, {String? initial}) {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final groups = widget.state.favoriteGroups;
          if (groups.isEmpty) {
            return const EmptyPlaceholder(
              message: '还没有收藏分组',
              hint: '点右下角新建一个',
              icon: Icons.favorite_border,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              for (final g in groups)
                _GroupCard(
                  group: g,
                  state: widget.state,
                  onRename: () => _renameGroup(g.id, g.name),
                  onDelete: () => _deleteGroup(g.id),
                  onTapAction: _openDetail,
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  const _GroupCard({
    required this.group,
    required this.state,
    required this.onRename,
    required this.onDelete,
    required this.onTapAction,
  });

  final FavoriteGroup group;
  final AppState state;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(String) onTapAction;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  List<Exercise> _actions = [];

  @override
  void initState() {
    super.initState();
    _loadActions();
  }

  Future<void> _loadActions() async {
    final ids = await widget.state.loadFavoritesInGroup(widget.group.id);
    final db = widget.state.fitnessDb;
    final all = await db?.listAll() ?? [];
    final byId = {for (final e in all) e.id: e};
    if (!mounted) return;
    setState(() {
      _actions = ids.map((id) => byId[id]).whereType<Exercise>().toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return Card(
      child: ExpansionTile(
        title: Text(g.name),
        subtitle: Text('${_actions.length} 个动作'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'rename') widget.onRename();
            if (v == 'delete') widget.onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('重命名')),
            PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        children: [
          for (final e in _actions)
            ListTile(
              dense: true,
              title: Text(e.name),
              subtitle: Text(e.body),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => widget.onTapAction(e.id),
            ),
        ],
      ),
    );
  }
}
