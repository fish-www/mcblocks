import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart' hide BlockTag;
import '../../../core/db/connection.dart';
import '../../../core/db/database_provider.dart';
import '../domain/patch.dart';
import '../domain/tag_source.dart';

part 'block_writer.g.dart';

@riverpod
BlockWriter blockWriter(Ref ref) => BlockWriter(ref.watch(appDatabaseProvider));

/// 标注的唯一写入口。一个 `apply` 就是一个事务，失败整体回滚。
///
/// 校验规则：
/// - 标签必须存在，`分类:标签` 或裸标签都行
/// - 单选分类（`single=1`）加新值会替换旧值
/// - 原版标签不允许手工删除
/// - 写入的标签来源固定为 `user`，优先级高于 `auto` / `vanilla`
class BlockWriter {
  BlockWriter(this._db, {Future<Directory> Function()? texturesDirectory})
    : _texturesDirectory =
          texturesDirectory ?? (() async => Directory(await texturesPath()));

  /// `命名空间:名称`，对应 Minecraft 的资源命名。
  static final RegExp _codePattern = RegExp(
    r'^[a-z0-9_.-]+:[a-z0-9_./-]+$',
  );

  final AppDatabase _db;
  final Future<Directory> Function() _texturesDirectory;

  Future<void> apply(BlockPatch patch) async {
    await _db.transaction(() async {
      final now = DateTime.now().toUtc();
      final block = await (_db.select(
        _db.blocks,
      )..where((t) => t.code.equals(patch.code))).getSingleOrNull();
      if (block == null) {
        throw PatchException('找不到方块 ${patch.code}');
      }

      if (patch.colorHex.present) {
        final raw = patch.colorHex.value;
        final normalized = raw == null ? null : _normalizeHex(raw);
        await (_db.update(_db.blocks)..where((t) => t.id.equals(block.id)))
            .write(
              BlocksCompanion(
                colorHex: Value(normalized),
                updatedAt: Value(now),
              ),
            );
      }

      if (patch.reviewed.present) {
        await (_db.update(_db.blocks)..where((t) => t.id.equals(block.id)))
            .write(
              BlocksCompanion(
                reviewed: Value(patch.reviewed.value),
                updatedAt: Value(now),
              ),
            );
      }

      final tags = await _vocab();
      for (final ref in patch.removeTags) {
        await _removeTag(block.id, ref, tags);
      }
      for (final tag in patch.addTags) {
        await _addTag(block.id, tag, tags, now);
      }
    });
  }

  String _normalizeHex(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (!RegExp(r'^#[0-9a-f]{6}$').hasMatch(normalized)) {
      throw PatchException('色值必须是 #rrggbb', '例如 #7f7f7f');
    }
    return normalized;
  }

  /// 新建方块。code 唯一，其余字段可后补。
  Future<int> createBlock({
    required String code,
    String? name,
    String? nameZh,
    String? nameEn,
    String? colorHex,
  }) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) throw const PatchException('code 不能为空');
    if (!_codePattern.hasMatch(trimmed)) {
      throw const PatchException(
        'code 要写成 命名空间:名称',
        '例如 minecraft:stone 或 create:zinc_block',
      );
    }
    final color = colorHex == null ? null : _normalizeHex(colorHex);

    return _db.transaction(() async {
      final exists = await (_db.select(
        _db.blocks,
      )..where((t) => t.code.equals(trimmed))).getSingleOrNull();
      if (exists != null) throw PatchException('方块 $trimmed 已存在');

      final now = DateTime.now().toUtc();
      return _db
          .into(_db.blocks)
          .insert(
            BlocksCompanion.insert(
              code: trimmed,
              name: Value(name?.trim().isEmpty ?? true ? null : name!.trim()),
              nameZh: Value(
                nameZh?.trim().isEmpty ?? true ? null : nameZh!.trim(),
              ),
              nameEn: Value(
                nameEn?.trim().isEmpty ?? true ? null : nameEn!.trim(),
              ),
              colorHex: Value(color),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  /// 编辑方块基本信息，返回最终的 code（改了 code 就返回新的）。
  Future<String> updateBlock(
    String code, {
    String? newCode,
    String? name,
    String? nameZh,
    String? nameEn,
    String? iconKey,
    bool clearIcon = false,
  }) async {
    final target = (newCode ?? code).trim();
    if (target.isEmpty) throw const PatchException('code 不能为空');
    if (!_codePattern.hasMatch(target)) {
      throw const PatchException(
        'code 要写成 命名空间:名称',
        '例如 minecraft:stone 或 create:zinc_block',
      );
    }

    return _db.transaction(() async {
      final block = await (_db.select(
        _db.blocks,
      )..where((t) => t.code.equals(code))).getSingleOrNull();
      if (block == null) throw PatchException('找不到方块 $code');

      if (target != code) {
        final clash = await (_db.select(
          _db.blocks,
        )..where((t) => t.code.equals(target))).getSingleOrNull();
        if (clash != null) throw PatchException('方块 $target 已存在');
      }

      int? iconId = block.iconId;
      if (clearIcon) {
        iconId = null;
      } else if (iconKey != null) {
        final row = await _textureRow(block.id, iconKey);
        if (row == null) throw PatchException('找不到材质 $iconKey');
        iconId = row.textureId;
      }

      await (_db.update(_db.blocks)..where((t) => t.id.equals(block.id)))
          .write(
            BlocksCompanion(
              code: Value(target),
              name: name == null
                  ? const Value.absent()
                  : Value(_emptyToNull(name)),
              nameZh: nameZh == null
                  ? const Value.absent()
                  : Value(_emptyToNull(nameZh)),
              nameEn: nameEn == null
                  ? const Value.absent()
                  : Value(_emptyToNull(nameEn)),
              iconId: Value(iconId),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      return target;
    });
  }

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 删除方块，连同它的标签和材质映射。
  Future<void> deleteBlock(String code) async {
    await _db.transaction(() async {
      final block = await (_db.select(
        _db.blocks,
      )..where((t) => t.code.equals(code))).getSingleOrNull();
      if (block == null) throw PatchException('找不到方块 $code');

      await (_db.delete(
        _db.blockTextures,
      )..where((t) => t.blockId.equals(block.id))).go();
      await (_db.delete(
        _db.blockTags,
      )..where((t) => t.blockId.equals(block.id))).go();
      await (_db.update(_db.blocks)..where(
            (t) => t.variantOf.equals(block.id),
          ))
          .write(const BlocksCompanion(variantOf: Value<int?>(null)));
      await (_db.delete(
        _db.blocks,
      )..where((t) => t.id.equals(block.id))).go();
    });
  }

  /// 重命名材质键。
  Future<void> renameTexture(String code, String key, String newKey) async {
    final trimmed = newKey.trim();
    if (trimmed.isEmpty) throw const PatchException('材质名不能为空');

    await _db.transaction(() async {
      final blockId = await _blockId(code);
      final row = await _textureRow(blockId, key);
      if (row == null) throw PatchException('找不到材质 $key');
      final clash = await _textureRow(blockId, trimmed);
      if (clash != null) throw PatchException('材质 $trimmed 已存在');

      await (_db.update(_db.blockTextures)..where(
            (t) => t.blockId.equals(blockId) & t.key.equals(key),
          ))
          .write(BlockTexturesCompanion(key: Value(trimmed)));
    });
  }

  /// 删除一条材质映射。
  Future<void> deleteTexture(String code, String key) async {
    await _db.transaction(() async {
      final blockId = await _blockId(code);
      final row = await _textureRow(blockId, key);
      if (row == null) throw PatchException('找不到材质 $key');

      await (_db.delete(_db.blockTextures)..where(
            (t) => t.blockId.equals(blockId) & t.key.equals(key),
          ))
          .go();

      // 删掉的正好是图标就换下一个。
      final block = await (_db.select(
        _db.blocks,
      )..where((t) => t.id.equals(blockId))).getSingle();
      if (block.iconId == row.textureId) {
        final next = await (_db.select(_db.blockTextures)
              ..where((t) => t.blockId.equals(blockId))
              ..orderBy([(t) => OrderingTerm(expression: t.sort)])
              ..limit(1))
            .getSingleOrNull();
        await (_db.update(_db.blocks)..where((t) => t.id.equals(blockId)))
            .write(
              BlocksCompanion(
                iconId: Value(next?.textureId),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    });
  }

  /// 上移 / 下移材质，delta 为 -1 或 1。
  Future<void> moveTexture(String code, String key, int delta) async {
    await _db.transaction(() async {
      final blockId = await _blockId(code);
      final rows = await (_db.select(_db.blockTextures)
            ..where((t) => t.blockId.equals(blockId))
            ..orderBy([(t) => OrderingTerm(expression: t.sort)]))
          .get();
      final index = rows.indexWhere((row) => row.key == key);
      if (index < 0) throw PatchException('找不到材质 $key');
      final target = index + delta;
      if (target < 0 || target >= rows.length) return;

      final reordered = [...rows];
      final moved = reordered.removeAt(index);
      reordered.insert(target, moved);
      await _db.batch((batch) {
        for (var i = 0; i < reordered.length; i++) {
          batch.update(
            _db.blockTextures,
            BlockTexturesCompanion(sort: Value(i)),
            where: (t) =>
                t.blockId.equals(blockId) & t.key.equals(reordered[i].key),
          );
        }
      });
    });
  }

  /// 添加一张贴图：统一转成 128px webp，按 hash 存盘。
  Future<void> addTexture(
    String code, {
    required String key,
    required Uint8List bytes,
  }) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) throw const PatchException('材质名不能为空');

    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const PatchException('无法解码这张图片');
    final square = img.copyResize(
      decoded,
      width: 128,
      height: 128,
      interpolation: img.Interpolation.nearest,
    );
    final webp = Uint8List.fromList(img.encodeWebP(square));
    final digest = sha1.convert(webp).toString();

    final directory = await _texturesDirectory();
    final file = File(p.join(directory.path, 'sha', digest.substring(0, 2), '$digest.webp'));
    if (!file.existsSync()) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(webp, flush: true);
    }

    await _db.transaction(() async {
      final blockId = await _blockId(code);
      final clash = await _textureRow(blockId, trimmed);
      if (clash != null) throw PatchException('材质 $trimmed 已存在');

      var textureId = (await (_db.select(
        _db.textures,
      )..where((t) => t.hash.equals(digest))).getSingleOrNull())?.id;
      final now = DateTime.now().toUtc();
      textureId ??= await _db
          .into(_db.textures)
          .insert(
            TexturesCompanion.insert(
              hash: digest,
              relPath: p.posix.join('sha', digest.substring(0, 2), '$digest.webp'),
              srcName: const Value('manual'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final maxSort = await _db
          .customSelect(
            'SELECT COALESCE(MAX(sort), -1) + 1 AS next FROM block_texture '
            'WHERE block_id = ?',
            variables: [Variable.withInt(blockId)],
          )
          .getSingle();

      await _db
          .into(_db.blockTextures)
          .insert(
            BlockTexturesCompanion.insert(
              blockId: blockId,
              key: trimmed,
              textureId: textureId,
              sort: Value(maxSort.read<int>('next')),
            ),
          );

      final block = await (_db.select(
        _db.blocks,
      )..where((t) => t.id.equals(blockId))).getSingle();
      if (block.iconId == null) {
        await (_db.update(_db.blocks)..where((t) => t.id.equals(blockId)))
            .write(BlocksCompanion(iconId: Value(textureId)));
      }
    });
  }

  Future<int> _blockId(String code) async {
    final block = await (_db.select(
      _db.blocks,
    )..where((t) => t.code.equals(code))).getSingleOrNull();
    if (block == null) throw PatchException('找不到方块 $code');
    return block.id;
  }

  Future<BlockTexture?> _textureRow(int blockId, String key) =>
      (_db.select(_db.blockTextures)..where(
            (t) => t.blockId.equals(blockId) & t.key.equals(key),
          ))
          .getSingleOrNull();

  Future<void> _addTag(
    int blockId,
    PatchTag tag,
    List<_VocabEntry> vocab,
    DateTime now,
  ) async {
    final entry = _resolve(tag.ref, vocab);
    if (entry == null) {
      throw PatchException('标签 ${tag.ref} 不在词表里', '先到词表页创建它');
    }

    if (entry.single) {
      await _clearSingleCategory(blockId, entry.category);
    }

    await _db
        .into(_db.blockTags)
        .insert(
          BlockTagsCompanion.insert(
            blockId: blockId,
            tagId: entry.id,
            source: Value(tag.source.value),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// 单选分类只留一个值；原版值不动，直接报错让人判断。
  Future<void> _clearSingleCategory(int blockId, String category) async {
    final rows = await _linksInCategory(blockId, category);
    for (final row in rows) {
      if (TagSource.parse(row.source) == TagSource.vanilla) {
        throw PatchException(
          '分类「$category」已有原版标签 ${row.tagCode}',
          '原版标签不能替换，先确认它是否该保留',
        );
      }
      await (_db.delete(_db.blockTags)..where(
            (t) => t.blockId.equals(blockId) & t.tagId.equals(row.tagId),
          ))
          .go();
    }
  }

  Future<void> _removeTag(
    int blockId,
    String ref,
    List<_VocabEntry> vocab,
  ) async {
    final entry = _resolve(ref, vocab);
    if (entry == null) {
      throw PatchException('标签 $ref 不在词表里');
    }

    final rows = await _linksInCategory(blockId, entry.category);
    final link = rows.where((row) => row.tagId == entry.id).firstOrNull;
    if (link == null) return;

    if (TagSource.parse(link.source) == TagSource.vanilla) {
      throw PatchException(
        '原版标签 ${entry.name} 不能删除',
        '原版标签由导入维护，重跑导入会再加回来',
      );
    }

    await (_db.delete(_db.blockTags)..where(
          (t) => t.blockId.equals(blockId) & t.tagId.equals(entry.id),
        ))
        .go();
  }

  Future<List<_LinkRow>> _linksInCategory(int blockId, String category) async {
    final rows = await _db
        .customSelect(
          '''
SELECT bt.tag_id AS tag_id, bt.source AS source, t.code AS tag_code
FROM block_tag bt
JOIN tag t ON t.id = bt.tag_id
JOIN category c ON c.id = t.category_id
WHERE bt.block_id = ? AND c.code = ?
''',
          variables: [Variable.withInt(blockId), Variable.withString(category)],
        )
        .get();
    return [
      for (final row in rows)
        _LinkRow(
          tagId: row.read<int>('tag_id'),
          source: row.read<String>('source'),
          tagCode: row.read<String>('tag_code'),
        ),
    ];
  }

  Future<List<_VocabEntry>> _vocab() async {
    final rows = await _db
        .customSelect(
          '''
SELECT t.id AS id, t.code AS code, t.name AS name,
       c.code AS category, c.name AS category_name, c.single AS single
FROM tag t JOIN category c ON c.id = t.category_id
''',
        )
        .get();
    return [
      for (final row in rows)
        _VocabEntry(
          id: row.read<int>('id'),
          code: row.read<String>('code'),
          name: row.read<String>('name'),
          category: row.read<String>('category'),
          categoryName: row.read<String>('category_name'),
          single: row.read<int>('single') != 0,
        ),
    ];
  }

  /// `分类:标签` 按分类内的 code 查；裸值先查 code，再查 name。
  _VocabEntry? _resolve(String ref, List<_VocabEntry> vocab) {
    final index = ref.indexOf(':');
    if (index > 0 && index < ref.length - 1) {
      final category = ref.substring(0, index);
      final value = ref.substring(index + 1);
      return vocab
          .where((e) => e.category == category && e.code == value)
          .firstOrNull;
    }
    return vocab.where((e) => e.code == ref).firstOrNull ??
        vocab.where((e) => e.name == ref).firstOrNull;
  }
}

final class _VocabEntry {
  const _VocabEntry({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.categoryName,
    required this.single,
  });

  final int id;
  final String code;
  final String name;
  final String category;
  final String categoryName;
  final bool single;
}

final class _LinkRow {
  const _LinkRow({
    required this.tagId,
    required this.source,
    required this.tagCode,
  });

  final int tagId;
  final String source;
  final String tagCode;
}
