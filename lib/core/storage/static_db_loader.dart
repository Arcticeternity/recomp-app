import 'package:sqflite/sqflite.dart' show Database;

import 'static_db_loader_io.dart'
    if (dart.library.js_interop) 'static_db_loader_web.dart' as impl;

/// 打开打包在 asset 里的**只读**静态库（食物成分表 / 健身数据）。
///
/// 两个平台的取数方式不同，但对调用方是一件事：
/// - 移动/桌面：把 `.db` 复制到可写目录后用 sqflite 打开（原路径，行为不变）
/// - Web：浏览器没有真实文件系统，改为把 `.sql` dump 灌进内存 SQLite
///   （内存库由 ffi_web 持久化到 OPFS/IndexedDB）
///
/// [dbAsset] 形如 `assets/fitness.db`；[sqlAsset] 是对应的 dump。
Future<Database> openStaticDatabase({
  required String dbAsset,
  required String sqlAsset,
}) =>
    impl.openStaticDatabase(dbAsset: dbAsset, sqlAsset: sqlAsset);

/// 从真实文件打开（测试用）。Web 上不支持。
Future<Database> openStaticDatabaseFromFile(String path) =>
    impl.openFromFile(path);
