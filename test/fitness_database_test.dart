import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/fitness/fitness_database.dart';

void main() {
  test('本地健身数据查询', () async {
    final db = await FitnessDatabase.openFromFile('assets/fitness.db');

    final all = await db.listAll();
    expect(all.length, 197);

    final bodies = await db.listBodies();
    expect(bodies, isNotEmpty);

    // 详情（含步骤）
    final detail = await db.detail('cable-chest-fly');
    expect(detail, isNotNull);
    expect(detail!.exercise.name, isNotEmpty);
    expect(detail.steps, isNotEmpty);
    expect(detail.exercise.muscles, isNotEmpty);

    // 训练计划：四分化 4 天、三分化 3 天
    final four = await db.program('four');
    expect(four, isNotNull);
    expect(four!.days.length, 4);
    expect(four.days.first.items, isNotEmpty);

    final three = await db.program('three');
    expect(three, isNotNull);
    expect(three!.days.length, 3);

    await db.close();
  });

  test('动作解释不露元数据（steps/变体只含文字）', () async {
    final db = await FitnessDatabase.openFromFile('assets/fitness.db');

    // 有变体的动作（barbell-bench-press 的 variants 非空）
    final d = await db.detail('barbell-bench-press');
    expect(d, isNotNull);

    // steps 只含 title/text，无元数据
    for (final s in d!.steps) {
      expect(s.title, isNotEmpty);
    }
    // 变体只含文字，不露 source_refs/video_id/start 等 JSON 字段
    for (final v in d.variants) {
      expect(v, isNot(contains('source_refs')));
      expect(v, isNot(contains('video_id')));
      expect(v, isNot(contains('start')));
      expect(v, isNot(contains('{')));
    }

    await db.close();
  });
}
