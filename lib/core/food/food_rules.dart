/// 加工描述解析结果。
class ProcessingResult {
  const ProcessingResult({
    required this.baseName,
    required this.peel,
    required this.noYolk,
    required this.boneOut,
    required this.lowFat,
    required this.skim,
  });

  /// 去掉加工词后的基础食物名。
  final String baseName;

  /// 去皮（带皮肉类 → 脂肪减半）。
  final bool peel;

  /// 去蛋黄（鸡蛋 → 按蛋清算）。
  final bool noYolk;

  /// 去骨（去骨肉类 → 按净肉算）。
  final bool boneOut;

  /// 低脂（乳制品 → 脂肪约为全脂 40%）。
  final bool lowFat;

  /// 脱脂（乳制品 → 脂肪近似 0）。
  final bool skim;
}

/// 加工词列表（提取顺序与替换一致）。
const List<String> _processingWords = [
  '去皮', '去蛋黄', '去骨', '全脂', '低脂', '脱脂',
];

/// 解析加工词，返回基础食物名 + 规则标记。
///
/// 用法：先提取加工词 → 用 [baseName] 查本地库 → 查库后用 [applyProcessing] 套规则。
ProcessingResult parseProcessing(String name) {
  var base = name;
  for (final w in _processingWords) {
    base = base.replaceAll(w, '');
  }
  return ProcessingResult(
    baseName: base.trim(),
    peel: name.contains('去皮'),
    noYolk: name.contains('去蛋黄'),
    boneOut: name.contains('去骨'),
    lowFat: name.contains('低脂'),
    skim: name.contains('脱脂'),
  );
}

/// 加工后的每 100g 营养值。
class ProcessedMacros {
  const ProcessedMacros({
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final double carbs;
  final double protein;
  final double fat;
}

/// 在基础食物营养值上应用加工规则。
///
/// - 去皮：脂肪 × 0.5（皮含大量脂肪），蛋白/碳水不变。
/// - 去骨：脂肪 × 0.8（去骨去掉附骨脂肪，估值），蛋白/碳水不变。
/// - 低脂：脂肪 × 0.4（乳制品低脂约为全脂 40%）。
/// - 脱脂：脂肪 × 0.03（乳制品脱脂近似 0）。
/// - 去蛋黄：按蛋清算，脂肪 ≈ 0、蛋白约 10g/100g、碳水约 1g/100g。
ProcessedMacros applyProcessing(
  double carbs,
  double protein,
  double fat, {
  required bool peel,
  required bool noYolk,
  bool boneOut = false,
  bool lowFat = false,
  bool skim = false,
}) {
  var c = carbs;
  var p = protein;
  var f = fat;
  if (noYolk) {
    c = 1;
    p = 10;
    f = 0;
    return ProcessedMacros(carbs: c, protein: p, fat: f);
  }
  if (peel) f = f * 0.5;
  if (boneOut) f = f * 0.8;
  if (lowFat) f = f * 0.4;
  if (skim) f = f * 0.03;
  return ProcessedMacros(carbs: c, protein: p, fat: f);
}

/// 常见食物单份重量表（可食部净重，克/份）。
///
/// 鸡腿/鸭腿去皮净肉为估值，可在确认卡片修正；表可增补。
const Map<String, double> unitWeights = {
  '鸡蛋': 50,
  '鸡腿': 100,
  '鸭腿': 110,
  '面包': 30,
};

/// 查单份重量，未收录返回 null。
double? lookupUnitWeight(String name) => unitWeights[name];
