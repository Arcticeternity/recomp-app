import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/calibration/calibration_engine.dart';
import '../core/calibration/calibration_result.dart';
import '../core/calibration/calibration_types.dart';
import '../core/format.dart';
import '../core/macro/macro_ratio.dart';
import '../core/profile/user_profile.dart';
import '../core/profile/weekly_status.dart';
import '../core/profile/weight_record.dart';
import '../core/storage/app_repository.dart' show dateKey;
import '../widgets/status_placeholder.dart';
import 'settings_page.dart';

/// 周期页：体重记录、10 天校准、周状态跟踪。
class CyclePage extends StatelessWidget {
  const CyclePage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final profile = state.profile;
        return Scaffold(
          appBar: AppBar(
            title: const Text('周期'),
            actions: [settingsButton(context, state)],
          ),
          body: profile == null
              ? const Center(child: Text('请先完成引导'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _WeightChartSection(state: state),
                    const SizedBox(height: 16),
                    _WeightSection(state: state),
                    const SizedBox(height: 16),
                    _CalibrationSection(state: state),
                    const SizedBox(height: 16),
                    _StatusSection(state: state),
                  ],
                ),
        );
      },
    );
  }
}

class _WeightSection extends StatefulWidget {
  const _WeightSection({required this.state});

  final AppState state;

  @override
  State<_WeightSection> createState() => _WeightSectionState();
}

class _WeightSectionState extends State<_WeightSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final w = double.tryParse(_controller.text);
    if (w == null || w <= 0) return;
    HapticFeedback.lightImpact();
    widget.state.addWeightRecord(WeightRecord(date: DateTime.now(), weightKg: w));
    _controller.clear();
  }

  void _showMenu(WeightRecord r) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('修改'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') {
      await _editRecord(r);
    } else if (action == 'delete') {
      await _deleteRecord(r);
    }
  }

  Future<void> _editRecord(WeightRecord r) async {
    final result = await showDialog<WeightRecord>(
      context: context,
      builder: (_) => _EditWeightDialog(record: r),
    );
    if (result != null) {
      await widget.state.updateWeightRecord(dateKey(r.date), result);
    }
  }

  Future<void> _deleteRecord(WeightRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除体重记录'),
        content: Text(
            '确定删除 ${r.date.year}-${r.date.month}-${r.date.day} 的 ${formatNum(r.weightKg)}kg 记录吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      HapticFeedback.mediumImpact();
      await widget.state.deleteWeightRecord(dateKey(r.date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.state.weightRecords;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('体重记录', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '今日体重',
                      suffixText: 'kg',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _add, child: const Text('记录')),
              ],
            ),
            const SizedBox(height: 12),
            if (records.isEmpty)
              const Text('还没有记录，添加第一条体重吧')
            else
              for (final r in records.reversed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: Text('${formatNum(r.weightKg)} kg'),
                  subtitle: Text('${r.date.year}-${r.date.month}-${r.date.day}'),
                  onLongPress: () => _showMenu(r),
                ),
          ],
        ),
      ),
    );
  }
}

/// 修改体重记录对话框。
class _EditWeightDialog extends StatefulWidget {
  const _EditWeightDialog({required this.record});

  final WeightRecord record;

  @override
  State<_EditWeightDialog> createState() => _EditWeightDialogState();
}

class _EditWeightDialogState extends State<_EditWeightDialog> {
  late final TextEditingController _weightController;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _weightController =
        TextEditingController(text: formatNum(widget.record.weightKg));
    _date = widget.record.date;
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final w = double.tryParse(_weightController.text);
    if (w == null || w <= 0) return;
    Navigator.pop(context, WeightRecord(date: _date, weightKg: w));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改体重记录'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '体重',
              suffixText: 'kg',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('记录日期'),
            trailing: Text(
                '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
            onTap: _pickDate,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}

class _CalibrationSection extends StatelessWidget {
  const _CalibrationSection({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile!;
    final records = state.weightRecords;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('10 天校准', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (records.length < 2)
              const Text('至少记录 2 次体重（相隔 7-10 天）后，这里会给出调整建议。')
            else
              _buildResult(context, profile),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context, UserProfile profile) {
    final records = state.weightRecords;
    final start = records.first;
    final end = records.last;
    final days = end.date.difference(start.date).inDays;
    final latest = state.weeklyStatuses.isEmpty ? null : state.weeklyStatuses.last;

    // 用「生效配比」而非推荐值：用户自定义配比后，校准必须从实际在用的
    // 碳水基准出发，否则建议会基于一个他并没有执行的数字。
    final effectiveRatio = state.macroRatioSettings.ratio;

    final result = CalibrationEngine().evaluate(
      gender: profile.gender,
      currentWeightKg: end.weightKg,
      training: profile.training,
      currentCarbsPerKg: effectiveRatio.carbsPerKg,
      startWeightKg: start.weightKg,
      endWeightKg: end.weightKg,
      days: days < 1 ? 1 : days,
      desire: latest?.desire,
      sleep: latest?.sleep,
    );

    final actionable = result.action != AdjustmentAction.maintain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('周期 ${days < 1 ? 1 : days} 天：'
            '${formatNum(start.weightKg)}kg → ${formatNum(end.weightKg)}kg'),
        const SizedBox(height: 8),
        Text(result.explanation),
        if (actionable) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _applySuggestion(context, result),
            icon: const Icon(Icons.check, size: 18),
            label: Text(
              '应用建议（碳水 '
              '${formatNum(effectiveRatio.carbsPerKg)} → '
              '${formatNum(result.newCarbsPerKg)} g/kg）',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  /// 把校准建议写回配比 —— 否则建议只停留在文案里，用户以为已经生效。
  Future<void> _applySuggestion(
    BuildContext context,
    CalibrationResult result,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final current = state.macroRatioSettings.ratio;
    HapticFeedback.mediumImpact();
    await state.saveMacroRatio(MacroRatio(
      carbsPerKg: result.newCarbsPerKg,
      proteinPerKg: current.proteinPerKg,
      fatPerKg: current.fatPerKg,
    ));
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('碳水配比已更新为 ${formatNum(result.newCarbsPerKg)} g/kg'),
      ),
    );
  }
}

class _StatusSection extends StatefulWidget {
  const _StatusSection({required this.state});

  final AppState state;

  @override
  State<_StatusSection> createState() => _StatusSectionState();
}

class _StatusSectionState extends State<_StatusSection> {
  TrainingDesire _desire = TrainingDesire.medium;
  SleepQuality _sleep = SleepQuality.medium;

  void _save() {
    HapticFeedback.lightImpact();
    widget.state.saveWeeklyStatus(
      WeeklyStatus(weekStart: DateTime.now(), desire: _desire, sleep: _sleep),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本周状态（辅助参考）',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('训练欲望'),
            Wrap(
              spacing: 8,
              children: [
                for (final d in TrainingDesire.values)
                  ChoiceChip(
                    label: Text(_desireLabel(d)),
                    selected: d == _desire,
                    onSelected: (_) => setState(() => _desire = d),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('睡眠质量'),
            Wrap(
              spacing: 8,
              children: [
                for (final s in SleepQuality.values)
                  ChoiceChip(
                    label: Text(_sleepLabel(s)),
                    selected: s == _sleep,
                    onSelected: (_) => setState(() => _sleep = s),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _save, child: const Text('保存本周状态')),
          ],
        ),
      ),
    );
  }

  String _desireLabel(TrainingDesire d) => switch (d) {
        TrainingDesire.high => '高',
        TrainingDesire.medium => '中',
        TrainingDesire.low => '低',
      };

  String _sleepLabel(SleepQuality s) => switch (s) {
        SleepQuality.good => '好',
        SleepQuality.medium => '中',
        SleepQuality.poor => '差',
      };
}

/// 体重曲线：折线图 + 范围切换（7 天 / 30 天 / 全部）。
class _WeightChartSection extends StatefulWidget {
  const _WeightChartSection({required this.state});

  final AppState state;

  @override
  State<_WeightChartSection> createState() => _WeightChartSectionState();
}

class _WeightChartSectionState extends State<_WeightChartSection> {
  int _range = 7; // 7 / 30 / 0=全部

  @override
  Widget build(BuildContext context) {
    final records = _filter(widget.state.weightRecords);
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 标题可压缩、分段按钮保固有宽度：Spacer 会在窄屏上直接挤爆这一行。
                Expanded(
                  child: Text(
                    '体重曲线',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7天')),
                    ButtonSegment(value: 30, label: Text('30天')),
                    ButtonSegment(value: 0, label: Text('全部')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                  showSelectedIcon: false,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              width: double.infinity,
              child: records.isEmpty
                  ? const EmptyPlaceholder(
                      message: '暂无体重数据', icon: Icons.show_chart)
                  : CustomPaint(
                      painter: _WeightChartPainter(records, primary)),
            ),
          ],
        ),
      ),
    );
  }

  List<WeightRecord> _filter(List<WeightRecord> records) {
    if (_range == 0) return records;
    final cutoff = DateTime.now().subtract(Duration(days: _range));
    return records.where((r) => r.date.isAfter(cutoff)).toList();
  }
}

class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter(this.records, this.color);

  final List<WeightRecord> records;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;
    const left = 16.0, right = 16.0, top = 16.0, bottom = 22.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    if (w <= 0 || h <= 0) return;

    final weights = records.map((r) => r.weightKg).toList();
    var minW = weights.reduce(math.min);
    var maxW = weights.reduce(math.max);
    var pad = (maxW - minW) * 0.25;
    if (pad == 0) {
      minW -= 1;
      maxW += 1;
    } else {
      minW -= pad;
      maxW += pad;
    }

    final first = records.first.date;
    final spanSeconds = records.last.date.difference(first).inSeconds;

    Offset pos(int i) {
      final t = records[i].date.difference(first).inSeconds;
      final x = spanSeconds == 0 ? left + w / 2 : left + (t / spanSeconds) * w;
      final y = top + (maxW - records[i].weightKg) / (maxW - minW) * h;
      return Offset(x, y);
    }

    // 折线
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < records.length; i++) {
      final p = pos(i);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    // 数据点
    final dotPaint = Paint()..color = color;
    for (var i = 0; i < records.length; i++) {
      canvas.drawCircle(pos(i), 4, dotPaint);
    }

    // 标签
    final firstDate = records.first.date;
    final lastDate = records.last.date;
    _text(canvas, '${firstDate.month}/${firstDate.day}', const Offset(left, 0));
    _text(canvas, '${lastDate.month}/${lastDate.day}',
        Offset(size.width - right, size.height - 16), align: TextAlign.right);
    _text(canvas, formatNum(maxW), Offset(size.width - right, top - 4),
        align: TextAlign.right);
    _text(canvas, formatNum(minW), Offset(size.width - right, top + h - 4),
        align: TextAlign.right);
  }

  void _text(Canvas canvas, String s, Offset pos,
      {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    var dx = pos.dx;
    if (align == TextAlign.right) dx -= tp.width;
    tp.paint(canvas, Offset(dx, pos.dy));
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) =>
      oldDelegate.records != records || oldDelegate.color != color;
}
