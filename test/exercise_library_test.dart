import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/app_state.dart';
import 'package:recomp_app/core/fitness/fitness_database.dart';
import 'package:recomp_app/pages/exercise_library_page.dart';

import 'in_memory_repository.dart';

void main() {
  testWidgets('动作库数据加载失败兜底', (tester) async {
    // fitnessDb 为 null → 加载失败提示
    final state = AppState(InMemoryAppRepository());
    await state.init();
    await tester.pumpWidget(
        MaterialApp(home: ExerciseLibraryPage(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('动作数据加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('动作库渲染动作列表（真实数据）', (tester) async {
    late AppState state;
    await tester.runAsync(() async {
      final fitnessDb =
          await FitnessDatabase.openFromFile('assets/fitness.db');
      state = AppState(InMemoryAppRepository(), fitnessDb: fitnessDb);
      await state.init();
    });

    await tester.pumpWidget(
        MaterialApp(home: ExerciseLibraryPage(state: state)));
    // 等待 _load 的真实 IO 完成
    await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    // 结果区标题 + 动作卡片列表
    expect(find.textContaining('全部动作'), findsWidgets);
    expect(find.byType(Card), findsWidgets);
    // 部位分组（肩部等）
    expect(find.text('肩部'), findsOneWidget);
    // 筛选按钮
    expect(find.text('细分部位'), findsOneWidget);
    expect(find.text('器械'), findsOneWidget);
    expect(find.text('动作类型'), findsOneWidget);
  });
}
