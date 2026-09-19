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

/// 数据库初始化的时间预算（仅 Web 生效）。
///
/// Web 上 sqlite3 WASM 可能因浏览器限制卡住且不报错 —— 那种情况下应用
/// **永远到不了 runApp()**，表现就是纯白屏。给个上限，超时走降级路径：
/// 宁可功能降级，也不能让用户对着白屏。
const dbInitTimeout = Duration(seconds: 8);

/// 给数据库初始化加上限。IO 平台不加限制（本地 SQLite 从不卡住）。
Future<T> withDbInitTimeout<T>(Future<T> future) =>
    impl.withInitTimeout(future);
