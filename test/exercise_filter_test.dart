import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/fitness/exercise_filter.dart';

void main() {
  final cats = [
    const CategoryData(
        actionId: 'a1', group: '胸部', regions: ['下胸'], equipments: ['哑铃'], pattern: '力量训练'),
    const CategoryData(
        actionId: 'a2', group: '胸部', regions: ['上胸'], equipments: ['杠铃'], pattern: '力量训练'),
    const CategoryData(
        actionId: 'a3', group: '背部', regions: ['背阔肌'], equipments: ['哑铃'], pattern: '热身激活'),
    const CategoryData(
        actionId: 'a4', group: '胸部', regions: ['下胸'], equipments: ['绳索'], pattern: '拉伸放松'),
  ];

  test('按部位筛选', () {
    expect(filterActionIds(cats, const ExerciseFilter(group: '胸部')),
        {'a1', 'a2', 'a4'});
  });

  test('按器械筛选', () {
    expect(filterActionIds(cats, const ExerciseFilter(equipment: '哑铃')),
        {'a1', 'a3'});
  });

  test('按动作类型筛选', () {
    expect(filterActionIds(cats, const ExerciseFilter(pattern: '热身激活')),
        {'a3'});
  });

  test('热身切换', () {
    expect(filterActionIds(cats, const ExerciseFilter(warmupOnly: true)), {'a3'});
  });

  test('多维度组合', () {
    expect(
        filterActionIds(cats,
            const ExerciseFilter(group: '胸部', equipment: '哑铃')),
        {'a1'});
  });

  test('联动：部位分组计数', () {
    final groups =
        availableValues(cats, const ExerciseFilter(), 'group');
    expect(groups.firstWhere((g) => g.name == '胸部').count, 3);
    expect(groups.firstWhere((g) => g.name == '背部').count, 1);
  });

  test('联动：选器械后细分部位更新', () {
    final regions = availableValues(
        cats, const ExerciseFilter(equipment: '哑铃'), 'region');
    final names = regions.map((r) => r.name).toSet();
    expect(names, contains('下胸'));
    expect(names, contains('背阔肌'));
    expect(names, isNot(contains('上胸')));
  });
}
