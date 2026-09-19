import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/macro/macro_ratio.dart';
import 'package:recomp_app/core/macro/macro_ratio_settings.dart';

void main() {
  group('自定义配比 JSON 往返', () {
    test('序列化后可原样还原', () {
      const ratio =
          MacroRatio(carbsPerKg: 2.8, proteinPerKg: 1.9, fatPerKg: 0.7);
      final restored = MacroRatio.fromJson(ratio.toJson());

      expect(restored.carbsPerKg, 2.8);
      expect(restored.proteinPerKg, 1.9);
      expect(restored.fatPerKg, 0.7);
      expect(restored.sameAs(ratio), isTrue);
    });

    test('整数值也能还原（JSON 里可能是 int）', () {
      final restored = MacroRatio.fromJson(
          const {'carbsPerKg': 3, 'proteinPerKg': 2, 'fatPerKg': 1});
      expect(restored.carbsPerKg, 3.0);
      expect(restored.fatPerKg, 1.0);
    });

    test('缺字段抛 FormatException', () {
      expect(
        () => MacroRatio.fromJson(const {'carbsPerKg': 2.2}),
        throwsFormatException,
      );
    });

    test('非正数与非法值抛 FormatException', () {
      expect(
        () => MacroRatio.fromJson(
            const {'carbsPerKg': 0, 'proteinPerKg': 1.6, 'fatPerKg': 0.9}),
        throwsFormatException,
      );
      expect(
        () => MacroRatio.fromJson(const {
          'carbsPerKg': double.nan,
          'proteinPerKg': 1.6,
          'fatPerKg': 0.9,
        }),
        throwsFormatException,
      );
      expect(
        () => MacroRatio.fromJson(
            const {'carbsPerKg': '2.2', 'proteinPerKg': 1.6, 'fatPerKg': 0.9}),
        throwsFormatException,
      );
    });
  });

  group('配比范围夹取', () {
    test('超出上限被压到上限', () {
      final clamped = MacroRatioBounds.clamp(const MacroRatio(
          carbsPerKg: 99, proteinPerKg: 99, fatPerKg: 99));
      expect(clamped.carbsPerKg, MacroRatioBounds.maxCarbs);
      expect(clamped.proteinPerKg, MacroRatioBounds.maxProtein);
      expect(clamped.fatPerKg, MacroRatioBounds.maxFat);
    });

    test('低于下限被抬到下限', () {
      final clamped = MacroRatioBounds.clamp(
          const MacroRatio(carbsPerKg: 0.1, proteinPerKg: 0.1, fatPerKg: 0.1));
      expect(clamped.carbsPerKg, MacroRatioBounds.minCarbs);
      expect(clamped.proteinPerKg, MacroRatioBounds.minProtein);
      expect(clamped.fatPerKg, MacroRatioBounds.minFat);
    });

    test('区间内的值原样保留', () {
      const inRange =
          MacroRatio(carbsPerKg: 2.5, proteinPerKg: 1.6, fatPerKg: 0.9);
      final clamped = MacroRatioBounds.clamp(inRange);
      expect(clamped.sameAs(inRange), isTrue);
    });
  });

  group('配比状态', () {
    const recommended =
        MacroRatio(carbsPerKg: 2.2, proteinPerKg: 1.4, fatPerKg: 0.8);

    test('推荐态：生效值即推荐值，不标记自定义', () {
      const settings = MacroRatioSettings.recommended(recommended);
      expect(settings.isCustom, isFalse);
      expect(settings.ratio.sameAs(recommended), isTrue);
      expect(settings.differsFromRecommended, isFalse);
    });

    test('自定义态：标记自定义且能算出偏离', () {
      const settings = MacroRatioSettings.custom(
        ratio: MacroRatio(carbsPerKg: 3.0, proteinPerKg: 1.4, fatPerKg: 0.8),
        recommended: recommended,
      );
      expect(settings.isCustom, isTrue);
      expect(settings.differsFromRecommended, isTrue);
      expect(settings.recommended.carbsPerKg, 2.2);
    });

    test('自定义值恰好等于推荐值时不算偏离', () {
      const settings = MacroRatioSettings.custom(
        ratio: recommended,
        recommended: recommended,
      );
      expect(settings.isCustom, isTrue);
      expect(settings.differsFromRecommended, isFalse);
    });
  });
}
