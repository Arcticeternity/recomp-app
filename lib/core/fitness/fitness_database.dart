import 'dart:convert';

import 'package:sqflite/sqflite.dart' show Database;

import '../storage/static_db_loader.dart';
import 'exercise_filter.dart';

/// 动作步骤/关键点的一条。
class StepItem {
  const StepItem({required this.title, required this.text});

  final String title;
  final String text;

  factory StepItem.fromJson(Map<String, dynamic> j) => StepItem(
        title: (j['title'] ?? '') as String,
        text: (j['text'] ?? '') as String,
      );
}

/// 动作（列表展示用）。
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.body,
    required this.equipment,
    required this.muscles,
  });

  final String id;
  final String name;

  /// 部位（胸/背/肩/腿/核心/手臂等）。
  final String body;

  final List<String> equipment;
  final List<String> muscles;
}

/// 动作详情。
class ExerciseDetail {
  const ExerciseDetail({
    required this.exercise,
    required this.summary,
    required this.steps,
    required this.keyPoints,
    required this.breathing,
    required this.feel,
    required this.variants,
    required this.bvid,
    required this.hasImage,
  });

  final Exercise exercise;
  final String summary;
  final List<StepItem> steps;
  final List<StepItem> keyPoints;
  final String breathing;
  final String feel;
  final List<String> variants;

  /// B站 BV 号（跳转外链用，可能为 null）。
  final String? bvid;

  /// 是否有演示图。
  final bool hasImage;
}

/// 训练计划里的一个动作项。
class TrainingItem {
  const TrainingItem({
    required this.actionId,
    required this.displayName,
    required this.phase,
    required this.dosageText,
    required this.note,
  });

  final String actionId;
  final String displayName;

  /// 热身 / 正式。
  final String phase;

  final String dosageText;
  final String note;
}

/// 训练日。
class TrainingDay {
  const TrainingDay({required this.title, required this.note, required this.items});

  final String title;
  final String note;
  final List<TrainingItem> items;
}

/// 动作在训练计划中的位置。
class ProgramLocation {
  const ProgramLocation({
    required this.programId,
    required this.programTitle,
    required this.dayTitle,
  });

  final String programId;
  final String programTitle;
  final String dayTitle;
}
class TrainingProgram {
  const TrainingProgram({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.days,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<TrainingDay> days;
}

/// 本地健身数据（动作库 + 训练计划，源自谭成义内容整理站）。
class FitnessDatabase {
  FitnessDatabase(this._db);

  final Database _db;

  static Future<FitnessDatabase> openFromAsset() async {
    final db = await openStaticDatabase(
      dbAsset: 'assets/fitness.db',
      sqlAsset: 'assets/fitness.sql',
    );
    return FitnessDatabase(db);
  }

  static Future<FitnessDatabase> openFromFile(String path) async {
    final db = await openStaticDatabaseFromFile(path);
    return FitnessDatabase(db);
  }

  static List<String> _strList(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final l = jsonDecode(json) as List;
      return l.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// 解析变体文字：只取 title/text，过滤 source_refs 等元数据（不露 JSON）。
  static List<String> _variantTexts(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final l = jsonDecode(json) as List;
      return l
          .map((e) {
            if (e is Map) {
              return (e['title'] ?? e['text'] ?? '').toString();
            }
            return e.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 按名称/别名搜索动作。
  Future<List<Exercise>> search(String query) async {
    final q = query.trim();
    final rows = await _db.query(
      'action',
      where: 'name LIKE ? OR aliases LIKE ?',
      whereArgs: ['%$q%', '%$q%'],
      limit: 50,
    );
    return rows.map(_exerciseFromRow).toList();
  }

  /// 全部动作（用于分类浏览）。
  Future<List<Exercise>> listAll() async {
    final rows = await _db.query('action', orderBy: 'name');
    return rows.map(_exerciseFromRow).toList();
  }

  /// 加载全部分类数据（用于筛选联动）。
  Future<List<CategoryData>> loadAllCategories() async {
    final rows = await _db.query('category');
    return rows
        .map((r) => CategoryData(
              actionId: r['action_id'] as String,
              group: (r['group_name'] ?? '') as String,
              regions: _strList(r['region'] as String?),
              equipments: _strList(r['equipment'] as String?),
              pattern: (r['pattern'] ?? '') as String,
            ))
        .toList();
  }

  /// 所有部位（去重）。
  Future<List<String>> listBodies() async {
    final rows = await _db.query('action', columns: ['body'], distinct: true);
    final set = rows.map((r) => r['body'] as String).where((s) => s.isNotEmpty).toSet();
    return set.toList()..sort();
  }

  /// 动作详情。
  Future<ExerciseDetail?> detail(String id) async {
    final aRows = await _db.query('action', where: 'id = ?', whereArgs: [id]);
    if (aRows.isEmpty) return null;
    final ex = _exerciseFromRow(aRows.first);

    final gRows = await _db.query('guide', where: 'action_id = ?', whereArgs: [id]);
    final mRows = await _db.query('media', where: 'action_id = ?', whereArgs: [id]);

    if (gRows.isEmpty) {
      return ExerciseDetail(
        exercise: ex,
        summary: '',
        steps: const [],
        keyPoints: const [],
        breathing: '',
        feel: '',
        variants: const [],
        bvid: null,
        hasImage: mRows.isNotEmpty,
      );
    }
    final g = gRows.first;
    List<StepItem> parseSteps(String? json) {
      if (json == null || json.isEmpty) return [];
      try {
        final l = jsonDecode(json) as List;
        return l
            .map((e) => StepItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }

    return ExerciseDetail(
      exercise: ex,
      summary: (g['summary'] ?? '') as String,
      steps: parseSteps(g['steps'] as String?),
      keyPoints: parseSteps(g['key_points'] as String?),
      breathing: (g['breathing'] ?? '') as String,
      feel: (g['feel'] ?? '') as String,
      variants: _variantTexts(g['variants'] as String?),
      bvid: g['bvid'] as String?,
      hasImage: mRows.isNotEmpty,
    );
  }

  /// 训练计划。
  Future<TrainingProgram?> program(String id) async {
    final rows = await _db.query('program', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    final days = <TrainingDay>[];
    try {
      final dl = jsonDecode(r['days'] as String) as List;
      for (final d in dl) {
        final dm = d as Map<String, dynamic>;
        final items = <TrainingItem>[];
        for (final it in (dm['items'] as List? ?? [])) {
          final im = it as Map<String, dynamic>;
          final dosage = im['dosage'] as Map<String, dynamic>? ?? {};
          items.add(TrainingItem(
            actionId: (im['action_id'] ?? '') as String,
            displayName: (im['display_name'] ?? '') as String,
            phase: (im['phase'] ?? '') as String,
            dosageText: (im['dosage_text'] ??
                '${dosage['sets'] ?? ''}组 ${dosage['reps'] ?? ''}') as String,
            note: (im['note'] ?? '') as String,
          ));
        }
        days.add(TrainingDay(
          title: (dm['title'] ?? '') as String,
          note: (dm['note'] ?? '') as String,
          items: items,
        ));
      }
    } catch (_) {}
    return TrainingProgram(
      id: id,
      title: (r['title'] ?? '') as String,
      subtitle: (r['subtitle'] ?? '') as String,
      days: days,
    );
  }

  Exercise _exerciseFromRow(Map<String, Object?> r) => Exercise(
        id: r['id'] as String,
        name: (r['name'] ?? '') as String,
        body: (r['body'] ?? '') as String,
        equipment: _strList(r['equipment'] as String?),
        muscles: _strList(r['muscles'] as String?),
      );

  /// 查找动作出现在哪些训练计划的哪些天。
  Future<List<ProgramLocation>> findProgramsContaining(String actionId) async {
    final rows = await _db.query('program');
    final result = <ProgramLocation>[];
    for (final r in rows) {
      final days = jsonDecode(r['days'] as String) as List;
      for (final d in days) {
        final dm = d as Map<String, dynamic>;
        for (final it in (dm['items'] as List? ?? [])) {
          final im = it as Map<String, dynamic>;
          if (im['action_id'] == actionId) {
            result.add(ProgramLocation(
              programId: r['id'] as String,
              programTitle: r['title'] as String,
              dayTitle: (dm['title'] ?? '') as String,
            ));
            break;
          }
        }
      }
    }
    return result;
  }

  Future<void> close() => _db.close();
}
