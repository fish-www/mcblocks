import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';
import 'package:mcblocks/features/blocks/data/blocks_repository.dart';
import 'package:mcblocks/features/blocks/domain/block_filter.dart';
import 'package:mcblocks/features/import/data/package_importer.dart';
import 'package:mcblocks/features/import/data/package_reader.dart';
import 'package:mcblocks/features/import/domain/import_report.dart';

import 'package_test_utils.dart';

void main() {
  const reader = PackageReader();

  late AppDatabase db;
  late Directory textures;
  late PackageImporter importer;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    textures = await Directory.systemTemp.createTemp('mcblocks_import_test');
    importer = PackageImporter(db, texturesDirectory: textures);
  });

  tearDown(() async {
    await db.close();
    await textures.delete(recursive: true);
  });

  test('首次导入写入方块、词表、标签和贴图', () async {
    final report = await importer.import(reader.parse(buildPackage()));

    expect(report.blocksInserted, 3);
    expect(report.blocksUpdated, 0);
    expect(report.texturesWritten, 2);
    expect(report.problems, isEmpty);

    expect(await db.select(db.categories).get(), hasLength(4));
    expect(await db.select(db.tags).get(), hasLength(6));
    expect(await db.select(db.textures).get(), hasLength(2));

    final slab = await _block(db, 'stone_slab');
    final stone = await _block(db, 'stone');
    expect(slab.variantOf, stone.id);
    expect(stone.iconId, await _textureId(db, hashA));
    expect(slab.iconId, await _textureId(db, hashB));
    final blockTextureRows = await (db.select(
      db.blockTextures,
    )..where((t) => t.blockId.equals(stone.id))).get();
    expect(
      blockTextureRows.map((row) => row.key),
      containsAll(['side', 'top', 'particle']),
    );
    expect(stone.colorHex, '#7f7f7f');
    expect(stone.nameZh, '石头');

    final links = await db.select(db.blockTags).get();
    expect(links, hasLength(4));
    final sources = {
      for (final link in links)
        if (link.blockId == stone.id) link.tagId: link.source,
    };
    expect(sources.values, unorderedEquals(['auto', 'vanilla']));

    final textureFile = File(
      '${textures.path}/sha/${hashA.substring(0, 2)}/$hashA.webp',
    );
    expect(await textureFile.exists(), isTrue);
    expect(await textureFile.readAsBytes(), [1, 2, 3]);

    final meta = {
      for (final row in await db.select(db.meta).get()) row.key: row.value,
    };
    expect(meta['mc_version'], '1.21.1');
    expect(meta['package_format_version'], '2');
  });

  test('重复导入是增量的，reviewed 方块计数为跳过', () async {
    await importer.import(reader.parse(buildPackage()));
    final report = await importer.import(reader.parse(buildPackage()));

    expect(report.blocksInserted, 0);
    expect(report.blocksUpdated, 2);
    expect(report.blocksSkipped, 1);
    expect(report.texturesWritten, 0);
    expect(report.texturesSkipped, 2);
    expect(report.tagsLinked, 0);
    expect(await db.select(db.blocks).get(), hasLength(3));
  });

  test('reviewed=1 的方块名字和贴图不被覆盖', () async {
    await importer.import(reader.parse(buildPackage()));

    final blocks = defaultBlocks();
    blocks[2] = {
      ...blocks[2],
      'name_zh': '导入想改的名字',
      'textures': {'side': hashA},
    };
    await importer.import(
      reader.parse(buildPackage(blocks: blocks)),
    );

    final wool = await _block(db, 'white_wool');
    expect(wool.nameZh, '白色羊毛');
    expect(wool.iconId, isNot(await _textureId(db, hashA)));
  });

  test('rebuild 模式先清空再写入', () async {
    await importer.import(reader.parse(buildPackage()));

    final onlyStone = [
      {
        'code': 'stone',
        'name_zh': '石头',
        'textures': {'side': hashA},
        'tags': [
          {'tag': '粗糙度:光滑', 'source': 'auto'},
        ],
      },
    ];
    final report = await importer.import(
      reader.parse(buildPackage(blocks: onlyStone)),
      mode: ImportMode.rebuild,
    );

    expect(report.blocksInserted, 1);
    final remaining = await db.select(db.blocks).get();
    expect(remaining.map((row) => row.code), ['stone']);
    expect(await db.select(db.blockTags).get(), hasLength(1));
  });

  test('变体指向不存在的方块时记录问题并留空', () async {
    final blocks = [
      {
        'code': 'stone_slab',
        'variant_of': 'missing_block',
        'textures': <String, String>{},
        'tags': <Map<String, String>>[],
      },
    ];

    final report = await importer.import(
      reader.parse(buildPackage(blocks: blocks)),
    );

    expect(report.problems.single, contains('missing_block'));
    expect((await _block(db, 'stone_slab')).variantOf, isNull);
  });

  test('变体成环时断开并记录', () async {
    final blocks = [
      {
        'code': 'a',
        'variant_of': 'b',
        'textures': <String, String>{},
        'tags': <Map<String, String>>[],
      },
      {
        'code': 'b',
        'variant_of': 'a',
        'textures': <String, String>{},
        'tags': <Map<String, String>>[],
      },
    ];

    final report = await importer.import(
      reader.parse(buildPackage(blocks: blocks)),
    );

    expect(report.problems.where((p) => p.contains('成环')), hasLength(2));
    final rows = await db.select(db.blocks).get();
    expect(rows.every((row) => row.variantOf == null), isTrue);
  });

  test('导入后折叠查询能按家族命中标签', () async {
    await importer.import(reader.parse(buildPackage()));

    final repo = BlocksRepository(db);
    final rows = (await repo.query(const BlockFilter(tags: ['形状:台阶']))).items;

    expect(rows.map((row) => row.code), ['stone']);
    expect(rows.single.variantCount, 1);
    expect(rows.single.displayName, '石头');
    expect(rows.single.tags.map((tag) => tag.label), ['粗糙度:光滑', '原版:mineable/pickaxe']);
    expect(rows.single.vanillaTags, hasLength(1));
  });

  test('导入过程中报告进度', () async {
    final seen = <String>[];
    await importer.import(
      reader.parse(buildPackage()),
      onProgress: (progress) {
        expect(progress.done, lessThanOrEqualTo(progress.total));
        seen.add(progress.stage);
      },
    );

    expect(seen, containsAll(['贴图', '方块']));
  });
}

Future<Block> _block(AppDatabase db, String code) => (db.select(
  db.blocks,
)..where((t) => t.code.equals(code))).getSingle();

Future<int?> _textureId(AppDatabase db, String hash) async {
  final row = await (db.select(
    db.textures,
  )..where((t) => t.hash.equals(hash))).getSingleOrNull();
  return row?.id;
}
