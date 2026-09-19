import 'weekly_status.dart';

/// 周状态跟踪器：记录每周训练欲望与睡眠质量，供校准周期作辅助参考。
class StatusTracker {
  final List<WeeklyStatus> _records = [];

  List<WeeklyStatus> get records => List.unmodifiable(_records);

  /// 记录某一周状态；若该周已存在则覆盖。
  void record(WeeklyStatus status) {
    final i = _records.indexWhere((r) => r.weekStart == status.weekStart);
    if (i == -1) {
      _records.add(status);
    } else {
      _records[i] = status;
    }
  }

  /// 最近一周的状态；无记录时返回 null。
  WeeklyStatus? get latest {
    if (_records.isEmpty) return null;
    return _records.reduce((a, b) => a.weekStart.isAfter(b.weekStart) ? a : b);
  }
}
