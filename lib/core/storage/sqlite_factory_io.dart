import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show
        databaseFactory,
        databaseFactoryFfi,
        getDatabasesPath,
        sqfliteFfiInit;

/// 移动端用 sqflite 原生实现；桌面/测试用 FFI 覆盖。
void initFactory() {
  if (!Platform.isAndroid && !Platform.isIOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

/// 可写数据库目录（Android/iOS/桌面均为 getDatabasesPath）。
Future<String> resolveDbDirectory() => getDatabasesPath();
