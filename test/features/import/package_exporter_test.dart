import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';
import 'package:mcblocks/features/blocks/data/blocks_repository.dart';
import 'package:mcblocks/features/blocks/domain/block_filter.dart';
import 'package:mcblocks/features/import/data/package_exporter.dart';
import 'package:mcblocks/features/import/data/package_importer.dart';
import 'package:mcblocks/features/import/data/package_reader.dart';
import 'package:mcblocks/features/import/domain/package_manifest.dart';

import 'package_test_utils.dart';

void main() {
  late Directory textures;

  setUp(() async {
    textures = await Directory.systemTemp.createTemp('mcblocks_export');
  });

  tearDown(() => textures.delete(recursive: true));

  Future<AppDatabase> seeded() async {
    final db = AppDatabase(NativeDatabase.memory());
    await PackageImporter(db, texturesDirectory: textures).import(
      const PackageReader().parse(buildPackage()),
    );
    return db;
  }

  test('导出的包能被重新解析', () async {
    final db = await seeded();
    addTearDown(db.close);

    final report = await PackageExporter(
      db,
      texturesDirectory: textures,
    ).export();

    expect(report.blocks, 3);
    expect(report.textures, 2);
    expect(report.missing, isEmpty);

    final package = const PackageReader().parse(report.bytes);
    expect(package.manifest.mcVersion, '1.21.1');
    expect(
      package.manifest.formatVersion,
      PackageManifest.supportedFormatVersion,
    );
    expect(package.blocks.map((b) => b.code), [
      'stone',
      'stone_slab',
      'white_wool',
    ]);
    expect(package.problems, isEmpty);

    final stone = package.blocks.first;
    expect(stone.nameZh, '石头');
    expect(stone.icon, hashA);
    expect(
      {for (final entry in stone.textures) entry.key: entry.hash},
      containsPair('side', hashA),
    );
    expect(
      {for (final tag in stone.tags) tag.ref: tag.source.value},
      containsPair('vanilla:mineable/pickaxe', 'vanilla'),
    );
  });

  test('导出再导入保持内容一致', () async {
    final source = await seeded();
    addTearDown(source.close);

    final bytes = (await PackageExporter(
      source,
      texturesDirectory: textures,
    ).export()).bytes;

    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await PackageImporter(target, texturesDirectory: textures).import(
      const PackageReader().parse(bytes),
    );

    final before = await BlocksRepository(source)
        .query(const BlockFilter());
    final after = await BlocksRepository(target)
        .query(const BlockFilter());

    expect(after.total, before.total);
    expect(
      after.items.map((item) => item.code),
      before.items.map((item) => item.code),
    );
    expect(
      after.items.map((item) => item.displayName),
      before.items.map((item) => item.displayName),
    );
    expect(
      after.items.map((item) => item.iconHash),
      before.items.map((item) => item.iconHash),
    );
  });
}
