import 'package:drift/drift.dart';

import 'schema.dart';

part 'app_database.g.dart';

/// 数据库结构版本。预发布阶段不做迁移：版本对不上就清空重建，
/// 数据靠重新导入数据包恢复。
const int schemaVersion = 4;

@DriftDatabase(
  tables: [Meta, Blocks, Textures, Categories, Tags, BlockTags, BlockTextures],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      // 预发布阶段不做迁移：结构一变就整库重建，数据靠重新导入。
      await customStatement('PRAGMA foreign_keys = OFF');
      final tables = await customSelect(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      ).get();
      for (final table in tables) {
        await customStatement(
          'DROP TABLE IF EXISTS "${table.read<String>('name')}"',
        );
      }
      await migrator.createAll();
      await customStatement('PRAGMA foreign_keys = ON');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
