import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/features/import/data/package_reader.dart';
import 'package:mcblocks/features/import/domain/import_exception.dart';

import 'package_test_utils.dart';

void main() {
  const reader = PackageReader();

  test('解析 manifest、方块行和贴图字节', () {
    final package = reader.parse(buildPackage());

    expect(package.manifest.mcVersion, '1.21.1');
    expect(package.manifest.categories, hasLength(4));
    expect(package.manifest.tags, hasLength(6));

    expect(package.blocks, hasLength(3));
    final stone = package.blocks.firstWhere((b) => b.code == 'stone');
    expect(stone.nameZh, '石头');
    expect(stone.colorHex, '#7f7f7f');
    expect(
      {for (final entry in stone.textures) entry.key: entry.hash}['side'],
      hashA,
    );
    expect(stone.icon, hashA);
    expect(
      stone.tags.map((tag) => (tag.ref, tag.source.value)),
      [('粗糙度:光滑', 'auto'), ('vanilla:mineable/pickaxe', 'vanilla')],
    );

    final slab = package.blocks.firstWhere((b) => b.code == 'stone_slab');
    expect(slab.variantOf, 'stone');

    // 只读取被引用的贴图。
    expect(package.textures.keys, unorderedEquals([hashA, hashB]));
    expect(package.textures[hashA], [1, 2, 3]);
    expect(package.problems, isEmpty);
  });

  test('词表里没有的标签丢弃并记录', () {
    final package = reader.parse(
      buildPackage(
        blocks: [
          {
            'code': 'stone',
            'textures': [
              {'key': 'side', 'hash': hashA, 'sort': 0},
            ],
            'tags': [
              {'tag': '色系:紫', 'source': 'auto'},
              {'tag': '形状:立方', 'source': 'auto'},
            ],
          },
        ],
      ),
    );

    expect(package.blocks.single.tags.map((tag) => tag.ref), ['形状:立方']);
    expect(package.problems.single, contains('色系:紫'));
  });

  test('坏行跳过，不影响其他方块', () {
    final raw = [
      '{"code":"stone","textures":{"side":"$hashA"}}',
      '不是 json',
      '[]',
      '{"name_zh":"没有 code"}',
      '{"code":"dirt","textures":{"side":"$hashA"}}',
    ].join('\n');

    final package = reader.parse(buildPackage(rawBlocks: raw));

    expect(package.blocks.map((b) => b.code), ['stone', 'dirt']);
    expect(package.problems, hasLength(3));
    expect(package.problems[0], contains('第 2 行'));
  });

  test('标签默认空列表', () {
    final package = reader.parse(
      buildPackage(
        blocks: [
          {'code': 'stone', 'textures': {'side': hashA}},
        ],
      ),
    );

    expect(package.blocks.single.tags, isEmpty);
  });

  test('贴图缺失记一条问题，方块保留', () {
    final package = reader.parse(
      buildPackage(
        blocks: [
          {
            'code': 'stone',
            'textures': [
              {'key': 'side', 'hash': hashA, 'sort': 0},
              {'key': 'top', 'hash': 'c' * 40, 'sort': 1},
            ],
          },
        ],
      ),
    );

    expect(
      {for (final entry in package.blocks.single.textures) entry.key: entry.hash}['top'],
      'c' * 40,
    );
    expect(package.textures.keys, [hashA]);
    expect(package.problems.single, contains('贴图缺失'));
  });

  test('未知的标签来源整行跳过', () {
    final package = reader.parse(
      buildPackage(
        blocks: [
          {
            'code': 'stone',
            'tags': [
              {'tag': '色系:灰', 'source': 'nope'},
            ],
          },
          {'code': 'dirt'},
        ],
      ),
    );

    expect(package.blocks.map((b) => b.code), ['dirt']);
    expect(package.problems.single, contains('未知的标签来源'));
  });

  test('缺少 manifest.json 或 blocks.jsonl 直接报错', () {
    expect(
      () => reader.parse(buildPackage(includeManifest: false)),
      throwsA(isA<ImportException>()),
    );
    expect(
      () => reader.parse(buildPackage(includeBlocks: false)),
      throwsA(isA<ImportException>()),
    );
  });

  test('格式版本不支持时报错并给出提示', () {
    final manifest = Map<String, Object?>.of(defaultManifest())
      ..['format_version'] = 3;

    expect(
      () => reader.parse(buildPackage(manifest: manifest)),
      throwsA(
        isA<ImportException>().having(
          (error) => error.hint,
          'hint',
          contains('Python'),
        ),
      ),
    );
  });

  test('非法贴图文件名被忽略', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string('manifest.json', jsonEncode(defaultManifest())),
      )
      ..addFile(
        ArchiveFile.string(
          'blocks.jsonl',
          jsonEncode({
            'code': 'stone',
            'textures': [
              {'key': 'side', 'hash': hashA, 'sort': 0},
            ],
          }),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'textures/../../evil.webp',
          Uint8List.fromList([9]),
        ),
      );

    final package = reader.parse(Uint8List.fromList(ZipEncoder().encode(archive)));

    expect(package.textures, isEmpty);
    expect(
      package.problems.any((problem) => problem.contains('贴图缺失')),
      isTrue,
    );
  });
}
