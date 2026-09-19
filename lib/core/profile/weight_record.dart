/// 一条体重记录（用于 10 天校准周期的趋势判断）。
class WeightRecord {
  const WeightRecord({required this.date, required this.weightKg});

  final DateTime date;
  final double weightKg;
}
