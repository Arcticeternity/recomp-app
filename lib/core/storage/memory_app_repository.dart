import 'dart:convert';

import '../fitness/favorite.dart';
import '../food/food_entry.dart';
import '../food/food_item.dart';
import '../macro/macro_ratio.dart';
import '../profile/user_profile.dart';
import '../profile/weekly_status.dart';
import '../profile/weight_record.dart';
import 'app_repository.dart';

/// 纯内存仓库：不落盘、不依赖 SQLite。
///
/// 两个用途：
/// 1. widget 测试（避免真实数据库 IO 在 fake async 环境中挂起）
/// 2. **Web 启动降级** —— 如果浏览器里的 sqlite3 WASM 初始化失败或卡住，
///    用它兜底，让应用至少能进得去（本次会话可用，刷新即丢）。
class InMemoryAppRepository implements AppRepository {
  UserProfile? _profile;
  final List<FoodItem> _customFoods = [];
  final Map<String, List<FoodEntry>> _entries = {};
  final List<WeeklyStatus> _weeklyStatuses = [];
  final List<WeightRecord> _weightRecords = [];
  String? _theme;
  String? _apiKey;
  String? _macroRatioJson;
  final List<FavoriteGroup> _favoriteGroups = [];
  final List<Map<String, Object>> _favorites = [];
  int _groupSeq = 0;

  @override
  Future<UserProfile?> loadProfile() async => _profile;

  @override
  Future<void> saveProfile(UserProfile profile) async => _profile = profile;

  @override
  Future<List<FoodItem>> loadCustomFoods() async => List.of(_customFoods);

  @override
  Future<void> addCustomFood(FoodItem item) async => _customFoods.add(item);

  @override
  Future<void> deleteCustomFood(String name) async =>
      _customFoods.removeWhere((f) => f.name == name);

  @override
  Future<List<FoodEntry>> loadEntries(String dateKey) async =>
      List.of(_entries[dateKey] ?? const []);

  @override
  Future<void> saveEntries(String dateKey, List<FoodEntry> entries) async =>
      _entries[dateKey] = List.of(entries);

  @override
  Future<List<WeeklyStatus>> loadWeeklyStatuses() async =>
      List.of(_weeklyStatuses);

  @override
  Future<void> saveWeeklyStatus(WeeklyStatus status) async {
    _weeklyStatuses.removeWhere((s) => s.weekStart == status.weekStart);
    _weeklyStatuses.add(status);
  }

  @override
  Future<List<WeightRecord>> loadWeightRecords() async =>
      List.of(_weightRecords);

  @override
  Future<void> addWeightRecord(WeightRecord record) async {
    _weightRecords.removeWhere((r) => r.date == record.date);
    _weightRecords.add(record);
  }

  @override
  Future<void> updateWeightRecord(String oldDateKey, WeightRecord record) async {
    _weightRecords.removeWhere((r) => dateKey(r.date) == oldDateKey);
    _weightRecords.add(record);
  }

  @override
  Future<void> deleteWeightRecord(String key) async {
    _weightRecords.removeWhere((r) => dateKey(r.date) == key);
  }

  @override
  Future<List<String>> loadEntryDates() async =>
      _entries.keys.toList()..sort();

  @override
  Future<String?> loadTheme() async => _theme;

  @override
  Future<void> saveTheme(String name) async => _theme = name;

  // 与 SQLite 实现一致：存 JSON 字符串，保证序列化往返也被测试覆盖。
  @override
  Future<MacroRatio?> loadMacroRatio() async {
    final raw = _macroRatioJson;
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return MacroRatio.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> saveMacroRatio(MacroRatio ratio) async =>
      _macroRatioJson = jsonEncode(ratio.toJson());

  @override
  Future<void> clearMacroRatio() async => _macroRatioJson = null;

  @override
  Future<String?> loadApiKey() async => _apiKey;

  @override
  Future<void> saveApiKey(String key) async => _apiKey = key;

  @override
  Future<List<FavoriteGroup>> loadFavoriteGroups() async =>
      List.of(_favoriteGroups);

  @override
  Future<int> addFavoriteGroup(String name) async {
    _groupSeq++;
    _favoriteGroups.add(FavoriteGroup(id: _groupSeq, name: name));
    return _groupSeq;
  }

  @override
  Future<void> renameFavoriteGroup(int id, String name) async {
    final i = _favoriteGroups.indexWhere((g) => g.id == id);
    if (i != -1) _favoriteGroups[i] = FavoriteGroup(id: id, name: name);
  }

  @override
  Future<void> deleteFavoriteGroup(int id) async {
    _favoriteGroups.removeWhere((g) => g.id == id);
    _favorites.removeWhere((f) => f['group_id'] == id);
  }

  @override
  Future<void> addFavorite(String actionId, int groupId) async {
    final exist = _favorites
        .any((f) => f['action_id'] == actionId && f['group_id'] == groupId);
    if (!exist) _favorites.add({'action_id': actionId, 'group_id': groupId});
  }

  @override
  Future<void> removeFavorite(String actionId) async {
    _favorites.removeWhere((f) => f['action_id'] == actionId);
  }

  @override
  Future<Set<String>> loadFavoriteActionIds() async =>
      _favorites.map((f) => f['action_id']! as String).toSet();

  @override
  Future<List<String>> loadFavoritesInGroup(int groupId) async => _favorites
      .where((f) => f['group_id'] == groupId)
      .map((f) => f['action_id']! as String)
      .toList();
}

/// 降级工厂：数据库不可用时给应用一个能跑的仓库。
AppRepository createMemoryRepository() => InMemoryAppRepository();
