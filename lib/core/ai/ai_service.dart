import 'dart:convert';

import 'package:http/http.dart' as http;

/// AI 识别的结构化结果。
class AiResult {
  const AiResult({
    required this.name,
    required this.unitWeight,
    required this.carbsPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
  });

  /// 食物名（含去皮/去蛋黄等加工描述）。
  final String name;

  /// 单个标准重量（克）。
  final double unitWeight;

  final double carbsPer100g;
  final double proteinPer100g;
  final double fatPer100g;
}

/// 智谱 GLM-4-Flash 营养识别服务。
class AiService {
  AiService({required this.apiKey});

  final String apiKey;

  static const _baseUrl = 'https://open.bigmodel.cn/api/paas/v4';
  static const _model = 'glm-4-flash';

  /// 移动网络下 15s 偏紧，放宽到 20s。
  static const requestTimeout = Duration(seconds: 20);

  /// 系统提示词（公开为常量，便于单测校验关键约束没有在改动中丢失）。
  ///
  /// 约束按「错误代价」排序：宁可返回 0 让用户补录，也不能编造一个看起来
  /// 合理的数字 —— 编造的数据会一路污染到 10 天校准的建议里。
  static const systemPrompt = r"""你是中国食物成分数据助手。给定一个食物，输出它的营养成分。
只输出一个 JSON 对象，不要输出任何解释、单位说明或代码块标记。

字段与含义：
- name：食物名，保留用户提到的加工方式（如「去皮鸡腿」「水煮蛋」「无糖豆浆」）
- unit_weight：该食物一个或一份的常见重量（克）。如鸡蛋约50、一碗米饭约150、一个苹果约200
- carbs：每 100 克**可食部**的碳水化合物克数
- protein：每 100 克可食部的蛋白质克数
- fat：每 100 克可食部的脂肪克数

准确性要求（按重要性排序）：
1. 数据须符合常识：三者换算热量（碳水与蛋白各 4 kcal/g，脂肪 9 kcal/g）应落在 30–900 kcal/100g 之间
2. 不确定或非常见食物，宁可返回 0，也不要编造看似合理的数值
3. 中餐按常见做法取值（清炒/红烧/油炸的热量差异很大，取最常见的做法）
4. 生熟区分明确，默认按「通常食用状态」取值（米饭、面条、肉类按熟重）
5. 单位统一为每 100 克可食部，不含骨头、蛋壳等不可食部分
6. 复合菜品（如青椒炒肉、蛋炒饭）按整道菜综合估算，不要把配料拆成多个对象

示例：
{"name":"水煮蛋","unit_weight":50,"carbs":1.1,"protein":13.1,"fat":8.6}
{"name":"米饭(熟)","unit_weight":150,"carbs":25.9,"protein":2.6,"fat":0.3}""";

  /// 识别食物营养，返回结构化结果。
  Future<AiResult> recognize(String foodName) async {
    final resp = await http
        .post(
          Uri.parse('$_baseUrl/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _model,
            'temperature': 0.1,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': foodName},
            ],
          }),
        )
        .timeout(requestTimeout);

    if (resp.statusCode != 200) {
      throw AiException('请求失败（HTTP ${resp.statusCode}）');
    }
    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final content =
        (data['choices'] as List).first['message']['content'] as String;
    final result = parseAiNutrition(content);
    return result.name.isEmpty
        ? AiResult(
            name: foodName,
            unitWeight: result.unitWeight,
            carbsPer100g: result.carbsPer100g,
            proteinPer100g: result.proteinPer100g,
            fatPer100g: result.fatPer100g,
          )
        : result;
  }
}

/// 解析 AI 返回的结构化营养 JSON（纯函数，可单测）。
///
/// 容错顺序：直接解析 → 扫出平衡的 JSON 对象 → 取最内层对象。
/// 之前用 `\{[^{}]*\}` 只能匹配不含花括号的单层对象，遇到嵌套
/// （如补充字段）或 name 里出现花括号就会解析失败。
AiResult parseAiNutrition(String content) {
  final obj = _extractJsonObject(content);
  if (obj == null) {
    throw AiException('无法从 AI 返回中解析出营养数据');
  }
  return AiResult(
    name: (obj['name'] as String?)?.trim() ?? '',
    unitWeight: _positiveNum(obj['unit_weight'], 100),
    carbsPer100g: _nonNegativeNum(obj['carbs'], 0),
    proteinPer100g: _nonNegativeNum(obj['protein'], 0),
    fatPer100g: _nonNegativeNum(obj['fat'], 0),
  );
}

/// 从可能带 markdown 包裹或前后废话的文本里抽出 JSON 对象。
Map<String, dynamic>? _extractJsonObject(String content) {
  final text = content.trim();

  // 1) 整个内容就是 JSON
  final direct = _tryDecode(text);
  if (direct != null) return direct;

  // 2) 扫描出第一个括号平衡的对象（正确跳过字符串内的花括号）
  var depth = 0;
  var start = -1;
  var inString = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inString) {
      if (ch == '"') inString = false;
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{') {
      if (depth == 0) start = i;
      depth++;
    } else if (ch == '}') {
      if (depth > 0) {
        depth--;
        if (depth == 0 && start >= 0) {
          final decoded = _tryDecode(text.substring(start, i + 1));
          if (decoded != null) return decoded;
        }
      }
    }
  }

  // 3) 兜底：取第一个不含嵌套花括号的对象
  final match = RegExp(r'\{[^{}]*\}').firstMatch(text);
  return match == null ? null : _tryDecode(match.group(0)!);
}

Map<String, dynamic>? _tryDecode(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

double _nonNegativeNum(Object? v, double fallback) {
  if (v is num && v.isFinite && v >= 0) return v.toDouble();
  return fallback;
}

double _positiveNum(Object? v, double fallback) {
  if (v is num && v.isFinite && v > 0) return v.toDouble();
  return fallback;
}

class AiException implements Exception {
  AiException(this.message);

  final String message;

  @override
  String toString() => message;
}
