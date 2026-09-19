import 'package:flutter/material.dart';
import 'package:recomp_app/app_state.dart';
import 'package:recomp_app/core/food/food_entry.dart';
import 'package:recomp_app/core/food/food_item.dart';
import 'package:recomp_app/core/food/meal.dart';
import 'package:recomp_app/core/macro/gender.dart';
import 'package:recomp_app/core/macro/weekly_training.dart';
import 'package:recomp_app/core/profile/user_profile.dart';
import 'package:recomp_app/core/profile/weight_record.dart';
import 'package:recomp_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_repository.dart';

/// 遍历所有页面并在窄屏下断言「零布局异常」。
///
/// 布局溢出在真机上只表现为文字被裁 / 控件点不到（正是用户报的
/// 「数值显示不完全」），不会崩溃，所以只能靠断言把它逼出来。

Future<AppState> _richState() async {
  final state = AppState(InMemoryAppRepository());
  await state.init();
  await state.saveProfile(const UserProfile(
    gender: Gender.male,
    weightKg: 85,
    training: WeeklyTraining.twoToThree,
    heightCm: 175,
    age: 26,
  ));
  await state.addEntry(const FoodEntry(
    food: FoodItem(
        name: '鸡胸肉',
        carbsPer100g: 0,
        proteinPer100g: 26,
        fatPer100g: 3),
    weightGrams: 150,
    meal: MealType.lunch,
  ));
  await state.addEntry(const FoodEntry(
    food: FoodItem(
        name: '米饭(熟)',
        carbsPer100g: 26,
        proteinPer100g: 2.6,
        fatPer100g: 0.3),
    weightGrams: 200,
    meal: MealType.lunch,
  ));
  await state.addWeightRecord(WeightRecord(
      date: DateTime.now().subtract(const Duration(days: 10)), weightKg: 86));
  await state.addWeightRecord(WeightRecord(date: DateTime.now(), weightKg: 84));
  return state;
}

/// 逐步 pump，并在每一步收集框架抛出的布局异常（含出错位置）。
Future<List<String>> _settleAndCollect(WidgetTester tester) async {
  final problems = <String>[];
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    final error = tester.takeException();
    if (error == null) continue;
    if (error is FlutterError) {
      problems.add(error.message);
    } else {
      problems.add(error.toString());
    }
  }
  return problems;
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final width in <double>[360, 320]) {
    group('窄屏 ${width.toInt()}dp 布局', () {
      Future<AppState> boot(WidgetTester tester) async {
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final state = await _richState();
        await tester.pumpWidget(RecompApp(state: state));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        return state;
      }

      // 每个 Tab 独立成一个用例：失败信息能直接指出是哪个页面。
      final tabs = <String, IconData>{
        '今日': Icons.today_outlined,
        '计算': Icons.calculate_outlined,
        '周期': Icons.insights_outlined,
        '指南': Icons.menu_book_outlined,
        '日历': Icons.calendar_month_outlined,
      };
      for (final entry in tabs.entries) {
        testWidgets('${entry.key}页', (tester) async {
          await boot(tester);
          await tester.tap(find.byIcon(entry.value));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(await _settleAndCollect(tester), isEmpty,
              reason: '${entry.key}页在 ${width.toInt()}dp 下不应有布局溢出');
        });
      }

      testWidgets('设置页', (tester) async {
        await boot(tester);
        await _openSettings(tester);
        expect(await _settleAndCollect(tester), isEmpty);
      });

      testWidgets('配比编辑页', (tester) async {
        await boot(tester);
        await _openSettings(tester);
        await tester.tap(find.text('碳蛋脂配比'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(await _settleAndCollect(tester), isEmpty);
      });

      testWidgets('动作库页', (tester) async {
        await boot(tester);
        await tester.tap(find.byIcon(Icons.menu_book_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('动作库'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(await _settleAndCollect(tester), isEmpty);
      });

      testWidgets('训练计划页', (tester) async {
        await boot(tester);
        await tester.tap(find.byIcon(Icons.menu_book_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('训练计划'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(await _settleAndCollect(tester), isEmpty);
      });
    });
  }
}
