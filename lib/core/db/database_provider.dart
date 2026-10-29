import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';
import 'connection.dart';

part 'database_provider.g.dart';

/// 数据库必须常驻：drift 的连接跑在后台 isolate 里，
/// 一旦 provider 被自动回收，连接关闭，正在进行的 import 会直接失败。
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase(openAppDatabase());
  ref.onDispose(database.close);
  return database;
}

/// 贴图根目录。UI 拼 `sha/<hash 前两位>/<hash>.webp` 读文件。
@riverpod
Future<String> texturesRoot(Ref ref) => texturesPath();
