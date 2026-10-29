import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 两段合法的 sha1 形态 hash，用于贴图命名。
const String hashA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String hashB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Map<String, Object?> defaultManifest() => {
  'format_version': 2,
  'mc_version': '1.21.1',
  'generated_at': '2026-10-29T09:00:00+08:00',
  'categories': [
    {'code': '色系', 'name': '色系', 'single': 1, 'ordered': 1, 'sort': 10},
    {'code': '形状', 'name': '形状', 'single': 1, 'ordered': 0, 'sort': 20},
    {'code': '粗糙度', 'name': '粗糙度', 'single': 1, 'ordered': 0, 'sort': 30},
    {'code': 'vanilla', 'name': '原版', 'single': 0, 'ordered': 0, 'sort': 40},
  ],
  'tags': [
    {'category': '色系', 'code': '灰', 'name': '灰', 'sort': 10},
    {'category': '色系', 'code': '白', 'name': '白', 'sort': 20},
    {'category': '形状', 'code': '立方', 'name': '立方', 'sort': 10},
    {'category': '形状', 'code': '台阶', 'name': '台阶', 'sort': 20},
    {'category': '粗糙度', 'code': '光滑', 'name': '光滑', 'sort': 10},
    {
      'category': 'vanilla',
      'code': 'mineable/pickaxe',
      'name': 'mineable/pickaxe',
      'sort': 10,
    },
  ],
};

List<Map<String, Object?>> defaultBlocks() => [
  {
    'code': 'stone',
    'name_en': 'Stone',
    'name_zh': '石头',
    'color_hex': '#7f7f7f',
    'variant_of': null,
    'reviewed': 0,
    'textures': [
      {'key': 'side', 'hash': hashA, 'sort': 0},
      {'key': 'top', 'hash': hashA, 'sort': 1},
      {'key': 'bottom', 'hash': hashA, 'sort': 2},
      {'key': 'particle', 'hash': hashA, 'sort': 3},
    ],
    'icon': hashA,
    'tags': [
      {'tag': '粗糙度:光滑', 'source': 'auto'},
      {'tag': 'vanilla:mineable/pickaxe', 'source': 'vanilla'},
    ],
  },
  {
    'code': 'stone_slab',
    'name_en': 'Stone Slab',
    'name_zh': '石台阶',
    'color_hex': null,
    'variant_of': 'stone',
    'reviewed': 0,
    'textures': [
      {'key': 'side', 'hash': hashB, 'sort': 0},
      {'key': 'bottom', 'hash': hashB, 'sort': 1},
    ],
    'icon': hashB,
    'tags': [
      {'tag': '形状:台阶', 'source': 'auto'},
    ],
  },
  {
    'code': 'white_wool',
    'name_en': 'White Wool',
    'name_zh': '白色羊毛',
    'color_hex': '#e9ecec',
    'variant_of': null,
    'reviewed': 1,
    'textures': {'side': hashB},
    'tags': [
      {'tag': '色系:白', 'source': 'auto'},
    ],
  },
];

/// 拼一个内存 zip 数据包。[rawBlocks] 用来塞入故意损坏的行。
Uint8List buildPackage({
  Map<String, Object?>? manifest,
  List<Map<String, Object?>>? blocks,
  String? rawBlocks,
  Map<String, Uint8List>? textures,
  bool includeManifest = true,
  bool includeBlocks = true,
}) {
  final archive = Archive();

  if (includeManifest) {
    archive.addFile(
      ArchiveFile.string(
        'manifest.json',
        jsonEncode(manifest ?? defaultManifest()),
      ),
    );
  }
  if (includeBlocks) {
    final lines = rawBlocks ??
        [for (final block in blocks ?? defaultBlocks()) jsonEncode(block)]
            .join('\n');
    archive.addFile(ArchiveFile.string('blocks.jsonl', lines));
  }

  final textureBytes = textures ??
      {
        hashA: Uint8List.fromList([1, 2, 3]),
        hashB: Uint8List.fromList([4, 5, 6]),
      };
  for (final entry in textureBytes.entries) {
    archive.addFile(
      ArchiveFile.bytes(
        'textures/sha/${entry.key.substring(0, 2)}/${entry.key}.webp',
        entry.value,
      ),
    );
  }

  return Uint8List.fromList(ZipEncoder().encode(archive));
}
