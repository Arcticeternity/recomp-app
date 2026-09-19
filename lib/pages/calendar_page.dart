import 'package:flutter/material.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../core/food/daily_log.dart';
import '../core/food/food_entry.dart';
import '../core/food/meal.dart';
import '../core/format.dart';
import '../core/macro/macro_target.dart';
import '../core/profile/weight_record.dart';
import '../core/storage/app_repository.dart' show dateKey;
import '../widgets/status_placeholder.dart';
import 'settings_page.dart';

/// 历史饮食日历（第 5 个 Tab）：月视图 + 明细页。
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.state});

  final AppState state;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
        actions: [settingsButton(context, widget.state)],
      ),
      body: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => Column(
          children: [
            _monthHeader(context),
            _weekHeader(context),
            Expanded(child: _monthGrid()),
          ],
        ),
      ),
    );
  }

  Widget _monthHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _changeMonth(-1),
        ),
        Expanded(
          child: Center(
            child: Text(
              '${_month.year} 年 ${_month.month} 月',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _weekHeader(BuildContext context) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: Text(l,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ),
      ],
    );
  }

  Widget _monthGrid() {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = firstDay.weekday - 1; // 周一开头
    final cellCount = leading + daysInMonth;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
      ),
      itemCount: cellCount,
      itemBuilder: (context, i) {
        if (i < leading) return const SizedBox();
        final day = i - leading + 1;
        final date = DateTime(_month.year, _month.month, day);
        return _DayCell(
          day: date,
          hasRecord: widget.state.entryDates.contains(dateKey(date)),
          isToday: dateKey(date) == dateKey(DateTime.now()),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DayDetailPage(state: widget.state, date: date),
            ),
          ),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasRecord,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final bool hasRecord;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = hasRecord ? scheme.onSurface : scheme.outlineVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${day.day}',
              style: TextStyle(
                  color: textColor,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(height: 3),
          if (hasRecord)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary,
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// 某日饮食明细页。
class DayDetailPage extends StatefulWidget {
  const DayDetailPage({super.key, required this.state, required this.date});

  final AppState state;
  final DateTime date;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  List<FoodEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.state.loadEntriesFor(dateKey(widget.date));
    if (mounted) setState(() => _entries = entries);
  }

  WeightRecord? _weightOf() {
    for (final w in widget.state.weightRecords) {
      if (dateKey(w.date) == dateKey(widget.date)) return w;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.state.profile;
    final target = profile == null
        ? const MacroTarget(carbs: 0, protein: 0, fat: 0)
        : widget.state.dailyTarget;
    final entries = _entries;

    return Scaffold(
      appBar: AppBar(
          title:
              Text('${widget.date.month} 月 ${widget.date.day} 日')),
      body: entries == null
          ? const LoadingPlaceholder()
          : _buildBody(context, target, entries),
    );
  }

  Widget _buildBody(
      BuildContext context, MacroTarget target, List<FoodEntry> entries) {
    final log = DailyLog(target: target);
    for (final e in entries) {
      log.add(e);
    }
    final total = log.totalIntake;
    final remaining = log.remaining;
    final weight = _weightOf();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (weight != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_weight_outlined),
              title: Text('当天体重'),
              trailing: Text('${formatNum(weight.weightKg)} kg',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
        _MacroLine('碳水', total.carbs, target.carbs, remaining.carbs),
        _MacroLine('蛋白质', total.protein, target.protein, remaining.protein),
        _MacroLine('脂肪', total.fat, target.fat, remaining.fat),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('这天没有饮食记录')),
          )
        else
          for (final meal in MealType.values)
            _MealGroup(meal: meal, entries: entries.where((e) => e.meal == meal).toList()),
      ],
    );
  }
}

class _MacroLine extends StatelessWidget {
  const _MacroLine(this.label, this.consumed, this.target, this.remaining);

  final String label;
  final double consumed;
  final double target;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final over = remaining < 0;
    final statusColors = statusColorsFor(Theme.of(context).brightness);
    final color = over ? statusColors.over : statusColors.onTrack;
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text('${formatNum(consumed)} / ${formatNum(target)} g'),
        trailing: Text(
          over ? '超 ${formatNum(-remaining)}g' : '余 ${formatNum(remaining)}g',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _MealGroup extends StatelessWidget {
  const _MealGroup({required this.meal, required this.entries});

  final MealType meal;
  final List<FoodEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(meal.label, style: Theme.of(context).textTheme.titleMedium),
        for (final e in entries)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${e.food.name} · ${formatNum(e.weightGrams)}g'),
            subtitle: Text(
              '碳水 ${formatNum(e.carbs)} · 蛋白 ${formatNum(e.protein)} · 脂肪 ${formatNum(e.fat)}',
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
