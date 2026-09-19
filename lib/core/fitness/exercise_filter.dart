/// 分类数据（动作的筛选维度）。
class CategoryData {
  const CategoryData({
    required this.actionId,
    required this.group,
    required this.regions,
    required this.equipments,
    required this.pattern,
  });

  final String actionId;
  final String group;
  final List<String> regions;
  final List<String> equipments;
  final String pattern;
}

/// 筛选条件（各维度可选，null 表示不限）。
class ExerciseFilter {
  const ExerciseFilter({
    this.group,
    this.region,
    this.equipment,
    this.pattern,
    this.warmupOnly = false,
  });

  final String? group;
  final String? region;
  final String? equipment;
  final String? pattern;
  final bool warmupOnly;
}

/// 名称 + 计数（用于筛选器展示）。
class NameCount {
  const NameCount(this.name, this.count);

  final String name;
  final int count;
}

/// 判断动作是否匹配筛选条件。
bool matches(CategoryData c, ExerciseFilter f) {
  if (f.group != null && c.group != f.group) return false;
  if (f.region != null && !c.regions.contains(f.region)) return false;
  if (f.equipment != null && !c.equipments.contains(f.equipment)) return false;
  if (f.pattern != null && c.pattern != f.pattern) return false;
  if (f.warmupOnly && c.pattern != '热身激活') return false;
  return true;
}

/// 筛选后的动作 id 集合。
Set<String> filterActionIds(List<CategoryData> cats, ExerciseFilter f) =>
    cats.where((c) => matches(c, f)).map((c) => c.actionId).toSet();

/// 联动：在 base（不含 dim 维度）筛选后，统计 dim 维度的可选项（含计数）。
///
/// dim 取值：group / pattern / region / equipment。
List<NameCount> availableValues(
    List<CategoryData> cats, ExerciseFilter base, String dim) {
  final map = <String, int>{};
  for (final c in cats) {
    if (!matches(c, base)) continue;
    final values = switch (dim) {
      'group' => [c.group],
      'pattern' => [c.pattern],
      'region' => c.regions,
      _ => c.equipments,
    };
    for (final v in values) {
      if (v.isNotEmpty) map[v] = (map[v] ?? 0) + 1;
    }
  }
  final list = map.entries.map((e) => NameCount(e.key, e.value)).toList()
    ..sort((a, b) => b.count != a.count
        ? b.count.compareTo(a.count)
        : a.name.compareTo(b.name));
  return list;
}
