/// 智能输入解析结果。
class SmartInput {
  const SmartInput({
    required this.name,
    this.weightGrams,
    this.quantity,
    this.carbs,
    this.protein,
    this.fat,
  });

  final String name;
  final double? weightGrams;

  /// 数量词（个/只/份/片/块/碗/杯）。
  final double? quantity;

  final double? carbs;
  final double? protein;
  final double? fat;

  /// 用户是否报了宏量（非 null 即视为已提供，无需查库/AI）。
  bool get hasMacros => carbs != null || protein != null || fat != null;
}

/// 中文数字转数值。支持 一~九、两、十，以及 十一~九十九。非数字返回 null。
double? parseChineseNumber(String s) {
  const single = {
    '零': 0.0, '一': 1.0, '二': 2.0, '两': 2.0, '三': 3.0, '四': 4.0,
    '五': 5.0, '六': 6.0, '七': 7.0, '八': 8.0, '九': 9.0,
  };
  if (s.isEmpty) return null;
  if (s == '十') return 10.0;
  if (s.length == 1) return single[s];
  if (s.startsWith('十')) return 10.0 + (single[s.substring(1)] ?? 0.0);
  if (s.contains('十')) {
    final parts = s.split('十');
    final tens = single[parts[0]] ?? 0.0;
    final ones = parts.length > 1 && parts[1].isNotEmpty
        ? (single[parts[1]] ?? 0.0)
        : 0.0;
    return tens * 10 + ones;
  }
  return null;
}

/// 完整量词清单：可数个体 + 容器/份量。
const String _measureWords = '个|只|条|根|颗|粒|枚|块|片|瓣|段|节|头|尾|朵|张|把|串|对|双|打|'
    '份|碗|杯|盘|碟|盒|包|袋|瓶|罐|听|桶|壶|勺|匙|盅';

/// 数量倍率正则：分数 / 小数 / 半 / 中文数字，后接量词。
final RegExp _quantityRegex = RegExp(
    '((?:[零一二两三四五六七八九十]+分之[零一二两三四五六七八九十]+)'
    '|(?:[0-9]+(?:\\.[0-9]+)?)'
    '|半'
    '|(?:[零一二两三四五六七八九十]+))\\s*($_measureWords)');

/// 解析数量倍率：半 → 0.5；小数/整数 → 数字；X分之Y → Y/X；中文数字 → 数字。
double? _parseFactor(String expr) {
  final s = expr.trim();
  if (s == '半') return 0.5;
  final num = double.tryParse(s);
  if (num != null) return num;
  final frac = RegExp('([零一二两三四五六七八九十]+)分之([零一二两三四五六七八九十]+)')
      .firstMatch(s);
  if (frac != null) {
    final denom = parseChineseNumber(frac.group(1)!); // 分母
    final numer = parseChineseNumber(frac.group(2)!); // 分子
    if (denom != null && numer != null && denom != 0) return numer / denom;
  }
  return parseChineseNumber(s);
}

/// 双向提取营养素值：支持「蛋白质100g」与「100g蛋白质」两种顺序。
double? _extractMacro(String s, String keyword) {
  final fwd =
      RegExp('(?:$keyword)\\D{0,3}(\\d+(?:\\.\\d+)?)').firstMatch(s);
  if (fwd != null) return double.parse(fwd.group(1)!);
  final rev =
      RegExp('(\\d+(?:\\.\\d+)?)\\D{0,3}(?:$keyword)').firstMatch(s);
  if (rev != null) return double.parse(rev.group(1)!);
  return null;
}

/// 解析智能输入字符串，提取 食物名 / 重量 / 数量 / 宏量。
///
/// 优先级：
/// 1. 比例换算式（含「每100g」密度）→ 直接换算总宏量；
/// 2. 直接宏量式（顺序无关）→ 直接用用户报的数；
/// 3~5. 数量词 / 加工词 / 纯食物名 → 由调用方查本地库。
SmartInput parseSmartInput(String input) {
  final s = input.trim();
  if (RegExp('每\\s*100\\s*(?:g|克)').hasMatch(s)) {
    return _parseRatio(s);
  }
  return _parseDirect(s);
}

/// 比例换算式：「吃了30g蛋白粉，每100g有60g蛋白质」→ 总宏量 = 密度 × 总量/100。
SmartInput _parseRatio(String s) {
  final marker = RegExp('每\\s*100\\s*(?:g|克)').firstMatch(s)!;
  final totalPart = s.substring(0, marker.start);
  final densityPart = s.substring(marker.end);

  final densityCarbs = _extractMacro(densityPart, '碳水');
  final densityProtein = _extractMacro(densityPart, '蛋白质|蛋白');
  final densityFat = _extractMacro(densityPart, '脂肪|脂');

  final wm = RegExp('(\\d+(?:\\.\\d+)?)\\s*(?:g|克|公斤|kg|KG)')
      .firstMatch(totalPart);
  final weight = wm == null ? null : double.parse(wm.group(1)!);
  final w = weight ?? 100;

  double? conv(double? density) => density == null ? null : density * w / 100;

  final name = totalPart
      .replaceAll(RegExp('\\d+(?:\\.\\d+)?'), ' ')
      .replaceAll(RegExp('克|公斤|千克|kg|KG|g|吃了|含|，|,'), ' ')
      .replaceAll(RegExp('\\s+'), ' ')
      .trim();

  return SmartInput(
    name: name,
    weightGrams: weight,
    carbs: conv(densityCarbs),
    protein: conv(densityProtein),
    fat: conv(densityFat),
  );
}

/// 直接宏量式 / 数量词 / 纯食物名解析。
SmartInput _parseDirect(String s) {
  final carbs = _extractMacro(s, '碳水');
  final protein = _extractMacro(s, '蛋白质|蛋白');
  final fat = _extractMacro(s, '脂肪|脂');

  // 数量词：倍率（分数/小数/半/数字）+ 量词
  final qtyMatch = _quantityRegex.firstMatch(s);
  double? quantity;
  if (qtyMatch != null) {
    quantity = _parseFactor(qtyMatch.group(1)!);
  }

  // 去掉宏量片段（双向）、数量词片段后，找重量。
  final rest = s
      .replaceAll(
          RegExp('(?:碳水|蛋白质|蛋白|脂肪|脂)\\D{0,3}\\d+(?:\\.\\d+)?'), ' ')
      .replaceAll(
          RegExp('\\d+(?:\\.\\d+)?\\D{0,3}(?:碳水|蛋白质|蛋白|脂肪|脂)'), ' ')
      .replaceAll(_quantityRegex, ' ');

  final wm = RegExp('(\\d+(?:\\.\\d+)?)\\s*(?:g|克|公斤|kg|KG)').firstMatch(rest);
  final weight = wm == null ? null : double.parse(wm.group(1)!);

  final name = rest
      .replaceAll(RegExp('\\d+(?:\\.\\d+)?'), ' ')
      .replaceAll(RegExp('克|公斤|千克|kg|KG|g'), ' ')
      .replaceAll(RegExp('\\s+'), ' ')
      .trim();

  return SmartInput(
    name: name,
    weightGrams: weight,
    quantity: quantity,
    carbs: carbs,
    protein: protein,
    fat: fat,
  );
}
