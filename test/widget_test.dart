import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/app_state.dart';
import 'package:recomp_app/core/calibration/calibration_engine.dart';
import 'package:recomp_app/core/macro/gender.dart';
import 'package:recomp_app/core/macro/macro_ratio.dart';
import 'package:recomp_app/core/macro/weekly_training.dart';
import 'package:recomp_app/core/profile/user_profile.dart';
import 'package:recomp_app/core/profile/weight_record.dart';
import 'package:recomp_app/main.dart';
import 'package:recomp_app/pages/cycle_page.dart';

import 'in_memory_repository.dart';

Future<AppState> _makeState() async {
  final state = AppState(InMemoryAppRepository());
  await state.init();
  return state;
}

Future<AppState> _stateWithProfile() async {
  final state = await _makeState();
  await state.saveProfile(const UserProfile(
    gender: Gender.male,
    weightKg: 85,
    training: WeeklyTraining.twoToThree,
  ));
  return state;
}

void main() {
  testWidgets('无档案时显示引导页', (tester) async {
    final state = await _makeState();
    await tester.pumpWidget(RecompApp(state: state));
    expect(find.text('你的性别'), findsOneWidget);
    expect(find.text('男'), findsOneWidget);
    expect(find.text('女'), findsOneWidget);
  });

  testWidgets('完成引导进入主界面', (tester) async {
    final state = await _makeState();
    await tester.pumpWidget(RecompApp(state: state));

    // 第 1 步：选性别
    await tester.tap(find.text('男'));
    await tester.pump();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 第 2 步：输体重
    await tester.enterText(find.byType(TextField), '85');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 第 3 步：输身高
    await tester.enterText(find.byType(TextField), '175');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 第 4 步：输年龄
    await tester.enterText(find.byType(TextField), '25');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 第 5 步：选训练时长
    await tester.tap(find.text('2-3小时/周'));
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    // 进入主界面，5 个 Tab
    expect(find.text('今日'), findsWidgets);
    expect(find.text('计算'), findsWidgets);
    expect(find.text('周期'), findsWidgets);
    expect(find.text('指南'), findsWidgets);
    expect(find.text('日历'), findsWidgets);
  });

  testWidgets('主界面显示每日目标数值', (tester) async {
    final state = await _stateWithProfile();
    await tester.pumpWidget(RecompApp(state: state));
    await tester.pumpAndSettle();

    // 切到计算 Tab
    await tester.tap(find.byIcon(Icons.calculate_outlined));
    await tester.pumpAndSettle();

    // 计算页显示目标
    expect(find.text('187 g'), findsOneWidget); // 碳水
    expect(find.text('119 g'), findsOneWidget); // 蛋白
    expect(find.text('68 g'), findsOneWidget); // 脂肪
  });

  testWidgets('智能输入带宏量录入', (tester) async {
    final state = await _stateWithProfile();
    await tester.pumpWidget(RecompApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // 智能输入：米饭150g 碳水39g 蛋白3.9g
    await tester.enterText(
        find.byKey(const Key('smart_input')), '米饭150g 碳水39g 蛋白3.9g');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    // 确认卡片
    expect(find.text('确认食物'), findsOneWidget);
    await tester.tap(find.text('确认添加'));
    await tester.pumpAndSettle();

    // 已摄入碳水 39g
    expect(find.textContaining('39 / 187'), findsOneWidget);
  });

  testWidgets('手动添加自定义食物后可录入', (tester) async {
    final state = await _stateWithProfile();
    await tester.pumpWidget(RecompApp(state: state));
    await tester.pumpAndSettle();

    // 打开录入 sheet
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // 打开手动添加对话框
    await tester.tap(find.text('手动填写'));
    await tester.pumpAndSettle();

    // 填表单（默认「营养密度」方式）
    await tester.enterText(find.byKey(const Key('quick_name')), '蛋白粉');
    await tester.enterText(find.widgetWithText(TextField, '碳水（g/100g）'), '8');
    await tester.enterText(find.widgetWithText(TextField, '蛋白（g/100g）'), '80');
    await tester.enterText(find.widgetWithText(TextField, '脂肪（g/100g）'), '5');
    await tester.tap(find.text('保存到食物库'));
    await tester.pumpAndSettle();

    // 已选中自定义食物
    expect(find.text('已选：蛋白粉'), findsOneWidget);

    // 输重量并添加（30g × 80/100 = 24g 蛋白）
    await tester.enterText(find.byKey(const Key('food_weight')), '30');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.textContaining('24 / 119'), findsOneWidget);
  });

  testWidgets('一次性录入直接计入当天', (tester) async {
    final state = await _stateWithProfile();
    await tester.pumpWidget(RecompApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动填写'));
    await tester.pumpAndSettle();

    // 切到「一次性」方式
    await tester.tap(find.text('一次性'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quick_name')), '面包');
    await tester.enterText(find.byKey(const Key('quick_weight')), '15');
    await tester.enterText(
        find.widgetWithText(TextField, '这 X 克碳水总量（g）'), '7');
    await tester.enterText(
        find.widgetWithText(TextField, '这 X 克蛋白总量（g）'), '3');
    await tester.enterText(
        find.widgetWithText(TextField, '这 X 克脂肪总量（g）'), '1');
    await tester.tap(find.text('直接添加'));
    await tester.pumpAndSettle();

    // 直接计入：碳水 7g
    expect(find.textContaining('7 / 187'), findsOneWidget);
  });

  testWidgets('日历 Tab 显示月视图', (tester) async {
    final state = await _stateWithProfile();
    await tester.pumpWidget(RecompApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(find.text('${now.year} 年 ${now.month} 月'), findsOneWidget);
  });

  testWidgets('设置页切换主题', (tester) async {
    final state = await _stateWithProfile();
    await tester.pumpWidget(RecompApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // 滚动到底部让主题列表可见
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('海洋蓝'));
    await tester.pumpAndSettle();

    expect(state.themeName, 'ocean');
  });

  group('自定义碳蛋脂配比', () {
    testWidgets('自定义配比生效于每日目标，恢复推荐后回到原值', (tester) async {
      final state = await _stateWithProfile();
      await tester.pumpWidget(RecompApp(state: state));
      await tester.pumpAndSettle();

      // 基线：85kg 男生 2-3h/周 => 碳水 2.2×85
      expect(state.dailyTarget.carbs, closeTo(187, 0.05),
          reason: '未自定义时按档案推荐值');
      expect(state.macroRatioSettings.isCustom, isFalse);

      // 改成 3.0 g/kg 碳水
      await state.saveMacroRatio(const MacroRatio(
        carbsPerKg: 3.0,
        proteinPerKg: 1.4,
        fatPerKg: 0.8,
      ));
      await tester.pumpAndSettle();

      expect(state.macroRatioSettings.isCustom, isTrue);
      expect(state.dailyTarget.carbs, closeTo(255, 0.05),
          reason: '3.0×85=255，自定义配比必须覆盖推荐值');

      // 计算页渲染的是生效值而非推荐值
      await tester.tap(find.byIcon(Icons.calculate_outlined));
      await tester.pumpAndSettle();
      expect(find.text('255 g'), findsOneWidget);

      // 恢复推荐
      await state.clearMacroRatio();
      await tester.pumpAndSettle();
      expect(state.macroRatioSettings.isCustom, isFalse);
      expect(state.dailyTarget.carbs, closeTo(187, 0.05));
    });

    testWidgets('推荐值实时跟随训练时长，不被自定义值冻结', (tester) async {
      final state = await _stateWithProfile();
      await state.saveMacroRatio(const MacroRatio(
        carbsPerKg: 3.0,
        proteinPerKg: 1.4,
        fatPerKg: 0.8,
      ));
      await tester.pumpWidget(RecompApp(state: state));
      await tester.pumpAndSettle();

      final before = state.macroRatioSettings.recommended.carbsPerKg;
      expect(before, closeTo(2.2, 0.001));

      // 档案改成 4-5 小时：推荐值应实时更新，生效值仍是自定义的
      await state.saveProfile(state.profile!
          .copyWith(training: WeeklyTraining.fourToFive));
      await tester.pumpAndSettle();

      expect(state.macroRatioSettings.recommended.carbsPerKg,
          closeTo(2.5, 0.001),
          reason: '推荐值按当前档案重算，不能是过期快照');
      expect(state.macroRatioSettings.ratio.carbsPerKg, closeTo(3.0, 0.001),
          reason: '生效值仍是用户自定义值');
    });

    testWidgets('设置页显示配比卡片，可进入编辑页并恢复推荐', (tester) async {
      final state = await _stateWithProfile();
      await state.saveMacroRatio(const MacroRatio(
        carbsPerKg: 3.0,
        proteinPerKg: 1.4,
        fatPerKg: 0.8,
      ));
      await tester.pumpWidget(RecompApp(state: state));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('饮食目标'), findsOneWidget);
      expect(find.text('碳蛋脂配比'), findsOneWidget);
      expect(find.text('自定义'), findsOneWidget);

      await tester.tap(find.text('碳蛋脂配比'));
      await tester.pumpAndSettle();

      // 配置页展示自定义值与推荐值对比
      expect(find.text('正在使用自定义配比'), findsOneWidget);
      expect(state.macroRatioSettings.recommended.carbsPerKg,
          closeTo(2.2, 0.001));

      await tester.tap(find.text('恢复推荐'));
      await tester.pumpAndSettle();

      expect(state.macroRatioSettings.isCustom, isFalse);
      expect(find.text('正在跟随档案推荐配比'), findsOneWidget);
    });
  });

  group('校准建议写回配比', () {
    testWidgets('点应用建议后配比更新为建议值', (tester) async {
      final state = await _stateWithProfile();
      final now = DateTime.now();
      // 10 天降 2.5kg（周均 1.75kg）→ 触发「过快 → 提碳水」
      await state.addWeightRecord(
          WeightRecord(date: now.subtract(const Duration(days: 10)), weightKg: 85));
      await state.addWeightRecord(WeightRecord(date: now, weightKg: 82.5));

      // 期望值由引擎算出，不写死数字
      final startRatio = state.macroRatioSettings.ratio;
      final expected = CalibrationEngine().evaluate(
        gender: Gender.male,
        currentWeightKg: 82.5,
        training: WeeklyTraining.twoToThree,
        currentCarbsPerKg: startRatio.carbsPerKg,
        startWeightKg: 85,
        endWeightKg: 82.5,
        days: 10,
      );
      expect(expected.newCarbsPerKg, greaterThan(startRatio.carbsPerKg),
          reason: '过快应提碳水');

      await tester.pumpWidget(RecompApp(state: state));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.insights_outlined));
      await tester.pumpAndSettle();

      // 校准卡片在页面下方且 ListView 懒构建，先滚下去再校验按钮真的渲染了
      final cycleList = find.descendant(
        of: find.byType(CyclePage),
        matching: find.byType(ListView),
      );
      await tester.drag(cycleList, const Offset(0, -700));
      await tester.pumpAndSettle();

      final applyButton = find.textContaining('应用建议');
      expect(applyButton, findsOneWidget, reason: '校准给出建议后应出现应用按钮');

      await tester.ensureVisible(applyButton);
      await tester.pumpAndSettle();

      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(state.macroRatioSettings.ratio.carbsPerKg,
          closeTo(expected.newCarbsPerKg, 0.001),
          reason: '建议必须真正写回配比，而不只是显示文案');
      expect(state.macroRatioSettings.ratio.proteinPerKg,
          closeTo(startRatio.proteinPerKg, 0.001),
          reason: '应用建议只动碳水，蛋白与脂肪不变');
    });
  });
}
