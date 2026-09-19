import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide databaseFactory;

import '../calibration/calibration_types.dart';
import '../fitness/favorite.dart';
import '../food/food_entry.dart';
import '../food/food_item.dart';
import '../food/meal.dart';
import '../macro/gender.dart';
import '../macro/macro_ratio.dart';
import '../macro/weekly_training.dart';
import '../profile/user_profile.dart';
import '../profile/weekly_status.dart';
import '../profile/weight_record.dart';
import 'app_repository.dart';
import 'sqlite_factory.dart';

/// SQLite 持久化实现。移动端原生、桌面/测试 FFI、Web 用 sqlite3 WASM。
class SqliteAppRepository implements AppRepository {
  SqliteAppRepository(this._db);

  final Database _db;

  static const _profileId = 1;

  /// 打开数据库。默认内存库；传 [path] 则持久化到文件。
  static Future<SqliteAppRepository> open({String? path}) async {
    ensureSqliteFactory();
    final db = await databaseFactory.openDatabase(
      path ?? inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return SqliteAppRepository(db);
  }

  /// 打开默认持久化数据库（用户数据目录，跨会话保留）。
  static Future<SqliteAppRepository> openDefault() async {
    ensureSqliteFactory();
    final dir = await dbDirectory();
    // Web 没有文件路径：空目录走内存库（由 ffi_web 落到 OPFS/IndexedDB）
    return open(path: dir.isEmpty ? null : p.join(dir, 'recomp.db'));
  }

  Future<void> close() => _db.close();

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        gender TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        training TEXT NOT NULL,
        height_cm REAL NOT NULL DEFAULT 0,
        age INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE custom_food (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        carbs_per_100g REAL NOT NULL,
        protein_per_100g REAL NOT NULL,
        fat_per_100g REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE food_entry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_key TEXT NOT NULL,
        meal TEXT NOT NULL,
        food_name TEXT NOT NULL,
        weight_grams REAL NOT NULL,
        carbs_per_100g REAL NOT NULL,
        protein_per_100g REAL NOT NULL,
        fat_per_100g REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE weekly_status (
        week_start TEXT PRIMARY KEY,
        desire TEXT NOT NULL,
        sleep TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE weight_record (
        date_key TEXT PRIMARY KEY,
        weight_kg REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ai_food_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        carbs_per_100g REAL NOT NULL,
        protein_per_100g REAL NOT NULL,
        fat_per_100g REAL NOT NULL,
        transferred INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE favorite_group (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE favorite (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_id TEXT NOT NULL,
        group_id INTEGER NOT NULL
      )
    ''');
  }

  /// 迁移：v1→v2 加 settings，v2→v3 加 ai_food_history。
  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldV < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_food_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          carbs_per_100g REAL NOT NULL,
          protein_per_100g REAL NOT NULL,
          fat_per_100g REAL NOT NULL,
          transferred INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldV < 4) {
      await db.execute(
          'ALTER TABLE profile ADD COLUMN height_cm REAL NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE profile ADD COLUMN age INTEGER NOT NULL DEFAULT 0');
    }
    if (oldV < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS favorite_group (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS favorite (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action_id TEXT NOT NULL,
          group_id INTEGER NOT NULL
        )
      ''');
    }
  }

  // ---- 档案 ----

  @override
  Future<UserProfile?> loadProfile() async {
    final rows =
        await _db.query('profile', where: 'id = ?', whereArgs: [_profileId]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return UserProfile(
      gender: Gender.values.byName(r['gender'] as String),
      weightKg: (r['weight_kg'] as num).toDouble(),
      training: WeeklyTraining.values.byName(r['training'] as String),
      heightCm: (r['height_cm'] as num?)?.toDouble() ?? 0,
      age: (r['age'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _db.insert(
      'profile',
      {
        'id': _profileId,
        'gender': profile.gender.name,
        'weight_kg': profile.weightKg,
        'training': profile.training.name,
        'height_cm': profile.heightCm,
        'age': profile.age,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- 自定义食物 ----

  @override
  Future<List<FoodItem>> loadCustomFoods() async {
    final rows = await _db.query('custom_food');
    return rows
        .map((r) => FoodItem(
              name: r['name'] as String,
              carbsPer100g: (r['carbs_per_100g'] as num).toDouble(),
              proteinPer100g: (r['protein_per_100g'] as num).toDouble(),
              fatPer100g: (r['fat_per_100g'] as num).toDouble(),
            ))
        .toList();
  }

  @override
  Future<void> addCustomFood(FoodItem item) async {
    await _db.insert('custom_food', {
      'name': item.name,
      'carbs_per_100g': item.carbsPer100g,
      'protein_per_100g': item.proteinPer100g,
      'fat_per_100g': item.fatPer100g,
    });
  }

  @override
  Future<void> deleteCustomFood(String name) async {
    await _db.delete('custom_food', where: 'name = ?', whereArgs: [name]);
  }

  // ---- 每日录入 ----

  @override
  Future<List<FoodEntry>> loadEntries(String key) async {
    final rows =
        await _db.query('food_entry', where: 'date_key = ?', whereArgs: [key]);
    return rows
        .map((r) => FoodEntry(
              food: FoodItem(
                name: r['food_name'] as String,
                carbsPer100g: (r['carbs_per_100g'] as num).toDouble(),
                proteinPer100g: (r['protein_per_100g'] as num).toDouble(),
                fatPer100g: (r['fat_per_100g'] as num).toDouble(),
              ),
              weightGrams: (r['weight_grams'] as num).toDouble(),
              meal: MealType.values.byName(r['meal'] as String),
            ))
        .toList();
  }

  @override
  Future<void> saveEntries(String key, List<FoodEntry> entries) async {
    await _db.transaction((txn) async {
      await txn.delete('food_entry', where: 'date_key = ?', whereArgs: [key]);
      for (final e in entries) {
        await txn.insert('food_entry', {
          'date_key': key,
          'meal': e.meal.name,
          'food_name': e.food.name,
          'weight_grams': e.weightGrams,
          'carbs_per_100g': e.food.carbsPer100g,
          'protein_per_100g': e.food.proteinPer100g,
          'fat_per_100g': e.food.fatPer100g,
        });
      }
    });
  }

  // ---- 周状态 ----

  @override
  Future<List<WeeklyStatus>> loadWeeklyStatuses() async {
    final rows = await _db.query('weekly_status');
    return rows
        .map((r) => WeeklyStatus(
              weekStart: DateTime.parse(r['week_start'] as String),
              desire: TrainingDesire.values.byName(r['desire'] as String),
              sleep: SleepQuality.values.byName(r['sleep'] as String),
            ))
        .toList();
  }

  @override
  Future<void> saveWeeklyStatus(WeeklyStatus status) async {
    await _db.insert(
      'weekly_status',
      {
        'week_start': dateKey(status.weekStart),
        'desire': status.desire.name,
        'sleep': status.sleep.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- 体重记录 ----

  @override
  Future<List<WeightRecord>> loadWeightRecords() async {
    final rows = await _db.query('weight_record', orderBy: 'date_key ASC');
    return rows
        .map((r) => WeightRecord(
              date: DateTime.parse(r['date_key'] as String),
              weightKg: (r['weight_kg'] as num).toDouble(),
            ))
        .toList();
  }

  @override
  Future<void> addWeightRecord(WeightRecord record) async {
    await _db.insert(
      'weight_record',
      {
        'date_key': dateKey(record.date),
        'weight_kg': record.weightKg,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateWeightRecord(String oldDateKey, WeightRecord record) async {
    await _db.transaction((txn) async {
      await txn.delete('weight_record',
          where: 'date_key = ?', whereArgs: [oldDateKey]);
      await txn.insert(
        'weight_record',
        {
          'date_key': dateKey(record.date),
          'weight_kg': record.weightKg,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> deleteWeightRecord(String key) async {
    await _db.delete('weight_record', where: 'date_key = ?', whereArgs: [key]);
  }

  // ---- 日历 / 主题 ----

  @override
  Future<List<String>> loadEntryDates() async {
    final rows = await _db.query('food_entry', columns: ['date_key']);
    final keys = rows.map((r) => r['date_key'] as String).toSet().toList()
      ..sort();
    return keys;
  }

  @override
  Future<String?> loadTheme() async {
    final rows = await _db
        .query('settings', where: 'key = ?', whereArgs: ['theme']);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  @override
  Future<void> saveTheme(String name) async {
    await _db.insert(
      'settings',
      {'key': 'theme', 'value': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- API Key ----

  @override
  Future<String?> loadApiKey() async {
    final rows = await _db
        .query('settings', where: 'key = ?', whereArgs: ['glm_api_key']);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  @override
  Future<void> saveApiKey(String key) async {
    await _db.insert(
      'settings',
      {'key': 'glm_api_key', 'value': key},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- 自定义宏量配比 ----

  /// settings 表的键名。
  static const _macroRatioKey = 'macro_ratio';

  @override
  Future<MacroRatio?> loadMacroRatio() async {
    final raw = await _readSetting(_macroRatioKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return MacroRatio.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      // 数据损坏时静默回退到推荐值，不能让用户卡在崩坏的设置里。
      return null;
    }
  }

  @override
  Future<void> saveMacroRatio(MacroRatio ratio) =>
      _writeSetting(_macroRatioKey, jsonEncode(ratio.toJson()));

  @override
  Future<void> clearMacroRatio() async {
    await _db.delete('settings',
        where: 'key = ?', whereArgs: [_macroRatioKey]);
  }

  Future<String?> _readSetting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> _writeSetting(String key, String value) => _db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  // ---- 收藏分组 ----

  @override
  Future<List<FavoriteGroup>> loadFavoriteGroups() async {
    final rows = await _db.query('favorite_group', orderBy: 'id ASC');
    return rows
        .map((r) =>
            FavoriteGroup(id: r['id'] as int, name: r['name'] as String))
        .toList();
  }

  @override
  Future<int> addFavoriteGroup(String name) async {
    return await _db.insert('favorite_group', {'name': name});
  }

  @override
  Future<void> renameFavoriteGroup(int id, String name) async {
    await _db.update('favorite_group', {'name': name},
        where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteFavoriteGroup(int id) async {
    await _db.transaction((txn) async {
      await txn.delete('favorite', where: 'group_id = ?', whereArgs: [id]);
      await txn.delete('favorite_group', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<void> addFavorite(String actionId, int groupId) async {
    final exist = await _db.query('favorite',
        where: 'action_id = ? AND group_id = ?',
        whereArgs: [actionId, groupId]);
    if (exist.isEmpty) {
      await _db.insert('favorite', {'action_id': actionId, 'group_id': groupId});
    }
  }

  @override
  Future<void> removeFavorite(String actionId) async {
    await _db.delete('favorite', where: 'action_id = ?', whereArgs: [actionId]);
  }

  @override
  Future<Set<String>> loadFavoriteActionIds() async {
    final rows =
        await _db.query('favorite', columns: ['action_id'], distinct: true);
    return rows.map((r) => r['action_id'] as String).toSet();
  }

  @override
  Future<List<String>> loadFavoritesInGroup(int groupId) async {
    final rows = await _db.query('favorite',
        columns: ['action_id'],
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'id ASC');
    return rows.map((r) => r['action_id'] as String).toList();
  }
}
