import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/app_state.dart';
import 'package:recomp_app/core/macro/gender.dart';
import 'package:recomp_app/core/macro/weekly_training.dart';
import 'package:recomp_app/core/profile/user_profile.dart';
import 'package:recomp_app/main.dart';

import 'in_memory_repository.dart';

Future<AppState> _state() async {
  final state = AppState(InMemoryAppRepository());
  await state.init();
  await state.saveProfile(const UserProfile(
    gender: Gender.male,
    weightKg: 85,
    training: WeeklyTraining.twoToThree,
  ));
  return state;
}

/// 进入配比编辑页。
Future<AppState> _open(WidgetTester tester, {Size size = const Size(412, 915)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final state = await _state();
  await tester.pumpWidget(RecompApp(state: state));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('碳蛋脂配比'));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  group('配比编辑页数字输入', () {
    testWidgets('输入数字后配比按输入值更新', (tester) async {
      final state = await _open(tester);
      expect(state.macroRatioSettings.ratio.carbsPerKg, closeTo(2.2, 0.001));

      // 碳水输入框初始显示 2.2
      final carbsField = find.widgetWithText(TextField, '2.2');
      expect(carbsField, findsOneWidget, reason: '应能定位到碳水输入框');

      await tester.tap(carbsField);
      await tester.pumpAndSettle();
      await tester.enterText(carbsField, '3.4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(state.macroRatioSettings.ratio.carbsPerKg, closeTo(3.4, 0.001),
          reason: '输入的数字必须真正写进配比（此前手机上无法输入）');
    });

    testWidgets('输入超范围值被夹到边界', (tester) async {
      final state = await _open(tester);

      final carbsField = find.widgetWithText(TextField, '2.2');
      await tester.tap(carbsField);
      await tester.enterText(carbsField, '99');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(state.macroRatioSettings.ratio.carbsPerKg, closeTo(6.0, 0.001),
          reason: '上限 6.0 g/kg');
    });

    testWidgets('步进按钮按 0.05 调整', (tester) async {
      final state = await _open(tester);
      final before = state.macroRatioSettings.ratio.carbsPerKg;

      // 碳水卡片的加号按钮
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      expect(state.macroRatioSettings.ratio.carbsPerKg,
          closeTo(before + 0.05, 0.001));
    });

    testWidgets('非法输入被还原，不写入配比', (tester) async {
      final state = await _open(tester);
      final before = state.macroRatioSettings.ratio.carbsPerKg;

      final carbsField = find.widgetWithText(TextField, '2.2');
      await tester.tap(carbsField);
      await tester.enterText(carbsField, '.');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(state.macroRatioSettings.ratio.carbsPerKg, closeTo(before, 0.001),
          reason: '无法解析的输入不应破坏配比');
    });
  });

  group('配比编辑页布局适配', () {
    // 回归防护：此前输入框与偏离标签挤在同一行，改动配比后偏离标签出现，
    // 把输入框压到十几 dp —— 手机上既显示不全也点不到。
    testWidgets('小屏 + 出现偏离标签时不溢出', (tester) async {
      await _open(tester, size: const Size(320, 720)); // 窄屏（老机型）

      final carbsField = find.widgetWithText(TextField, '2.2');
      await tester.tap(carbsField);
      await tester.enterText(carbsField, '5.0'); // 制造大偏离 → 标签变长
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // tester.takeException() 非空即说明发生了 RenderFlex overflow 之类的错误
      expect(tester.takeException(), isNull,
          reason: '窄屏下改动配比不得触发布局溢出');
    });

    testWidgets('输入框在窄屏下仍有可点击宽度', (tester) async {
      await _open(tester, size: const Size(320, 720));

      final field = find.widgetWithText(TextField, '2.2');
      final size = tester.getSize(field);
      expect(size.width, greaterThanOrEqualTo(60),
          reason: '输入框被挤压到无法点击就是本次要修的 bug');
      expect(size.height, greaterThan(20));
    });
  });

  group('配比编辑页恢复推荐', () {
    testWidgets('恢复推荐后输入框回到推荐值', (tester) async {
      final state = await _open(tester);

      final carbsField = find.widgetWithText(TextField, '2.2');
      await tester.tap(carbsField);
      await tester.enterText(carbsField, '4.0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(state.macroRatioSettings.ratio.carbsPerKg, closeTo(4.0, 0.001));

      await tester.tap(find.text('恢复推荐'));
      await tester.pumpAndSettle();

      expect(state.macroRatioSettings.isCustom, isFalse);
      expect(find.widgetWithText(TextField, '2.2'), findsOneWidget,
          reason: '输入框应同步回推荐值');
    });
  });
}
