import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'sqlite_factory.dart';

/// 移动/桌面：把 asset 里的 .db 复制到可写目录再打开。
///
/// 每次启动都覆盖：只读数据包，避免旧版本（结构不同）残留导致查询失败。
Future<Database> openStaticDatabase({
  required String dbAsset,
  required String sqlAsset,
}) async {
  ensureSqliteFactory();
  final dir = await dbDirectory();
  final target = p.join(dir, p.basename(dbAsset));
  final data = await rootBundle.load(dbAsset);
  await File(target).writeAsBytes(data.buffer.asUint8List(), flush: true);
  return databaseFactory.openDatabase(target);
}

Future<Database> openFromFile(String path) async {
  ensureSqliteFactory();
  final abs = p.isAbsolute(path) ? path : p.join(Directory.current.path, path);
  return databaseFactory.openDatabase(abs);
}
