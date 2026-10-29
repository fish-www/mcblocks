import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/connection.dart';
import '../../../core/db/database_provider.dart';
import '../domain/package_manifest.dart';

part 'package_exporter.g.dart';

@riverpod
Future<PackageExporter> packageExporter(Ref ref) async => PackageExporter(
  ref.watch(appDatabaseProvider),
  texturesDirectory: Directory(await texturesPath()),
);

/// 一次导出的结果。
final class ExportReport {
  const ExportReport({
    required this.blocks,
    required this.textures,
    required this.bytes,
    required this.missing,
  });

  final int blocks;
  final int textures;
  final Uint8List bytes;
  final List<String> missing;
}

/// 把当前数据库打回 `.mcblocks`，格式和 Python 工具产出的一致。
class PackageExporter {
  PackageExporter(this._db, {required this.texturesDirectory});

  final AppDatabase _db;
  final Directory texturesDirectory;

  Future<ExportReport> export() async {
    final mcVersion = await _meta('mc_version') ?? '';
    final categories = await (_db.select(_db.categories)..orderBy([
          (t) => OrderingTerm(expression: t.sort),
          (t) => OrderingTerm(expression: t.code),
        ]))
        .get();
    final tagRows = await _db
        .customSelect(
          '''
SELECT c.code AS category, t.code AS code, t.name AS name, t.sort AS sort
FROM tag t JOIN category c ON c.id = t.category_id
ORDER BY c.sort, c.code, t.sort, t.code
''',
        )
        .get();
    final blockRows = await _db
        .customSelect(
          '''
SELECT b.id AS id, b.code AS code, b.name AS name, b.name_en AS name_en,
       b.name_zh AS name_zh, b.color_hex AS color_hex, b.reviewed AS reviewed,
       v.code AS variant_of, icon.hash AS icon
FROM block b
LEFT JOIN block v ON v.id = b.variant_of
LEFT JOIN texture icon ON icon.id = b.icon_id
ORDER BY b.code
''',
        )
        .get();
    final textureRows = await (_db.select(
      _db.blockTextures,
    )..orderBy([(t) => OrderingTerm(expression: t.sort)]))
        .get();
    final tagLinks = await _db
        .customSelect(
          '''
SELECT bt.block_id AS block_id, bt.source AS source,
       c.code AS category, t.code AS code
FROM block_tag bt
JOIN tag t ON t.id = bt.tag_id
JOIN category c ON c.id = t.category_id
ORDER BY bt.block_id, c.sort, c.code, t.sort, t.code
''',
        )
        .get();
    final texturePaths = {
      for (final row in await _db.select(_db.textures).get())
        row.hash: row.relPath,
    };

    final textureHashes = {
      for (final row in await _db.select(_db.textures).get())
        row.id: row.hash,
    };
    final texturesByBlock = <int, List<Map<String, Object?>>>{};
    for (final row in textureRows) {
      final hash = textureHashes[row.textureId];
      if (hash == null) continue;
      (texturesByBlock[row.blockId] ??= []).add({
        'key': row.key,
        'hash': hash,
        'sort': row.sort,
      });
    }

    final tagsByBlock = <int, List<Map<String, Object?>>>{};
    for (final row in tagLinks) {
      (tagsByBlock[row.read<int>('block_id')] ??= []).add({
        'tag': '${row.read<String>('category')}:${row.read<String>('code')}',
        'source': row.read<String>('source'),
      });
    }

    final lines = <String>[];
    final referenced = <String>{};
    for (final row in blockRows) {
      final id = row.read<int>('id');
      final textures = texturesByBlock[id] ?? const [];
      final icon = row.read<String?>('icon');
      if (icon != null) referenced.add(icon);
      referenced.addAll([for (final entry in textures) entry['hash'] as String]);

      final item = <String, Object?>{
        'code': row.read<String>('code'),
        'name': row.read<String?>('name'),
        'name_en': row.read<String?>('name_en'),
        'name_zh': row.read<String?>('name_zh'),
        'color_hex': row.read<String?>('color_hex'),
        'variant_of': row.read<String?>('variant_of'),
        'reviewed': row.read<int>('reviewed') == 1 ? 1 : 0,
        'textures': textures,
        'icon': icon,
        'tags': tagsByBlock[id] ?? const [],
      };
      for (final key in ['name', 'name_en', 'name_zh', 'color_hex', 'variant_of']) {
        if (item[key] == null) item.remove(key);
      }
      lines.add(jsonEncode(item));
    }

    final manifest = <String, Object?>{
      'format_version': PackageManifest.supportedFormatVersion,
      'mc_version': mcVersion,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'block_count': lines.length,
      'texture_count': referenced.length,
      'categories': [
        for (final category in categories)
          {
            'code': category.code,
            'name': category.name,
            'single': category.single,
            'ordered': category.ordered,
            'sort': category.sort,
          },
      ],
      'tags': [
        for (final row in tagRows)
          {
            'category': row.read<String>('category'),
            'code': row.read<String>('code'),
            'name': row.read<String>('name'),
            'sort': row.read<int>('sort'),
          },
      ],
    };

    final archive = Archive();
    archive.addFile(
      ArchiveFile.string(
        'manifest.json',
        jsonEncode(manifest),
      ),
    );
    archive.addFile(ArchiveFile.string('blocks.jsonl', lines.join('\n')));

    final missing = <String>[];
    var written = 0;
    for (final hash in referenced.toList()..sort()) {
      final relPath = texturePaths[hash];
      if (relPath == null) {
        missing.add('$hash: 数据库里没有贴图记录');
        continue;
      }
      final file = File(p.join(texturesDirectory.path, relPath));
      if (!file.existsSync()) {
        missing.add('$hash: 文件不存在 $relPath');
        continue;
      }
      archive.addFile(
        ArchiveFile.bytes(
          'textures/sha/${hash.substring(0, 2)}/$hash.webp',
          await file.readAsBytes(),
        ),
      );
      written++;
    }

    return ExportReport(
      blocks: lines.length,
      textures: written,
      bytes: Uint8List.fromList(ZipEncoder().encode(archive)),
      missing: missing,
    );
  }

  Future<String?> _meta(String key) async {
    final row = await (_db.select(
      _db.meta,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }
}
