import 'package:flutter/foundation.dart';

import 'core/fitness/favorite.dart';
import 'core/fitness/fitness_database.dart';
import 'core/food/daily_log.dart';
import 'core/food/food_entry.dart';
import 'core/food/food_item.dart';
import 'core/food/local_food_database.dart';
import 'core/macro/gender.dart';
import 'core/macro/macro_calculator.dart';
import 'core/macro/macro_ratio.dart';
import 'core/macro/macro_ratio_settings.dart';
import 'core/macro/macro_target.dart';
import 'core/macro/weekly_training.dart';
import 'core/profile/user_profile.dart';
import 'core/profile/weekly_status.dart';
import 'core/profile/weight_record.dart';
import 'core/storage/app_repository.dart';
import 'state/fitness_store.dart';
import 'state/food_log_store.dart';
import 'state/profile_store.dart';

/// 应用状态：组合根，按域拆分为 ProfileStore / FoodLogStore / FitnessStore。
///
/// UI 仍通过 AppState 统一访问（委托给子 store），子 store 的通知会转发给 AppState 监听者。
class AppState extends ChangeNotifier {
  AppState(AppRepository repository, {this.localFoodDb, this.fitnessDb})
      : _profileStore = ProfileStore(repository),
        _foodStore = FoodLogStore(repository),
        _fitnessStore = FitnessStore(repository) {
    _profileStore.addListener(notifyListeners);
    _foodStore.addListener(notifyListeners);
    _fitnessStore.addListener(notifyListeners);
  }

  /// 本地食物成分表（约 1700 种）；测试可传 null。
  final LocalFoodDatabase? localFoodDb;

  /// 本地健身数据（动作库 + 训练计划）；测试可传 null。
  final FitnessDatabase? fitnessDb;

  final ProfileStore _profileStore;
  final FoodLogStore _foodStore;
  final FitnessStore _fitnessStore;

  // ---- 委托 getter ----

  UserProfile? get profile => _profileStore.profile;
  String? get themeName => _profileStore.themeName;
  String? get apiKey => _profileStore.apiKey;

  List<FoodEntry> get entries => _foodStore.entries;

  /// 有饮食记录的日期键集合（用于日历打点）。
  Set<String> get entryDates => _foodStore.entryDates;

  List<FoodItem> get customFoods => _foodStore.customFoods;
  List<WeightRecord> get weightRecords => _foodStore.weightRecords;
  List<WeeklyStatus> get weeklyStatuses => _foodStore.weeklyStatuses;

  List<FavoriteGroup> get favoriteGroups => _fitnessStore.favoriteGroups;

  /// 已收藏的动作 id 集合。
  Set<String> get favoriteIds => _fitnessStore.favoriteIds;

  /// 当前生效的宏量配比状态：自定义值 + 实时推荐值。
  ///
  /// 推荐值每次都按当前档案重算，因此用户改了性别/训练时长后不会用到过期数据。
  MacroRatioSettings get macroRatioSettings {
    final p = profile;
    if (p == null) {
      // 档案缺失（引导阶段）用中性默认档，UI 此时不会展示配比差异。
      return MacroRatioSettings.recommended(
        MacroCalculator().recommendedFor(
          Gender.male,
          WeeklyTraining.twoToThree,
        ),
      );
    }
    final recommended = p.recommendedRatio;
    final custom = _profileStore.customRatio;
    if (custom == null) return MacroRatioSettings.recommended(recommended);
    return MacroRatioSettings.custom(ratio: custom, recommended: recommended);
  }

  /// 每日目标（按生效配比计算；档案缺失时为 0）。
  MacroTarget get dailyTarget {
    final p = profile;
    if (p == null) return const MacroTarget(carbs: 0, protein: 0, fat: 0);
    return MacroCalculator()
        .targetFor(macroRatioSettings.ratio, p.weightKg);
  }

  /// 当天日志（含目标额度与剩余）。
  DailyLog? get todayLog {
    final p = profile;
    if (p == null) return null;
    final log = DailyLog(target: dailyTarget);
    for (final e in entries) {
      log.add(e);
    }
    return log;
  }

  /// 启动时加载全部数据。
  Future<void> init() async {
    await _profileStore.load();
    await _foodStore.load();
    await _fitnessStore.load();
  }

  // ---- 委托方法 ----

  Future<void> saveProfile(UserProfile profile) =>
      _profileStore.saveProfile(profile);
  Future<void> saveTheme(String name) => _profileStore.saveTheme(name);
  Future<void> saveApiKey(String key) => _profileStore.saveApiKey(key);

  /// 保存自定义宏量配比（设置页）。
  Future<void> saveMacroRatio(MacroRatio ratio) =>
      _profileStore.saveMacroRatio(ratio);

  /// 恢复档案推荐配比。
  Future<void> clearMacroRatio() => _profileStore.clearMacroRatio();

  Future<List<FoodEntry>> loadEntriesFor(String key) =>
      _foodStore.loadEntriesFor(key);
  Future<void> addEntry(FoodEntry entry) => _foodStore.addEntry(entry);
  Future<void> removeEntry(FoodEntry entry) => _foodStore.removeEntry(entry);
  Future<void> addCustomFood(FoodItem item) => _foodStore.addCustomFood(item);
  Future<void> deleteCustomFood(String name) =>
      _foodStore.deleteCustomFood(name);
  Future<void> addWeightRecord(WeightRecord record) =>
      _foodStore.addWeightRecord(record);
  Future<void> updateWeightRecord(String oldKey, WeightRecord record) =>
      _foodStore.updateWeightRecord(oldKey, record);
  Future<void> deleteWeightRecord(String key) =>
      _foodStore.deleteWeightRecord(key);
  Future<void> saveWeeklyStatus(WeeklyStatus status) =>
      _foodStore.saveWeeklyStatus(status);

  Future<int> addFavoriteGroup(String name) =>
      _fitnessStore.addFavoriteGroup(name);
  Future<void> renameFavoriteGroup(int id, String name) =>
      _fitnessStore.renameFavoriteGroup(id, name);
  Future<void> deleteFavoriteGroup(int id) =>
      _fitnessStore.deleteFavoriteGroup(id);
  Future<void> addFavorite(String actionId, int groupId) =>
      _fitnessStore.addFavorite(actionId, groupId);
  Future<void> removeFavorite(String actionId) =>
      _fitnessStore.removeFavorite(actionId);
  Future<List<String>> loadFavoritesInGroup(int groupId) =>
      _fitnessStore.loadFavoritesInGroup(groupId);
}
