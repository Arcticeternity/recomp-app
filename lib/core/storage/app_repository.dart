import '../fitness/favorite.dart';
import '../food/food_entry.dart';
import '../food/food_item.dart';
import '../macro/macro_ratio.dart';
import '../profile/user_profile.dart';
import '../profile/weekly_status.dart';
import '../profile/weight_record.dart';

/// 日期键格式：YYYY-MM-DD。
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// 数据持久化仓库接口：隔离存储实现（SQLite / JSON 等可替换）。
///
/// 只存「纯数据」，带逻辑的对象（DailyLog / StatusTracker）由上层组装。
abstract class AppRepository {
  /// 用户档案（单条）。
  Future<UserProfile?> loadProfile();
  Future<void> saveProfile(UserProfile profile);

  /// 自定义食物。
  Future<List<FoodItem>> loadCustomFoods();
  Future<void> addCustomFood(FoodItem item);
  Future<void> deleteCustomFood(String name);

  /// 某天的食物录入（整体替换）。
  Future<List<FoodEntry>> loadEntries(String dateKey);
  Future<void> saveEntries(String dateKey, List<FoodEntry> entries);

  /// 周状态。
  Future<List<WeeklyStatus>> loadWeeklyStatuses();
  Future<void> saveWeeklyStatus(WeeklyStatus status);

  /// 体重记录。
  Future<List<WeightRecord>> loadWeightRecords();
  Future<void> addWeightRecord(WeightRecord record);
  Future<void> updateWeightRecord(String oldDateKey, WeightRecord record);
  Future<void> deleteWeightRecord(String key);

  /// 有饮食记录的日期键列表（去重，用于日历打点）。
  Future<List<String>> loadEntryDates();

  /// 当前主题名；未设置时返回 null。
  Future<String?> loadTheme();
  Future<void> saveTheme(String name);

  /// 用户自定义的宏量配比；未设置或数据损坏时返回 null（上层回退到推荐值）。
  ///
  /// 只存用户设定的配比本身：推荐值随档案变化，不入库。
  Future<MacroRatio?> loadMacroRatio();
  Future<void> saveMacroRatio(MacroRatio ratio);

  /// 清除自定义配比（恢复推荐值）。
  Future<void> clearMacroRatio();

  /// 智谱 API Key（设置页配置）。
  Future<String?> loadApiKey();
  Future<void> saveApiKey(String key);

  /// 收藏分组。
  Future<List<FavoriteGroup>> loadFavoriteGroups();
  Future<int> addFavoriteGroup(String name);
  Future<void> renameFavoriteGroup(int id, String name);
  Future<void> deleteFavoriteGroup(int id);

  /// 收藏动作。
  Future<void> addFavorite(String actionId, int groupId);
  Future<void> removeFavorite(String actionId);
  Future<Set<String>> loadFavoriteActionIds();
  Future<List<String>> loadFavoritesInGroup(int groupId);
}
