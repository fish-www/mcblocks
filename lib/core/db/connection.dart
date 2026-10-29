import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';


/// 桌面端和移动端共用同一套存储布局：
///
/// ```text
/// <app support>/blocks.db
/// <app support>/textures/sha/<first two>/<hash>.webp
/// ```
const String databaseFileName = 'blocks.db';
const String texturesDirName = 'textures';

Future<Directory> appSupportDirectory() => getApplicationSupportDirectory();

Future<String> databasePath() async =>
    p.join((await appSupportDirectory()).path, databaseFileName);

Future<String> texturesPath() async =>
    p.join((await appSupportDirectory()).path, texturesDirName);

/// 打开数据库，首次启动时创建 `blocks.db`。
///
/// 测试里传入 [path] 换掉存储位置。
QueryExecutor openAppDatabase({Future<String> Function()? path}) {
  return driftDatabase(
    name: 'blocks',
    native: DriftNativeOptions(
      databasePath: path ?? databasePath,
      shareAcrossIsolates: true,
    ),
  );
}
