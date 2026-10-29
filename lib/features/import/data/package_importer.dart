import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/connection.dart';
import '../../../core/db/database_provider.dart';
import '../../blocks/domain/tag_source.dart';
import '../domain/package_block.dart';
import '../domain/import_report.dart';
import '../domain/package_manifest.dart';
import '../domain/parsed_package.dart';

part 'package_importer.g.dart';

@Riverpod(keepAlive: true)
Future<PackageImporter> packageImporter(Ref ref) async => PackageImporter(
  ref.watch(appDatabaseProvider),
  texturesDirectory: Directory(await texturesPath()),
);

/// 把已解析的数据包写进数据库和贴图目录。
///
/// 语义：
/// - `merge`：按 code 增量写入；`reviewed=1` 的方块名字和贴图不动；
///   已有标签不删；词表缺什么补什么，不覆盖已改过的名字。
/// - `rebuild`：先清空方块、标签、词表、贴图记录，再整体写入。
/// - 写数据库在一个事务里，失败整体回滚；贴图文件先落盘，
///   内容寻址，孤儿文件不影响正确性。
final class PackageImporter {
  PackageImporter(this._db, {required this.texturesDirectory});

  final AppDatabase _db;
  final Directory texturesDirectory;

  Future<ImportReport> import(
    ParsedPackage package, {
    ImportMode mode = ImportMode.merge,
    void Function(ImportProgress progress)? onProgress,
  }) async {
    final report = ImportReport(package.problems);
    final now = DateTime.now().toUtc();

    await _writeTextureFiles(package, report, onProgress);

    await _db.transaction(() async {
      if (mode == ImportMode.rebuild) await _clear();

      final categoryIds = await _upsertCategories(package.manifest, now);
      final tagLookup = await _upsertTags(package.manifest, categoryIds, now);
      final textureIds = await _upsertTextures(package, now);
      final (blockIds, inserted) = await _upsertBlocks(
        package,
        textureIds,
        now,
        report,
        onProgress,
      );

      await _breakCycles(report);
      await _linkTags(package, blockIds, inserted, tagLookup, now, report);
    });

    await _writeMeta(package.manifest, now);
    return report;
  }

  Future<void> _writeTextureFiles(
    ParsedPackage package,
    ImportReport report,
    void Function(ImportProgress progress)? onProgress,
  ) async {
    final total = package.textures.length;
    var done = 0;

    for (final entry in package.textures.entries) {
      final file = _textureFile(entry.key);
      if (await file.exists()) {
        report.texturesSkipped++;
      } else {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.value, flush: true);
        report.texturesWritten++;
      }
      done++;
      if (done % 50 == 0 || done == total) {
        onProgress?.call(ImportProgress('贴图', done, total));
      }
    }
  }

  File _textureFile(String hash) => File(
    p.join(texturesDirectory.path, 'sha', hash.substring(0, 2), '$hash.webp'),
  );

  Future<void> _clear() async {
    await _db.delete(_db.blockTextures).go();
    await _db.delete(_db.blockTags).go();
    await _db.delete(_db.blocks).go();
    await _db.delete(_db.tags).go();
    await _db.delete(_db.categories).go();
    await _db.delete(_db.textures).go();
  }

  Future<Map<String, int>> _upsertCategories(
    PackageManifest manifest,
    DateTime now,
  ) async {
    final ids = <String, int>{
      for (final row in await _db.select(_db.categories).get()) row.code: row.id,
    };

    for (final category in manifest.categories) {
      if (ids.containsKey(category.code)) continue;
      ids[category.code] = await _db
          .into(_db.categories)
          .insert(
            CategoriesCompanion.insert(
              code: category.code,
              name: category.name,
              single: Value(category.single),
              ordered: Value(category.ordered),
              sort: Value(category.sort),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    return ids;
  }

  Future<_TagLookup> _upsertTags(
    PackageManifest manifest,
    Map<String, int> categoryIds,
    DateTime now,
  ) async {
    final existing = await _db.select(_db.tags).get();
    final categoryCodes = {
      for (final entry in categoryIds.entries) entry.value: entry.key,
    };
    final ids = <String, int>{
      for (final row in existing)
        if (categoryCodes[row.categoryId] case final code?)
          '$code:${row.code}': row.id,
    };

    for (final tag in manifest.tags) {
      final categoryId = categoryIds[tag.category];
      if (categoryId == null) continue;
      final key = '${tag.category}:${tag.code}';
      if (ids.containsKey(key)) continue;
      ids[key] = await _db
          .into(_db.tags)
          .insert(
            TagsCompanion.insert(
              categoryId: categoryId,
              code: tag.code,
              name: tag.name,
              sort: Value(tag.sort),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    return _TagLookup(ids, {
      for (final tag in manifest.tags) '${tag.category}:${tag.code}': tag.name,
    });
  }

  Future<Map<String, int>> _upsertTextures(
    ParsedPackage package,
    DateTime now,
  ) async {
    final ids = <String, int>{
      for (final row in await _db.select(_db.textures).get()) row.hash: row.id,
    };

    for (final hash in package.textures.keys) {
      if (ids.containsKey(hash)) continue;
      ids[hash] = await _db
          .into(_db.textures)
          .insert(
            TexturesCompanion.insert(
              hash: hash,
              relPath: p.posix.join('sha', hash.substring(0, 2), '$hash.webp'),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    return ids;
  }

  Future<(Map<String, int>, Set<String>)> _upsertBlocks(
    ParsedPackage package,
    Map<String, int> textureIds,
    DateTime now,
    ImportReport report,
    void Function(ImportProgress progress)? onProgress,
  ) async {
    final existing = {
      for (final row in await _db.select(_db.blocks).get()) row.code: row,
    };
    final ids = <String, int>{};
    final inserted = <String>{};
    final total = package.blocks.length;
    var done = 0;

    for (final block in package.blocks) {
      final current = existing[block.code];
      final icon = _resolveIcon(textureIds, block);

      if (current == null) {
        final insertedId = await _db
            .into(_db.blocks)
            .insert(
              BlocksCompanion.insert(
                code: block.code,
                name: Value(block.name),
                nameEn: Value(block.nameEn),
                nameZh: Value(block.nameZh),
                colorHex: Value(block.colorHex),
                reviewed: Value(block.reviewed),
                iconId: Value(icon),
                createdAt: now,
                updatedAt: now,
              ),
            );
        ids[block.code] = insertedId;
        inserted.add(block.code);
        await _replaceBlockTextures(insertedId, block, textureIds);
        report.blocksInserted++;
      } else {
        ids[block.code] = current.id;
        if (current.reviewed) {
          report.blocksSkipped++;
        } else {
          await (_db.update(_db.blocks)..where((t) => t.id.equals(current.id)))
              .write(
                BlocksCompanion(
                  name: _keep(block.name),
                  nameEn: _keep(block.nameEn),
                  nameZh: _keep(block.nameZh),
                  colorHex: _keep(block.colorHex),
                  // 包里没有贴图信息时不覆盖已有数据，避免把图擦掉。
                  iconId: icon == null ? const Value.absent() : Value(icon),
                  updatedAt: Value(now),
                ),
              );
          await _replaceBlockTextures(current.id, block, textureIds);
          report.blocksUpdated++;
        }
      }

      done++;
      if (done % 100 == 0 || done == total) {
        onProgress?.call(ImportProgress('方块', done, total));
      }
    }

    for (final block in package.blocks) {
      final baseCode = block.variantOf;
      if (baseCode == null) continue;

      final id = ids[block.code];
      if (id == null) continue;
      if (!inserted.contains(block.code) &&
          (existing[block.code]?.reviewed ?? false)) {
        continue;
      }

      final baseId = ids[baseCode];
      if (baseId == null) {
        report.problems.add('${block.code}: 基础方块 $baseCode 不在数据包里');
        continue;
      }
      if (baseId == id) {
        report.problems.add('${block.code}: 变体指向自己，已忽略');
        continue;
      }

      await (_db.update(_db.blocks)..where((t) => t.id.equals(id))).write(
        BlocksCompanion(variantOf: Value(baseId), updatedAt: Value(now)),
      );
    }

    return (ids, inserted);
  }

  /// 变体关系成环会让折叠查询失去意义，直接断开并记录。
  Future<void> _breakCycles(ImportReport report) async {
    final rows = await _db.select(_db.blocks).get();
    final parents = {for (final row in rows) row.id: row.variantOf};

    for (final row in rows) {
      final seen = <int>{row.id};
      var current = row.variantOf;
      while (current != null && seen.add(current)) {
        current = parents[current];
      }
      if (current != null) {
        await (_db.update(_db.blocks)..where((t) => t.id.equals(row.id)))
            .write(const BlocksCompanion(variantOf: Value<int?>(null)));
        report.problems.add('${row.code}: 变体关系成环，已断开');
      }
    }
  }

  Future<void> _linkTags(
    ParsedPackage package,
    Map<String, int> blockIds,
    Set<String> inserted,
    _TagLookup lookup,
    DateTime now,
    ImportReport report,
  ) async {
    final existing = <String, TagSource>{
      for (final row in await _db.select(_db.blockTags).get())
        '${row.blockId}:${row.tagId}': TagSource.parse(row.source),
    };

    Future<void> link(int blockId, String ref, TagSource source) async {
      final tagId = lookup.resolve(ref);
      if (tagId == null) {
        report.problems.add('标签 $ref 不在词表里');
        return;
      }

      final key = '$blockId:$tagId';
      final current = existing[key];
      if (current == null) {
        await _db
            .into(_db.blockTags)
            .insert(
              BlockTagsCompanion.insert(
                blockId: blockId,
                tagId: tagId,
                source: Value(source.value),
                createdAt: now,
                updatedAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        existing[key] = source;
        report.tagsLinked++;
      } else if (source.priority > current.priority) {
        await (_db.update(_db.blockTags)..where(
              (t) => t.blockId.equals(blockId) & t.tagId.equals(tagId),
            ))
            .write(
              BlockTagsCompanion(
                source: Value(source.value),
                updatedAt: Value(now),
              ),
            );
        existing[key] = source;
      }
    }

    for (final block in package.blocks) {
      final blockId = blockIds[block.code];
      if (blockId == null) continue;

      for (final tag in block.tags) {
        // 预填（auto）只给新方块；vanilla / user 对已有方块也补。
        if (tag.source == TagSource.auto && !inserted.contains(block.code)) {
          continue;
        }
        await link(blockId, tag.ref, tag.source);
      }
    }
  }

  Future<void> _writeMeta(PackageManifest manifest, DateTime now) async {
    final values = {
      'mc_version': manifest.mcVersion,
      'package_format_version': '${manifest.formatVersion}',
      'imported_at': now.toIso8601String(),
    };
    for (final entry in values.entries) {
      await _db
          .into(_db.meta)
          .insertOnConflictUpdate(
            MetaCompanion.insert(key: entry.key, value: entry.value),
          );
    }
  }

  int? _textureId(Map<String, int> textureIds, String? hash) =>
      hash == null ? null : textureIds[hash];

  int? _resolveIcon(Map<String, int> textureIds, PackageBlock block) =>
      _textureId(textureIds, block.icon);

  /// 材质映射整块替换：先删干净再写，空映射也要清掉旧行。
  Future<void> _replaceBlockTextures(
    int blockId,
    PackageBlock block,
    Map<String, int> textureIds,
  ) async {
    await (_db.delete(
      _db.blockTextures,
    )..where((t) => t.blockId.equals(blockId))).go();
    for (final entry in block.textures) {
      final textureId = textureIds[entry.hash];
      if (textureId == null) continue;
      await _db
          .into(_db.blockTextures)
          .insert(
            BlockTexturesCompanion.insert(
              blockId: blockId,
              key: entry.key,
              textureId: textureId,
              sort: Value(entry.sort),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  static Value<T> _keep<T extends Object>(T? value) =>
      value == null ? const Value.absent() : Value(value);
}

/// 标签引用解析：`分类:标签` 按分类内的 code 查，裸值先查 code 再查 name。
final class _TagLookup {
  _TagLookup(Map<String, int> ids, Map<String, String> names) {
    for (final entry in ids.entries) {
      final code = entry.key.substring(entry.key.indexOf(':') + 1);
      byKey[entry.key] = entry.value;
      byCode.putIfAbsent(code, () => entry.value);
      final name = names[entry.key];
      if (name != null) byName.putIfAbsent(name, () => entry.value);
    }
  }

  final byKey = <String, int>{};
  final byCode = <String, int>{};
  final byName = <String, int>{};

  int? resolve(String ref) {
    final index = ref.indexOf(':');
    if (index > 0 && index < ref.length - 1) return byKey[ref];
    return byCode[ref] ?? byName[ref];
  }
}
