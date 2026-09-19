import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import 'sqlite_factory.dart';

/// Web：浏览器没有真实文件系统，把 `.sql` dump 灌进内存 SQLite。
///
/// 内存库由 sqflite_common_ffi_web 落到 OPFS/IndexedDB，跨会话保留。
/// dump 的生成见 `docs/icon_candidates/tools/`（Python + sqlite3，每条语句单行）。
Future<Database> openStaticDatabase({
  required String dbAsset,
  required String sqlAsset,
}) async {
  ensureSqliteFactory();
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);

  final watch = Stopwatch()..start();
  final script = await rootBundle.loadString(sqlAsset);
  var statements = 0;

  // dump 保证「每条语句占一行」：数据里含 JSON（带分号），
  // 按分号切会切坏，按行切才安全。整体包在一个事务里提交。
  await db.transaction((txn) async {
    for (final raw in script.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('--')) continue;
      await txn.execute(line);
      statements++;
    }
  });

  debugPrint('[staticDb] $sqlAsset 就绪：$statements 条语句，'
      '${watch.elapsedMilliseconds}ms');
  return db;
}

/// Web 无法从文件路径打开（测试专用入口）。
Future<Database> openFromFile(String path) async {
  throw UnsupportedError('Web 不支持从文件路径打开数据库：$path');
}
