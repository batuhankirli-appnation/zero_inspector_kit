import 'dart:io';

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

/// SQLite 后端统一入口 / Unified SQLite backend entry
///
/// - Android / iOS / macOS：官方 `sqflite`
/// - OpenHarmony：`sqflite_sqlcipher`（sqflite 官方版没有 ohos 原生实现）
///
/// 两者都基于 `sqflite_common`，`Database` 与回调类型完全一致，因此切换对上层透明。
/// sqflite_sqlcipher 在**不传 password** 时就是明文 SQLite：Dart 侧 `password == null`
/// 时不会把该参数发到原生，原生 `encrypt = password != null && length > 0` 即为 false，
/// 所以能正常打开用户已有的普通（未加密）数据库。
/// Both packages are based on `sqflite_common`, so `Database` and the callback types are
/// identical and the switch is transparent to callers. sqflite_sqlcipher behaves as plain
/// SQLite when no password is given: Dart omits the parameter when it is null and the native
/// side uses `encrypt = password != null && length > 0`, so existing unencrypted databases
/// open normally.
class SqliteBackend {
  SqliteBackend._();

  /// 是否为 OpenHarmony 平台 / Whether running on OpenHarmony
  ///
  /// 不用 `Platform.isOhos`（只存在于 Flutter OHOS SDK，会让标准 SDK 编译失败）。
  /// Do not use `Platform.isOhos` (OHOS SDK only; breaks standard SDK builds).
  static bool get isOhos => Platform.operatingSystem == 'ohos';

  /// 获取数据库默认目录 / Get the default databases directory
  static Future<String> getDatabasesPath() =>
      isOhos ? sqlcipher.getDatabasesPath() : sqflite.getDatabasesPath();

  /// 打开数据库 / Open a database
  ///
  /// 注意：不传 password，保持明文 SQLite（可读写用户已有的普通数据库）。
  /// Note: no password is passed, keeping plain SQLite (read/write for existing databases).
  static Future<sqflite.Database> openDatabase(
    String path, {
    int? version,
    sqflite.OnDatabaseCreateFn? onCreate,
    sqflite.OnDatabaseVersionChangeFn? onUpgrade,
    sqflite.OnDatabaseVersionChangeFn? onDowngrade,
    sqflite.OnDatabaseConfigureFn? onConfigure,
    sqflite.OnDatabaseOpenFn? onOpen,
    bool readOnly = false,
    bool singleInstance = true,
  }) {
    if (isOhos) {
      return sqlcipher.openDatabase(
        path,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onDowngrade: onDowngrade,
        onConfigure: onConfigure,
        onOpen: onOpen,
        readOnly: readOnly,
        singleInstance: singleInstance,
      );
    }
    return sqflite.openDatabase(
      path,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onDowngrade: onDowngrade,
      onConfigure: onConfigure,
      onOpen: onOpen,
      readOnly: readOnly,
      singleInstance: singleInstance,
    );
  }

  /// 取结果集第一行第一列的整数值 / Read the int value of the first row/column
  static int? firstIntValue(List<Map<String, Object?>> list) => isOhos
      ? sqlcipher.Sqflite.firstIntValue(list)
      : sqflite.Sqflite.firstIntValue(list);
}
