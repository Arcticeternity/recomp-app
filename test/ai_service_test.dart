import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/core/ai/ai_service.dart';

void main() {
  group('parseAiNutrition', () {
    test('解析标准 JSON', () {
      final r = parseAiNutrition(
          '{"name":"去皮鸡腿","unit_weight":100,"carbs":0,"protein":20,"fat":7}');
      expect(r.name, '去皮鸡腿');
      expect(r.unitWeight, 100);
      expect(r.carbsPer100g, 0);
      expect(r.proteinPer100g, 20);
      expect(r.fatPer100g, 7);
    });

    test('容忍 markdown 代码块包裹', () {
      final r = parseAiNutrition(
          '```json\n{"name":"鸡蛋","unit_weight":50,"carbs":1,"protein":13,"fat":10}\n```');
      expect(r.unitWeight, 50);
      expect(r.proteinPer100g, 13);
    });

    test('缺失字段用默认值', () {
      final r = parseAiNutrition('{"carbs":26,"protein":2.6,"fat":0.3}');
      expect(r.name, '');
      expect(r.unitWeight, 100);
      expect(r.carbsPer100g, 26);
    });

    test('无 JSON 抛 AiException', () {
      expect(() => parseAiNutrition('抱歉，我不认识这个食物'),
          throwsA(isA<AiException>()));
    });

    test('容忍前后有解释文字', () {
      final r = parseAiNutrition(
          '好的，这是结果：\n{"name":"鸡胸肉","unit_weight":120,"carbs":0,"protein":26,"fat":3}\n希望有帮助！');
      expect(r.name, '鸡胸肉');
      expect(r.proteinPer100g, 26);
    });

    test('容忍嵌套 JSON 对象', () {
      // 旧实现用 \{[^{}]*\} 无法匹配嵌套结构
      final r = parseAiNutrition(
          '{"name":"红烧肉","unit_weight":100,"carbs":5,"protein":14,"fat":30,'
          '"source":{"db":"CFCT","confidence":0.8}}');
      expect(r.name, '红烧肉');
      expect(r.fatPer100g, 30);
    });

    test('name 含花括号时不破坏解析', () {
      final r = parseAiNutrition(
          '{"name":"拼盘{小份}","unit_weight":200,"carbs":10,"protein":8,"fat":6}');
      expect(r.name, '拼盘{小份}');
      expect(r.carbsPer100g, 10);
    });

    test('非法数值回退到安全默认值', () {
      final r = parseAiNutrition(
          '{"name":"怪食物","unit_weight":0,"carbs":-5,"protein":"很多","fat":null}');
      expect(r.unitWeight, 100, reason: 'unit_weight 非正数应回退 100');
      expect(r.carbsPer100g, 0, reason: '负数回退 0');
      expect(r.proteinPer100g, 0, reason: '非数字回退 0');
      expect(r.fatPer100g, 0, reason: 'null 回退 0');
    });

    test('name 两端空白被裁掉', () {
      final r = parseAiNutrition(
          '{"name":"  水煮蛋  ","unit_weight":50,"carbs":1,"protein":13,"fat":9}');
      expect(r.name, '水煮蛋');
    });
  });

  group('系统提示词约束', () {
    test('要求严格 JSON 输出', () {
      expect(AiService.systemPrompt, contains('只输出一个 JSON 对象'));
    });

    test('要求不确定时返回 0 而非编造', () {
      expect(AiService.systemPrompt, contains('宁可返回 0'));
      expect(AiService.systemPrompt, contains('不要编造'));
    });

    test('包含每 100g 可食部口径与常见重量基准', () {
      expect(AiService.systemPrompt, contains('每 100 克'));
      expect(AiService.systemPrompt, contains('可食'));
      expect(AiService.systemPrompt, contains('一碗米饭'));
    });

    test('给出示例输出以稳定格式', () {
      expect(AiService.systemPrompt, contains('"unit_weight"'));
      expect(AiService.systemPrompt, contains('"protein"'));
    });
  });
}
