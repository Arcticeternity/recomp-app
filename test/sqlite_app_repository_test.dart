import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:recomp_app/core/calibration/calibration_types.dart';
import 'package:recomp_app/core/food/food_entry.dart';
import 'package:recomp_app/core/food/food_item.dart';
import 'package:recomp_app/core/food/meal.dart';
import 'package:recomp_app/core/macro/gender.dart';
import 'package:recomp_app/core/macro/macro_ratio.dart';
import 'package:recomp_app/core/macro/weekly_training.dart';
import 'package:recomp_app/core/profile/user_profile.dart';
import 'package:recomp_app/core/profile/weekly_status.dart';
import 'package:recomp_app/core/profile/weight_record.dart';
import 'package:recomp_app/core/storage/sqlite_app_repository.dart';

void main() {
  late SqliteAppRepository repo;

  setUp(() async {
    repo = await SqliteAppRepository.open(); // 内存库
  });

  tearDown(() async {
    await repo.close();
  });

  group('用户档案', () {
    test('空库返回 null', () async {
      expect(await repo.loadProfile(), isNull);
    });

    test('保存后可读回', () async {
      const profile = UserProfile(
        gender: Gender.male,
        weightKg: 85,
        training: WeeklyTraining.twoToThree,
      );
      await repo.saveProfile(profile);
      final loaded = await repo.loadProfile();
      expect(loaded, isNotNull);
      expect(loaded!.gender, Gender.male);
      expect(loaded.weightKg, 85);
      expect(loaded.training, WeeklyTraining.twoToThree);
    });

    test('覆盖保存（体重更新）', () async {
      await repo.saveProfile(const UserProfile(
          gender: Gender.male, weightKg: 85, training: WeeklyTraining.twoToThree));
      await repo.saveProfile(const UserProfile(
          gender: Gender.male, weightKg: 83, training: WeeklyTraining.twoToThree));
      final loaded = await repo.loadProfile();
      expect(loaded!.weightKg, 83);
    });
  });

  group('自定义食物', () {
    test('添加后可读回', () async {
      await repo.addCustomFood(const FoodItem(
          name: '蛋白粉', carbsPer100g: 8, proteinPer100g: 80, fatPer100g: 5));
      final foods = await repo.loadCustomFoods();
      expect(foods.length, 1);
      expect(foods.first.name, '蛋白粉');
      expect(foods.first.proteinPer100g, 80);
    });

    test('空库返回空列表', () async {
      expect(await repo.loadCustomFoods(), isEmpty);
    });

    test('删除自定义食物', () async {
      await repo.addCustomFood(const FoodItem(
          name: '蛋白粉', carbsPer100g: 8, proteinPer100g: 80, fatPer100g: 5));
      await repo.addCustomFood(const FoodItem(
          name: '螺旋藻', carbsPer100g: 5, proteinPer100g: 60, fatPer100g: 3));
      expect((await repo.loadCustomFoods()).length, 2);

      await repo.deleteCustomFood('蛋白粉');
      final foods = await repo.loadCustomFoods();
      expect(foods.length, 1);
      expect(foods.first.name, '螺旋藻');
    });
  });

  group('每日录入', () {
    const rice = FoodItem(
        name: '米饭(熟)', carbsPer100g: 26, proteinPer100g: 2.6, fatPer100g: 0.3);
    const chicken = FoodItem(
        name: '鸡胸肉', carbsPer100g: 0, proteinPer100g: 24, fatPer100g: 2);

    test('保存后可读回（含餐别/食物/重量）', () async {
      await repo.saveEntries('2026-09-12', [
        FoodEntry(food: rice, weightGrams: 150, meal: MealType.lunch),
      ]);
      final loaded = await repo.loadEntries('2026-09-12');
      expect(loaded.length, 1);
      expect(loaded.first.food.name, '米饭(熟)');
      expect(loaded.first.weightGrams, 150);
      expect(loaded.first.meal, MealType.lunch);
    });

    test('再次保存覆盖当天', () async {
      await repo.saveEntries('2026-09-12', [
        FoodEntry(food: rice, weightGrams: 150, meal: MealType.lunch),
      ]);
      await repo.saveEntries('2026-09-12', [
        FoodEntry(food: chicken, weightGrams: 120, meal: MealType.lunch),
      ]);
      final loaded = await repo.loadEntries('2026-09-12');
      expect(loaded.length, 1);
      expect(loaded.first.food.name, '鸡胸肉');
    });

    test('不同日期互不影响', () async {
      await repo.saveEntries('2026-09-12', [
        FoodEntry(food: rice, weightGrams: 150, meal: MealType.lunch),
      ]);
      await repo.saveEntries('2026-09-13', [
        FoodEntry(food: chicken, weightGrams: 120, meal: MealType.lunch),
      ]);
      expect((await repo.loadEntries('2026-09-12')).length, 1);
      expect((await repo.loadEntries('2026-09-13')).length, 1);
      expect(await repo.loadEntries('2026-09-14'), isEmpty);
    });
  });

  group('周状态', () {
    test('保存后可读回', () async {
      await repo.saveWeeklyStatus(WeeklyStatus(
          weekStart: DateTime(2026, 9, 1),
          desire: TrainingDesire.high,
          sleep: SleepQuality.good));
      final list = await repo.loadWeeklyStatuses();
      expect(list.length, 1);
      expect(list.first.desire, TrainingDesire.high);
    });

    test('覆盖同周', () async {
      await repo.saveWeeklyStatus(WeeklyStatus(
          weekStart: DateTime(2026, 9, 1),
          desire: TrainingDesire.high,
          sleep: SleepQuality.good));
      await repo.saveWeeklyStatus(WeeklyStatus(
          weekStart: DateTime(2026, 9, 1),
          desire: TrainingDesire.low,
          sleep: SleepQuality.poor));
      final list = await repo.loadWeeklyStatuses();
      expect(list.length, 1);
      expect(list.first.desire, TrainingDesire.low);
    });
  });

  group('体重记录', () {
    test('按日期升序返回', () async {
      await repo.addWeightRecord(
          WeightRecord(date: DateTime(2026, 9, 10), weightKg: 85));
      await repo.addWeightRecord(
          WeightRecord(date: DateTime(2026, 9, 1), weightKg: 86));
      final list = await repo.loadWeightRecords();
      expect(list.length, 2);
      expect(list.first.weightKg, 86); // 9月1日在前
      expect(list.last.weightKg, 85);
    });

    test('覆盖同日期', () async {
      await repo.addWeightRecord(
          WeightRecord(date: DateTime(2026, 9, 1), weightKg: 86));
      await repo.addWeightRecord(
          WeightRecord(date: DateTime(2026, 9, 1), weightKg: 85.5));
      final list = await repo.loadWeightRecords();
      expect(list.length, 1);
      expect(list.first.weightKg, 85.5);
    });

    test('修改体重记录（改值）', () async {
      await repo.addWeightRecord(
          WeightRecord(date: DateTime(2026, 9, 1), weightKg: 86));
      await repo.updateWeightRecord(
          '2026-09-01',
          WeightRecord(date: DateTime(2026, 9, 1), weightKg: 85));
      final list = await repo.loadWeightRecords();
      expect(list.length, 1);
      expect(list.first.weightKg, 85);
    });

    test('修改体重记录（改日期）', () async {
      await repo.addWeightRecord(
          WeightRecord(date: DateTime(2026, 9, 1), weightKg: 86));
      await repo.updateWeightRecord(
          '2026-09-01',
          WeightRecord(date: DateTime(2026, 9, 5), weightKg: 85.5));
      final list = await repo.loadWeightRecords();
      expect(list.length, 1);
      expect(list.first.date.day, 5);
      expect(list.first.weightKg, 85.5);
    });

    test('删除体重记录', () async {
      await repo.addWeightRecord(
          WeightRecord(date: DateTime(2026, 9, 1), weightKg: 86));
      await repo.addWeightRecord(
          WeightRecord(date: DateTime(2026, 9, 10), weightKg: 85));
      await repo.deleteWeightRecord('2026-09-01');
      final list = await repo.loadWeightRecords();
      expect(list.length, 1);
      expect(list.first.date.day, 10);
    });
  });

  group('持久化（文件库）', () {
    test('关闭重开后数据仍在', () async {
      final tmp = await Directory.systemTemp.createTemp('recomp_test');
      addTearDown(() => tmp.delete(recursive: true));
      final dbPath = p.join(tmp.path, 'test.db');

      var fileRepo = await SqliteAppRepository.open(path: dbPath);
      await fileRepo.saveProfile(const UserProfile(
          gender: Gender.male, weightKg: 85, training: WeeklyTraining.twoToThree));
      await fileRepo.addWeightRecord(
          WeightRecord(date: DateTime(2026, 9, 1), weightKg: 85));
      await fileRepo.close();

      fileRepo = await SqliteAppRepository.open(path: dbPath);
      final profile = await fileRepo.loadProfile();
      expect(profile!.weightKg, 85);
      final records = await fileRepo.loadWeightRecords();
      expect(records.length, 1);
      await fileRepo.close();
    });
  });

  group('日历与主题', () {
    test('loadEntryDates 返回有记录的日期', () async {
      await repo.saveEntries('2026-09-12', [
        const FoodEntry(
          food: FoodItem(
              name: '米饭(熟)',
              carbsPer100g: 26,
              proteinPer100g: 2.6,
              fatPer100g: 0.3),
          weightGrams: 150,
          meal: MealType.lunch,
        ),
      ]);
      await repo.saveEntries('2026-09-13', [
        const FoodEntry(
          food: FoodItem(
              name: '鸡蛋', carbsPer100g: 1, proteinPer100g: 13, fatPer100g: 10),
          weightGrams: 100,
          meal: MealType.breakfast,
        ),
      ]);
      final dates = await repo.loadEntryDates();
      expect(dates, contains('2026-09-12'));
      expect(dates, contains('2026-09-13'));
      expect(dates.length, 2);
    });

    test('主题默认 null，保存后可读回', () async {
      expect(await repo.loadTheme(), isNull);
      await repo.saveTheme('ocean');
      expect(await repo.loadTheme(), 'ocean');
    });
  });

  group('API Key', () {
    test('默认 null，保存后可读回', () async {
      expect(await repo.loadApiKey(), isNull);
      await repo.saveApiKey('test-key-123');
      expect(await repo.loadApiKey(), 'test-key-123');
    });
  });

  group('自定义宏量配比', () {
    test('默认 null，保存后可读回', () async {
      expect(await repo.loadMacroRatio(), isNull);

      await repo.saveMacroRatio(
          const MacroRatio(carbsPerKg: 2.8, proteinPerKg: 1.9, fatPerKg: 0.7));

      final loaded = await repo.loadMacroRatio();
      expect(loaded, isNotNull);
      expect(loaded!.carbsPerKg, 2.8);
      expect(loaded.proteinPerKg, 1.9);
      expect(loaded.fatPerKg, 0.7);
    });

    test('覆盖保存取最新值', () async {
      await repo.saveMacroRatio(
          const MacroRatio(carbsPerKg: 2.0, proteinPerKg: 1.5, fatPerKg: 0.8));
      await repo.saveMacroRatio(
          const MacroRatio(carbsPerKg: 3.5, proteinPerKg: 1.8, fatPerKg: 1.0));

      final loaded = await repo.loadMacroRatio();
      expect(loaded!.carbsPerKg, 3.5);
    });

    test('清除后回到 null（恢复推荐值）', () async {
      await repo.saveMacroRatio(
          const MacroRatio(carbsPerKg: 2.0, proteinPerKg: 1.5, fatPerKg: 0.8));
      await repo.clearMacroRatio();
      expect(await repo.loadMacroRatio(), isNull);
    });

    test('数据损坏时返回 null 而非抛出', () async {
      // 往真实库里直写脏值：必须命中 loadMacroRatio 读取的那个 key，
      // 否则断言会因为「本来就读不到」而假通过。
      final tmpDir = await Directory.systemTemp.createTemp('recomp_ratio_test');
      final path = p.join(tmpDir.path, 'corrupt.db');
      final repo = await SqliteAppRepository.open(path: path);
      addTearDown(() async {
        await repo.close();
        await tmpDir.delete(recursive: true);
      });

      final db = await databaseFactory.openDatabase(path);
      addTearDown(db.close);

      Future<void> writeRaw(String value) => db.insert(
            'settings',
            {'key': 'macro_ratio', 'value': value},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

      await writeRaw('{不是合法 JSON}');
      expect(await repo.loadMacroRatio(), isNull, reason: '非 JSON 应吞掉并回退');

      await writeRaw('{"carbsPerKg":2.2}');
      expect(await repo.loadMacroRatio(), isNull, reason: '缺字段应回退');

      await writeRaw('{"carbsPerKg":-1,"proteinPerKg":1.6,"fatPerKg":0.9}');
      expect(await repo.loadMacroRatio(), isNull, reason: '非正数属于非法配比');

      await writeRaw('{"carbsPerKg":2.4,"proteinPerKg":1.7,"fatPerKg":0.9}');
      final ok = await repo.loadMacroRatio();
      expect(ok!.carbsPerKg, 2.4, reason: '同一 key 上的合法值必须能读回');
    });
  });

  group('收藏分组', () {
    test('分组增改删 + 收藏', () async {
      final gid = await repo.addFavoriteGroup('胸日');
      expect(gid, greaterThan(0));

      await repo.addFavorite('a1', gid);
      await repo.addFavorite('a2', gid);
      await repo.addFavorite('a1', gid); // 重复收藏不重复插入
      expect(await repo.loadFavoriteActionIds(), {'a1', 'a2'});
      expect(await repo.loadFavoritesInGroup(gid), ['a1', 'a2']);

      await repo.renameFavoriteGroup(gid, '推日');
      final groups = await repo.loadFavoriteGroups();
      expect(groups.first.name, '推日');

      await repo.removeFavorite('a1');
      expect(await repo.loadFavoriteActionIds(), {'a2'});

      await repo.deleteFavoriteGroup(gid);
      expect(await repo.loadFavoriteGroups(), isEmpty);
      expect(await repo.loadFavoriteActionIds(), isEmpty);
    });
  });
}
