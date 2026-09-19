import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/fitness/exercise_filter.dart';
import '../core/fitness/fitness_database.dart';
import '../widgets/status_placeholder.dart';
import 'exercise_detail_page.dart';
import 'favorites_page.dart';

/// 动作库：部位分组 + 全部/热身 tab + 下拉式三级筛选 + 搜索 + 收藏。
class ExerciseLibraryPage extends StatefulWidget {
  const ExerciseLibraryPage({super.key, required this.state});

  final AppState state;

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  List<Exercise> _all = [];
  List<CategoryData> _cats = [];
  bool _loading = true;
  String? _error;

  String? _group;
  String? _region;
  String? _equipment;
  String? _pattern;
  bool _warmupOnly = false;
  final _searchController = TextEditingController();
  String _query = '';
  Timer? _debounce;

  /// 当前展开的下拉面板维度：region / equipment / pattern，null 表示收起。
  String? _openDim;
  final _panelSearchController = TextEditingController();
  String _panelQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _panelSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final db = widget.state.fitnessDb;
      final all = await db?.listAll() ?? [];
      final cats = await db?.loadAllCategories() ?? [];
      if (!mounted) return;
      if (all.isEmpty || cats.isEmpty) {
        setState(() {
          _loading = false;
          _error = '动作数据加载失败';
        });
        return;
      }
      setState(() {
        _all = all;
        _cats = cats;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '动作数据加载失败';
        });
      }
    }
  }

  ExerciseFilter get _filter => ExerciseFilter(
        group: _group,
        region: _region,
        equipment: _equipment,
        pattern: _pattern,
        warmupOnly: _warmupOnly,
      );

  ExerciseFilter _baseWithout(String dim) => ExerciseFilter(
        group: dim == 'group' ? null : _group,
        region: dim == 'region' ? null : _region,
        equipment: dim == 'equipment' ? null : _equipment,
        pattern: dim == 'pattern' ? null : _pattern,
        warmupOnly: _warmupOnly,
      );

  List<NameCount> _groups() =>
      availableValues(_cats, _baseWithout('group'), 'group');
  List<NameCount> _regions() =>
      availableValues(_cats, _baseWithout('region'), 'region');
  List<NameCount> _equipments() =>
      availableValues(_cats, _baseWithout('equipment'), 'equipment');
  List<NameCount> _patterns() =>
      availableValues(_cats, _baseWithout('pattern'), 'pattern');

  List<Exercise> get _filtered {
    final ids = filterActionIds(_cats, _filter);
    var list = _all.where((e) => ids.contains(e.id)).toList();
    final q = _query.trim();
    if (q.isNotEmpty) {
      list = list
          .where((e) =>
              e.name.contains(q) ||
              e.muscles.any((m) => m.contains(q)) ||
              e.equipment.any((eq) => eq.contains(q)))
          .toList();
    }
    return list;
  }

  void _reset() {
    setState(() {
      _group = null;
      _region = null;
      _equipment = null;
      _pattern = null;
      _warmupOnly = false;
      _query = '';
      _searchController.clear();
      _openDim = null;
    });
  }

  void _openPanel(String dim) {
    setState(() {
      _openDim = _openDim == dim ? null : dim;
      _panelQuery = '';
      _panelSearchController.clear();
    });
  }

  String? get _selectedOfDim => switch (_openDim) {
        'region' => _region,
        'equipment' => _equipment,
        'pattern' => _pattern,
        _ => null,
      };

  List<NameCount> get _panelOptions => switch (_openDim) {
        'region' => _regions(),
        'equipment' => _equipments(),
        'pattern' => _patterns(),
        _ => const [],
      };

  void _selectPanel(String value) {
    setState(() {
      switch (_openDim) {
        case 'region':
          _region = _region == value ? null : value;
        case 'equipment':
          _equipment = _equipment == value ? null : value;
        case 'pattern':
          _pattern = _pattern == value ? null : value;
      }
    });
  }

  Future<void> _openDetail(String id) async {
    final db = widget.state.fitnessDb;
    final d = await db?.detail(id);
    if (d != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                ExerciseDetailPage(detail: d, state: widget.state)),
      );
    }
  }

  Future<void> _toggleFavorite(Exercise e) async {
    final state = widget.state;
    if (state.favoriteIds.contains(e.id)) {
      HapticFeedback.lightImpact();
      await state.removeFavorite(e.id);
      return;
    }
    final groupId = await showDialog<int>(
      context: context,
      builder: (_) => _PickGroupDialog(state: state, actionName: e.name),
    );
    if (groupId != null) {
      HapticFeedback.lightImpact();
      await state.addFavorite(e.id, groupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('动作库')),
        body: const LoadingPlaceholder(),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('动作库')),
        body: ErrorPlaceholder(message: '动作数据加载失败', onRetry: _load),
      );
    }

    final list = _filtered;
    final panelOptions = _panelOptions
        .where((o) =>
            _panelQuery.isEmpty || o.name.contains(_panelQuery.trim()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('动作库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            tooltip: '我的收藏',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => FavoritesPage(state: widget.state)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 150), () {
                  if (mounted) setState(() => _query = v);
                });
              },
              decoration: InputDecoration(
                hintText: '搜索动作名称 / 肌群',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // 2. 部位分组（横向单行，不换行）
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final g in _groups())
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(g.name),
                      selected: g.name == _group,
                      onSelected: (_) => setState(
                          () => _group = _group == g.name ? null : g.name),
                    ),
                  ),
              ],
            ),
          ),
          // 3. 全部动作 / 热身 tab
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _TabButton(
                  label: '全部动作',
                  selected: !_warmupOnly,
                  onTap: () => setState(() => _warmupOnly = false),
                ),
                const SizedBox(width: 8),
                _TabButton(
                  label: '热身',
                  selected: _warmupOnly,
                  onTap: () => setState(() => _warmupOnly = true),
                ),
              ],
            ),
          ),
          // 4. 筛选栏（一排 3 个下拉按钮）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _FilterButton(
                  label: '细分部位',
                  selected: _region,
                  active: _openDim == 'region',
                  onTap: () => _openPanel('region'),
                ),
                const SizedBox(width: 8),
                _FilterButton(
                  label: '器械',
                  selected: _equipment,
                  active: _openDim == 'equipment',
                  onTap: () => _openPanel('equipment'),
                ),
                const SizedBox(width: 8),
                _FilterButton(
                  label: '动作类型',
                  selected: _pattern,
                  active: _openDim == 'pattern',
                  onTap: () => _openPanel('pattern'),
                ),
              ],
            ),
          ),
          // 5+6. 结果区（含下拉浮层）
          Expanded(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_group ?? '全部动作'}（${list.length}）',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _reset,
                            child: const Text('重置条件'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? const EmptyPlaceholder(
                              message: '暂无匹配动作', icon: Icons.search_off)
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: list.length,
                              itemBuilder: (context, i) {
                                final e = list[i];
                                final fav =
                                    widget.state.favoriteIds.contains(e.id);
                                return Card(
                                  child: ListTile(
                                    title: Text(e.name),
                                    subtitle: Text(
                                      '${e.body} · ${e.muscles.take(3).join(' / ')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        fav
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: fav
                                            ? Theme.of(context)
                                                .colorScheme
                                                .error
                                            : null,
                                      ),
                                      onPressed: () => _toggleFavorite(e),
                                    ),
                                    onTap: () => _openDetail(e.id),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                // 下拉浮层
                if (_openDim != null) ...[
                  ModalBarrier(
                    color: Colors.black26,
                    dismissible: true,
                    onDismiss: () => setState(() => _openDim = null),
                  ),
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _panelSearchController,
                              onChanged: (v) =>
                                  setState(() => _panelQuery = v),
                              decoration: const InputDecoration(
                                hintText: '搜索选项',
                                isDense: true,
                                prefixIcon: Icon(Icons.search, size: 18),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Flexible(
                              child: ListView(
                                shrinkWrap: true,
                                children: [
                                  if (_selectedOfDim != null)
                                    ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.clear,
                                          size: 16),
                                      title: const Text('清除选择'),
                                      onTap: () {
                                        _selectPanel(_selectedOfDim!);
                                        setState(() => _openDim = null);
                                      },
                                    ),
                                  for (final o in panelOptions)
                                    ListTile(
                                      dense: true,
                                      title: Text('${o.name}（${o.count}）'),
                                      selected:
                                          _selectedOfDim == o.name,
                                      onTap: () => _selectPanel(o.name),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: selected ? scheme.primaryContainer : Colors.transparent,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String? selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSelection = selected != null;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasSelection || active
                  ? scheme.primary
                  : scheme.outlineVariant,
            ),
            color: hasSelection ? scheme.primaryContainer : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  selected ?? label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasSelection ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                active ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 选择收藏分组对话框。
class _PickGroupDialog extends StatefulWidget {
  const _PickGroupDialog({required this.state, required this.actionName});

  final AppState state;
  final String actionName;

  @override
  State<_PickGroupDialog> createState() => _PickGroupDialogState();
}

class _PickGroupDialogState extends State<_PickGroupDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createAndPick() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final id = await widget.state.addFavoriteGroup(name);
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.state.favoriteGroups;
    return AlertDialog(
      title: Text('收藏「${widget.actionName}」到'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('还没有分组，先建一个吧'),
              ),
            for (final g in groups)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(g.name),
                onTap: () => Navigator.pop(context, g.id),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '新建分组',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _createAndPick,
                  child: const Text('新建'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
