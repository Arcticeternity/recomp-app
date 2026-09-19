import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import 'sqlite_factory.dart';

/// index.html 里定义的启动追踪函数（window.bootTrace）。
/// 用 try/catch 包住调用：追踪本身绝不能影响启动。
@JS('bootTrace')
external void _jsBootTrace(String step);

/// 把启动进度写到 window.__boot，便于在浏览器控制台定位卡在哪一步。
///
/// 这个应用在 runApp() 之前要初始化 WASM + 灌静态库；一旦卡住就是纯白屏，
/// 没有可观测点只能靠猜。
void _trace(String step) {
  debugPrint('[boot] $step');
  try {
    _jsBootTrace(step);
  } catch (_) {
    // 追踪失败无所谓
  }
}

/// 单个静态库初始化的时间预算。超时则向上抛，由调用方降级处理。
///
/// 白屏是比「功能降级」严重得多的故障 —— 至少要让应用进得去。
const _initBudget = Duration(seconds: 15);

/// Web：浏览器没有真实文件系统，把 `.sql` dump 灌进内存 SQLite。
///
/// 内存库由 sqflite_common_ffi_web 落到 IndexedDB，跨会话保留。
/// dump 的生成见 `tools/dump_static_db.py`（每条语句必须单行）。
Future<Database> openStaticDatabase({
  required String dbAsset,
  required String sqlAsset,
}) async {
  _trace('openStaticDatabase:start $sqlAsset');
  try {
    final db = await _build(dbAsset: dbAsset, sqlAsset: sqlAsset)
        .timeout(_initBudget);
    _trace('openStaticDatabase:done $sqlAsset');
    return db;
  } on TimeoutException {
    _trace('openStaticDatabase:TIMEOUT $sqlAsset (${_initBudget.inSeconds}s)');
    rethrow;
  } catch (e) {
    _trace('openStaticDatabase:ERROR $sqlAsset -> $e');
    rethrow;
  }
}

Future<Database> _build({
  required String dbAsset,
  required String sqlAsset,
}) async {
  ensureSqliteFactory();
  _trace('ensureSqliteFactory:done');

  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  _trace('openDatabase:done (inMemory)');

  final watch = Stopwatch()..start();
  final script = await rootBundle.loadString(sqlAsset);
  _trace('loadString:done (${script.length} chars)');

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
  _trace('sql:done ($statements 条, ${watch.elapsedMilliseconds}ms)');

  return db;
}

/// Web 无法从文件路径打开（测试专用入口）。
Future<Database> openFromFile(String path) async {
  throw UnsupportedError('Web 不支持从文件路径打开数据库：$path');
}
