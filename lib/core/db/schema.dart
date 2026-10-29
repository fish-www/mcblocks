import 'package:drift/drift.dart';

/// schema 由本 app 独占。Python 导入器只产出 `.mcblocks` 数据包，
/// 由 repository 层读取。
///
/// 表名用单数 snake_case，方便直接读原生 SQL。

class Meta extends Table {
  @override
  String get tableName => 'meta';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class Textures extends Table {
  @override
  String get tableName => 'texture';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get hash => text().unique()();
  TextColumn get srcName => text().nullable()();
  TextColumn get relPath => text()();
  IntColumn get width => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@TableIndex(name: 'idx_block_variant_of', columns: {#variantOf})
class Blocks extends Table {
  @override
  String get tableName => 'block';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().unique()();
  TextColumn get name => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get colorHex => text().nullable()();
  IntColumn get variantOf =>
      integer().nullable().references(Blocks, #id)();
  TextColumn get nameEn => text().nullable()();
  TextColumn get nameZh => text().nullable()();
  /// 展示图标：完整方块用材质贴图，非完整方块用 item 图标或派生图。
  @ReferenceName('iconBlocks')
  IntColumn get iconId => integer().nullable().references(Textures, #id)();
  BoolColumn get reviewed => boolean().withDefault(const Constant(false))();
  TextColumn get extra => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Categories extends Table {
  @override
  String get tableName => 'category';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().unique()();
  TextColumn get name => text()();
  BoolColumn get single => boolean().withDefault(const Constant(false))();
  BoolColumn get ordered => boolean().withDefault(const Constant(false))();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  TextColumn get extra => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Tags extends Table {
  @override
  String get tableName => 'tag';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get note => text().nullable()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  TextColumn get extra => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {categoryId, code},
  ];
}

@TableIndex(name: 'idx_block_texture_texture', columns: {#textureId})
class BlockTextures extends Table {
  @override
  String get tableName => 'block_texture';

  IntColumn get blockId => integer().references(Blocks, #id)();
  TextColumn get key => text()();
  IntColumn get textureId => integer().references(Textures, #id)();

  /// 展示顺序，小的在前。
  IntColumn get sort => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {blockId, key};
}

@TableIndex(name: 'idx_block_tag_tag', columns: {#tagId})
class BlockTags extends Table {
  @override
  String get tableName => 'block_tag';

  IntColumn get blockId => integer().references(Blocks, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();
  TextColumn get source => text().withDefault(const Constant('user'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {blockId, tagId};
}
