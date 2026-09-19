import 'package:flutter/foundation.dart';

import '../core/food/food_entry.dart';
import '../core/food/food_item.dart';
import '../core/profile/weekly_status.dart';
import '../core/profile/weight_record.dart';
import '../core/storage/app_repository.dart';

/// 饮食 + 健康记录域：当天录入、自定义食物、体重记录、周状态。
class FoodLogStore extends ChangeNotifier {
  FoodLogStore(this._repository);

  final AppRepository _repository;

  List<FoodEntry> _entries = [];
  Set<String> _entryDates = {};
  List<FoodItem> _customFoods = [];
  List<WeightRecord> _weightRecords = [];
  List<WeeklyStatus> _weeklyStatuses = [];

  List<FoodEntry> get entries => List.unmodifiable(_entries);
  Set<String> get entryDates => _entryDates;
  List<FoodItem> get customFoods => List.unmodifiable(_customFoods);
  List<WeightRecord> get weightRecords => List.unmodifiable(_weightRecords);
  List<WeeklyStatus> get weeklyStatuses => List.unmodifiable(_weeklyStatuses);

  Future<void> load() async {
    _entries = await _repository.loadEntries(dateKey(DateTime.now()));
    _entryDates = (await _repository.loadEntryDates()).toSet();
    _customFoods = await _repository.loadCustomFoods();
    _weightRecords = await _repository.loadWeightRecords();
    _weeklyStatuses = await _repository.loadWeeklyStatuses();
    notifyListeners();
  }

  Future<List<FoodEntry>> loadEntriesFor(String key) =>
      _repository.loadEntries(key);

  Future<void> addEntry(FoodEntry entry) async {
    _entries.add(entry);
    _entryDates.add(dateKey(DateTime.now()));
    notifyListeners();
    await _repository.saveEntries(dateKey(DateTime.now()), _entries);
  }

  Future<void> removeEntry(FoodEntry entry) async {
    _entries.remove(entry);
    if (_entries.isEmpty) {
      _entryDates.remove(dateKey(DateTime.now()));
    }
    notifyListeners();
    await _repository.saveEntries(dateKey(DateTime.now()), _entries);
  }

  Future<void> addCustomFood(FoodItem item) async {
    _customFoods.add(item);
    notifyListeners();
    await _repository.addCustomFood(item);
  }

  Future<void> deleteCustomFood(String name) async {
    _customFoods.removeWhere((f) => f.name == name);
    notifyListeners();
    await _repository.deleteCustomFood(name);
  }

  Future<void> addWeightRecord(WeightRecord record) async {
    _weightRecords.removeWhere((w) => dateKey(w.date) == dateKey(record.date));
    _weightRecords.add(record);
    _weightRecords.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
    await _repository.addWeightRecord(record);
  }

  Future<void> updateWeightRecord(String oldKey, WeightRecord record) async {
    _weightRecords.removeWhere((w) => dateKey(w.date) == oldKey);
    _weightRecords.add(record);
    _weightRecords.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
    await _repository.updateWeightRecord(oldKey, record);
  }

  Future<void> deleteWeightRecord(String key) async {
    _weightRecords.removeWhere((w) => dateKey(w.date) == key);
    notifyListeners();
    await _repository.deleteWeightRecord(key);
  }

  Future<void> saveWeeklyStatus(WeeklyStatus status) async {
    _weeklyStatuses
        .removeWhere((w) => dateKey(w.weekStart) == dateKey(status.weekStart));
    _weeklyStatuses.add(status);
    notifyListeners();
    await _repository.saveWeeklyStatus(status);
  }
}
