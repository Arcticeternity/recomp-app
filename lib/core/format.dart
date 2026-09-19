/// 数字格式化：整数去小数点，小数最多保留 2 位并去尾零。
///
/// 例：187.0 → "187"；2.2 → "2.2"；2.25 → "2.25"。
String formatNum(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  var s = v.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  s = s.replaceFirst(RegExp(r'\.$'), '');
  return s;
}
