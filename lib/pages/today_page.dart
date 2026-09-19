import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ai/ai_service.dart';
import '../app_state.dart';
import '../app_theme.dart';
import '../core/food/daily_log.dart';
import '../core/food/food_database.dart';
import '../core/food/food_entry.dart';
import '../core/food/food_item.dart';
import '../core/food/food_rules.dart';
import '../core/food/meal.dart';
import '../core/food/smart_input.dart';
import '../core/format.dart';
import 'settings_page.dart';

/// 今日页：目标 vs 已摄入、剩余额度、按餐分组列表、录入。
class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日'),
        actions: [settingsButton(context, state)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntry(context),
        child: const Icon(Icons.add),
      ),
      // 仅 body 随状态重建，AppBar/FAB 保持静态
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final log = state.todayLog;
          return log == null
              ? const Center(child: Text('请先完成引导'))
              : _buildBody(context, log);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, DailyLog log) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeaderCard(log: log),
        const SizedBox(height: 16),
        for (final meal in MealType.values)
          _MealSection(
            meal: meal,
            entries: state.entries.where((e) => e.meal == meal).toList(),
            onRemove: state.removeEntry,
          ),
        // 底部留白，避免 FAB 遮挡最后一条的删除按钮
        const SizedBox(height: 88),
      ],
    );
  }

  void _showAddEntry(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddEntrySheet(state: state),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.log});

  final DailyLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = log.totalIntake;
    final target = log.target;
    final remaining = log.remaining;
    final ratio = target.calories > 0 ? total.calories / target.calories : 0.0;

    // header 底色始终是 primary 渐变，进度条按它的亮度取色 —— 固定用亮色
    // （原先是 Colors.lightBlueAccent 等）在「练习簿」这类浅色 primary 主题上
    // 会直接看不见。文字仍用 onPrimary：对比度由主题作者保证。
    final barBg = ThemeData.estimateBrightnessForColor(scheme.primary);
    final macroColors = macroColorsOnBackground(barBg);
    final onBar = scheme.onPrimary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.72)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Text(
                  '今日摄入',
                  style: TextStyle(color: scheme.onPrimary, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // 窄屏上「今日摄入 + 卡路里」会挤爆一行，数字优先保留完整。
              Flexible(
                child: Text(
                  '${formatNum(total.calories)} / ${formatNum(target.calories)} kcal',
                  maxLines: 1,
                  style: TextStyle(
                      color: scheme.onPrimary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _CalorieRing(ratio: ratio, color: scheme.onPrimary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _RemainingMacro(
                        label: '碳水剩余', grams: remaining.carbs, color: scheme.onPrimary),
                    const SizedBox(height: 10),
                    _RemainingMacro(
                        label: '蛋白剩余', grams: remaining.protein, color: scheme.onPrimary),
                    const SizedBox(height: 10),
                    _RemainingMacro(
                        label: '脂肪剩余', grams: remaining.fat, color: scheme.onPrimary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _AnimatedMacroBar(
              label: '碳水',
              consumed: total.carbs,
              target: target.carbs,
              color: macroColors.carbs,
              textColor: onBar,
              barBackground: barBg),
          _AnimatedMacroBar(
              label: '蛋白',
              consumed: total.protein,
              target: target.protein,
              color: macroColors.protein,
              textColor: onBar,
              barBackground: barBg),
          _AnimatedMacroBar(
              label: '脂肪',
              consumed: total.fat,
              target: target.fat,
              color: macroColors.fat,
              textColor: onBar,
              barBackground: barBg),
        ],
      ),
    );
  }
}

class _CalorieRing extends StatelessWidget {
  const _CalorieRing({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = ratio.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 9,
              backgroundColor: color.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(color),
            ),
            Text('${(v * 100).round()}%',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _RemainingMacro extends StatelessWidget {
  const _RemainingMacro({
    required this.label,
    required this.grams,
    required this.color,
  });

  final String label;
  final double grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // 两侧都用 Flexible：Spacer 会保留两端文本的固有宽度，
    // 窄屏（320dp）下「碳水剩余 + 数值」必然溢出。
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 13),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text('${formatNum(grams)} g',
              maxLines: 1,
              textAlign: TextAlign.end,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      ],
    );
  }
}

class _AnimatedMacroBar extends StatelessWidget {
  const _AnimatedMacroBar({
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
    required this.textColor,
    required this.barBackground,
  });

  final String label;
  final double consumed;
  final double target;
  final Color color;
  final Color textColor;

  /// 进度条底色的明暗来源，决定空槽的透明叠加方向。
  final Brightness barBackground;

  @override
  Widget build(BuildContext context) {
    final ratio = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    // 空槽颜色跟随背景明暗，保证在 primary 渐变上始终可见。
    final track = barBackground == Brightness.dark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: textColor.withValues(alpha: 0.9), fontSize: 12)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text('${formatNum(consumed)} / ${formatNum(target)} g',
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: textColor.withValues(alpha: 0.9), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: track,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.meal,
    required this.entries,
    required this.onRemove,
  });

  final MealType meal;
  final List<FoodEntry> entries;
  final void Function(FoodEntry) onRemove;

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
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onRemove(e),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AddEntrySheet extends StatefulWidget {
  const _AddEntrySheet({required this.state});

  final AppState state;

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _smartController = TextEditingController();
  final _searchController = TextEditingController();
  final _weightController = TextEditingController();

  MealType _meal = MealType.breakfast;
  FoodItem? _food;
  late List<FoodItem> _results;

  @override
  void initState() {
    super.initState();
    _results = _allFoods();
  }

  @override
  void dispose() {
    _smartController.dispose();
    _searchController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  List<FoodItem> _allFoods() =>
      [...FoodDatabase.seedFoods, ...widget.state.customFoods];

  void _search(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _results = query.isEmpty
          ? _allFoods()
          : _allFoods()
              .where((f) => f.name.toLowerCase().contains(query))
              .toList();
    });
  }

  Future<void> _handleSmartInput() async {
    final text = _smartController.text.trim();
    if (text.isEmpty) return;
    final parsed = parseSmartInput(text);
    if (parsed.name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没识别出食物名')));
      return;
    }

    final proc = parseProcessing(parsed.name);
    var name = parsed.name;
    var unitWeight = 100.0; // 单个标准重量
    final quantity = parsed.quantity;
    var weight = parsed.weightGrams; // 用户明确给的重量
    var carbs = parsed.carbs ?? 0;
    var protein = parsed.protein ?? 0;
    var fat = parsed.fat ?? 0;

    // 没报宏量 → 本地库优先，查不到再回退 AI
    if (!parsed.hasMacros) {
      final foodDb = widget.state.localFoodDb;
      List<FoodItem> hits = [];
      if (foodDb != null && proc.baseName.isNotEmpty) {
        hits = await foodDb.search(proc.baseName);
      }
      if (!mounted) return;

      if (hits.isNotEmpty) {
        // 本地命中：取最接近的一条，应用加工规则
        final hit = hits.first;
        final pm = applyProcessing(
          hit.carbsPer100g,
          hit.proteinPer100g,
          hit.fatPer100g,
          peel: proc.peel,
          noYolk: proc.noYolk,
          boneOut: proc.boneOut,
          lowFat: proc.lowFat,
          skim: proc.skim,
        );
        unitWeight = lookupUnitWeight(proc.baseName) ?? 100.0;
        weight ??= quantity != null ? quantity * unitWeight : 100.0;
        carbs = pm.carbs * weight / 100;
        protein = pm.protein * weight / 100;
        fat = pm.fat * weight / 100;
      } else {
        // 回退 AI
        final key = widget.state.apiKey;
        if (key == null || key.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('本地库未查到且未配置 API Key，宏量暂填 0，可在确认卡片手动补')));
        } else {
          try {
            final ai = await AiService(apiKey: key).recognize(proc.baseName);
            if (ai.name.isNotEmpty) name = ai.name;
            unitWeight = ai.unitWeight;
            // 总重量：给了重量→用重量；给了数量→数量×单重；否则默认100g
            weight ??= quantity != null ? quantity * unitWeight : 100.0;
            carbs = ai.carbsPer100g * weight / 100;
            protein = ai.proteinPer100g * weight / 100;
            fat = ai.fatPer100g * weight / 100;
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('AI 识别失败：$e')));
            }
          }
        }
      }
    }

    weight ??= 100.0; // 兜底：有宏量但没重量没数量
    final finalWeight = weight;

    if (!mounted) return;
    final result = await showDialog<_ConfirmResult>(
      context: context,
      builder: (_) => _SmartConfirmDialog(
        name: name,
        weight: finalWeight,
        carbs: carbs,
        protein: protein,
        fat: fat,
        usedDefaultWeight: parsed.weightGrams == null && parsed.quantity == null,
        info: quantity != null
            ? '${formatNum(quantity)} 个 × 约 ${formatNum(unitWeight)}g'
            : null,
      ),
    );
    if (result == null || !mounted) return;

    final food = FoodDatabase.fromTotal(
      name: result.name,
      weightGrams: result.weight,
      carbs: result.carbs,
      protein: result.protein,
      fat: result.fat,
    );
    if (result.saveToLibrary) {
      await widget.state.addCustomFood(food);
    }
    HapticFeedback.lightImpact();
    await widget.state.addEntry(
        FoodEntry(food: food, weightGrams: result.weight, meal: _meal));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openManual() async {
    final result = await showDialog<_QuickAddResult>(
      context: context,
      builder: (_) => _QuickAddDialog(state: widget.state, meal: _meal),
    );
    if (result == null || !mounted) return;
    if (result.done) {
      Navigator.pop(context);
      return;
    }
    if (result.food != null) {
      setState(() {
        _food = result.food;
        _results = _allFoods();
      });
    }
  }

  Future<void> _confirmDelete(FoodItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除食物'),
        content: Text('确定从食物库删除「${item.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      HapticFeedback.mediumImpact();
      await widget.state.deleteCustomFood(item.name);
      if (mounted) {
        setState(() => _results = _allFoods());
        if (_food?.name == item.name) _food = null;
      }
    }
  }

  void _add() {
    final w = double.tryParse(_weightController.text);
    if (_food == null || w == null || w <= 0) return;
    HapticFeedback.lightImpact();
    widget.state.addEntry(FoodEntry(food: _food!, weightGrams: w, meal: _meal));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('录入食物', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final m in MealType.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: m == _meal,
                    onSelected: (_) => setState(() => _meal = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('smart_input'),
              controller: _smartController,
              onSubmitted: (_) => _handleSmartInput(),
              decoration: InputDecoration(
                labelText: '快速输入',
                hintText: '鸡胸肉200g 或 面包15g 碳水7g 蛋白3g',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _handleSmartInput,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _openManual,
                icon: const Icon(Icons.edit_note),
                label: const Text('手动填写'),
              ),
            ),
            const Divider(height: 24),
            TextField(
              key: const Key('food_search'),
              controller: _searchController,
              onChanged: _search,
              decoration: const InputDecoration(
                labelText: '从食物库选',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '食物库是空的，用上面的快速输入添加吧',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              )
            else
              SizedBox(
                height: 180,
                child: ListView(
                  children: [
                    for (final f in _results)
                      ListTile(
                        title: Text(f.name),
                        subtitle: Text(
                          '碳水 ${formatNum(f.carbsPer100g)} · 蛋白 ${formatNum(f.proteinPer100g)} · 脂肪 ${formatNum(f.fatPer100g)} /100g',
                        ),
                        selected: f == _food,
                        onTap: () => setState(() => _food = f),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(f),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(_food == null ? '未选择食物' : '已选：${_food!.name}'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('food_weight'),
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '重量',
                suffixText: 'g',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _add, child: const Text('添加')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 智能输入确认卡片的结果。
class _ConfirmResult {
  const _ConfirmResult({
    required this.name,
    required this.weight,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.saveToLibrary,
  });

  final String name;
  final double weight;
  final double carbs;
  final double protein;
  final double fat;
  final bool saveToLibrary;
}

/// 智能输入确认卡片：展示并允许修正解析结果。
class _SmartConfirmDialog extends StatefulWidget {
  const _SmartConfirmDialog({
    required this.name,
    required this.weight,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.usedDefaultWeight,
    this.info,
  });

  final String name;
  final double weight;
  final double carbs;
  final double protein;
  final double fat;
  final bool usedDefaultWeight;

  /// 数量×单重的说明信息（如「2 个 × 约 50g」）。
  final String? info;

  @override
  State<_SmartConfirmDialog> createState() => _SmartConfirmDialogState();
}

class _SmartConfirmDialogState extends State<_SmartConfirmDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _weightController;
  late final TextEditingController _carbsController;
  late final TextEditingController _proteinController;
  late final TextEditingController _fatController;
  bool _save = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _weightController = TextEditingController(text: formatNum(widget.weight));
    _carbsController = TextEditingController(text: formatNum(widget.carbs));
    _proteinController = TextEditingController(text: formatNum(widget.protein));
    _fatController = TextEditingController(text: formatNum(widget.fat));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameController.text.trim();
    final w = double.tryParse(_weightController.text);
    final c = double.tryParse(_carbsController.text) ?? 0;
    final p = double.tryParse(_proteinController.text) ?? 0;
    final f = double.tryParse(_fatController.text) ?? 0;
    if (name.isEmpty || w == null || w <= 0) return;
    Navigator.pop(
      context,
      _ConfirmResult(
        name: name,
        weight: w,
        carbs: c,
        protein: p,
        fat: f,
        saveToLibrary: _save,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('确认食物'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.usedDefaultWeight)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '未填重量，默认按 100g',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (widget.info != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  widget.info!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            TextField(
              key: const Key('confirm_name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: '食物名'),
            ),
            TextField(
              key: const Key('confirm_weight'),
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: '重量', suffixText: 'g'),
            ),
            TextField(
              key: const Key('confirm_carbs'),
              controller: _carbsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '碳水（总量 g）'),
            ),
            TextField(
              key: const Key('confirm_protein'),
              controller: _proteinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '蛋白（总量 g）'),
            ),
            TextField(
              key: const Key('confirm_fat'),
              controller: _fatController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '脂肪（总量 g）'),
            ),
            SwitchListTile(
              title: const Text('存入我的食物库'),
              value: _save,
              onChanged: (v) => setState(() => _save = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('确认添加')),
      ],
    );
  }
}

/// 快速添加结果：方式 A/C 返回食物，方式 B 直接完成。
class _QuickAddResult {
  const _QuickAddResult({this.food, this.done = false});

  final FoodItem? food;
  final bool done;
}

/// 手动填写：营养密度 / 一次性 两种方式。
class _QuickAddDialog extends StatefulWidget {
  const _QuickAddDialog({required this.state, required this.meal});

  final AppState state;
  final MealType meal;

  @override
  State<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<_QuickAddDialog> {
  final _nameController = TextEditingController();
  final _carbsController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _weightController = TextEditingController();

  int _mode = 0; // 0=营养密度, 1=一次性

  @override
  void dispose() {
    _nameController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    // 方式 B：一次性，重量 + 总量，直接计入当天（不存库）。
    if (_mode == 1) {
      final w = double.tryParse(_weightController.text);
      final c = double.tryParse(_carbsController.text);
      final p = double.tryParse(_proteinController.text);
      final f = double.tryParse(_fatController.text);
      if (w == null || c == null || p == null || f == null || w <= 0) return;
      final food = FoodDatabase.fromTotal(
        name: name,
        weightGrams: w,
        carbs: c,
        protein: p,
        fat: f,
      );
      HapticFeedback.lightImpact();
      await widget.state
          .addEntry(FoodEntry(food: food, weightGrams: w, meal: widget.meal));
      if (mounted) {
        Navigator.pop(context, const _QuickAddResult(done: true));
      }
      return;
    }

    // 方式 A：每 100g 宏量，返回食物。
    final c = double.tryParse(_carbsController.text);
    final p = double.tryParse(_proteinController.text);
    final f = double.tryParse(_fatController.text);
    if (c == null || p == null || f == null) return;
    final food =
        FoodItem(name: name, carbsPer100g: c, proteinPer100g: p, fatPer100g: f);

    await widget.state.addCustomFood(food); // 存自定义食物库
    if (mounted) Navigator.pop(context, _QuickAddResult(food: food));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手动填写'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('quick_name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: '食物名'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('营养密度')),
                ButtonSegment(value: 1, label: Text('一次性')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 12),
            if (_mode == 1)
              TextField(
                key: const Key('quick_weight'),
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '本次吃了多少克',
                  suffixText: 'g',
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _carbsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _mode == 1 ? '这 X 克碳水总量（g）' : '碳水（g/100g）',
              ),
            ),
            TextField(
              controller: _proteinController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _mode == 1 ? '这 X 克蛋白总量（g）' : '蛋白（g/100g）',
              ),
            ),
            TextField(
              controller: _fatController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _mode == 1 ? '这 X 克脂肪总量（g）' : '脂肪（g/100g）',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_mode == 1 ? '直接添加' : '保存到食物库'),
        ),
      ],
    );
  }
}
