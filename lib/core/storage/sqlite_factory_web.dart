import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_common_ffi.dart'
    show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWebNoWebWorker;

/// Web：sqlite3 WASM + IndexedDB 虚拟文件系统，**不用 SharedWorker**。
///
/// 为什么不用默认的 [databaseFactoryFfiWeb]：它走 SharedWorker，
/// 而 SharedWorker 路径需要页面跨域隔离（COOP/COEP 响应头）。
/// NoWebWorker 模式直接在页面里 loadFromUrl + IndexedDbFileSystem，
/// **不依赖 SharedArrayBuffer**，因此可以部署在 GitHub Pages
/// / 普通静态托管这类无法自定义响应头的环境上。
///
/// 只需要 `web/sqlite3.wasm` 一个资源（不再需要 sqflite_sw.js）。
void initFactory() {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}

/// 空串 = 内存数据库。持久化由 ffi_web 落到 IndexedDB，
/// 不需要也不存在真实目录。
Future<String> resolveDbDirectory() async => '';

/// Web 上数据库初始化可能卡住且不报错（浏览器限制，常见于移动端），
/// 必须有上限，否则 main() 永远到不了 runApp()，表现就是白屏。
Future<T> withInitTimeout<T>(Future<T> future) =>
    future.timeout(const Duration(seconds: 8));
