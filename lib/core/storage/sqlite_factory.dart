import 'sqlite_factory_io.dart' if (dart.library.js_interop) 'sqlite_factory_web.dart'
    as impl;

/// 各平台统一暴露 `databaseFactory`（仓库层用，避免直接依赖具体实现包）。
export 'package:sqflite_common_ffi/sqflite_common_ffi.dart' show databaseFactory;

bool _factoryReady = false;

/// 初始化数据库 factory：移动端用 sqflite 原生，桌面/测试用 FFI，Web 用 sqlite3 WASM。
///
/// 幂等，可安全多次调用。
void ensureSqliteFactory() {
  if (_factoryReady) return;
  impl.initFactory();
  _factoryReady = true;
}

/// 可写数据库的存放目录。
///
/// Web 返回空串 = 用内存数据库（浏览器没有真实文件系统，数据由
/// sqflite_common_ffi_web 持久化到 OPFS/IndexedDB）。
Future<String> dbDirectory() => impl.resolveDbDirectory();
