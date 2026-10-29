import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../domain/import_exception.dart';
import '../domain/package_block.dart';
import '../domain/package_manifest.dart';
import '../domain/parsed_package.dart';

/// 解析 `.mcblocks` 数据包（zip：`manifest.json` + `blocks.jsonl` +
/// `textures/sha/<hash>.webp`）。
///
/// 纯函数，不碰数据库和磁盘。解压和 JSON 解析是 CPU 活，调用方应放进 isolate。
final class PackageReader {
  const PackageReader();

  /// 防止异常数据包把内存吃光。
  static const int maxEntries = 200000;
  static const int maxTextureBytes = 512 * 1024 * 1024;

  static final RegExp _hashPattern = RegExp(r'^[0-9a-f]{40}$');

  ParsedPackage parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    if (archive.length > maxEntries) {
      throw const ImportException('数据包条目过多，可能不是 .mcblocks 文件');
    }

    ArchiveFile? manifestFile;
    ArchiveFile? blocksFile;
    final textureEntries = <String, ArchiveFile>{};

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name == 'manifest.json') {
        manifestFile = entry;
      } else if (name == 'blocks.jsonl') {
        blocksFile = entry;
      } else if (name.startsWith('textures/') && name.endsWith('.webp')) {
        // 只按 hash 重建路径，不信任压缩包里的目录名。
        final hash = name.substring(
          name.lastIndexOf('/') + 1,
          name.length - '.webp'.length,
        );
        if (_hashPattern.hasMatch(hash)) {
          textureEntries[hash] = entry;
        }
      }
    }

    if (manifestFile == null || blocksFile == null) {
      throw const ImportException(
        '数据包缺少 manifest.json 或 blocks.jsonl',
        '用 Python 工具重新生成数据包',
      );
    }

    final manifest = PackageManifest.fromJson(
      _decodeObject(manifestFile.readBytes(), 'manifest.json'),
    );
    final vocab = _Vocab(manifest);
    final problems = <String>[];

    final blocks = <String, PackageBlock>{};
    final referenced = <String>{};
    final blocksBytes = blocksFile.readBytes();
    if (blocksBytes == null) {
      throw const ImportException('blocks.jsonl 读取失败');
    }
    final raw = utf8.decode(blocksBytes, allowMalformed: true);

    for (final (index, line) in raw.split('\n').indexed) {
      if (line.trim().isEmpty) continue;
      final where = '第 ${index + 1} 行';

      final Object? decoded;
      try {
        decoded = jsonDecode(line);
      } on FormatException {
        problems.add('$where: 不是合法 JSON');
        continue;
      }
      if (decoded is! Map<String, Object?>) {
        problems.add('$where: 期望一个 JSON 对象');
        continue;
      }

      final PackageBlock block;
      try {
        block = PackageBlock.fromJson(decoded);
      } on ImportException catch (error) {
        problems.add('$where: ${error.message}');
        continue;
      }

      if (blocks.containsKey(block.code)) {
        problems.add('${block.code}: 重复出现，取最后一行');
      }
      blocks[block.code] = PackageBlock(
        code: block.code,
        name: block.name,
        nameEn: block.nameEn,
        nameZh: block.nameZh,
        colorHex: block.colorHex,
        variantOf: block.variantOf,
        reviewed: block.reviewed,
        textures: block.textures,
        icon: block.icon,
        tags: _knownTags(block.tags, vocab, block.code, problems),
      );
      for (final texture in block.textures) {
        referenced.add(texture.hash);
      }
      final main = block.icon;
      if (main != null) referenced.add(main);
    }

    final textures = <String, Uint8List>{};
    var textureBytes = 0;
    for (final hash in referenced) {
      final entry = textureEntries[hash];
      if (entry == null) {
        problems.add('贴图缺失: $hash');
        continue;
      }
      final data = entry.readBytes();
      if (data == null) {
        problems.add('贴图读取失败: $hash');
        continue;
      }
      textureBytes += data.length;
      if (textureBytes > maxTextureBytes) {
        throw const ImportException('数据包贴图总量超出上限');
      }
      textures[hash] = data;
    }

    return ParsedPackage(
      manifest: manifest,
      blocks: blocks.values.toList(growable: false),
      textures: textures,
      problems: problems,
    );
  }

  static List<PackageTag> _knownTags(
    List<PackageTag> refs,
    _Vocab vocab,
    String code,
    List<String> problems,
  ) {
    final known = <PackageTag>[];
    for (final tag in refs) {
      if (vocab.knows(tag.ref)) {
        known.add(tag);
      } else {
        problems.add('$code: 标签 ${tag.ref} 不在 manifest 词表里');
      }
    }
    return known;
  }

  static Map<String, Object?> _decodeObject(Uint8List? bytes, String name) {
    if (bytes == null) throw ImportException('$name 读取失败');

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw ImportException('$name 不是合法 JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw ImportException('$name 期望一个 JSON 对象');
    }
    return decoded;
  }
}

/// manifest 声明的词表，用来校验方块行里的标签引用。
final class _Vocab {
  _Vocab(PackageManifest manifest)
    : keys = {for (final tag in manifest.tags) '${tag.category}:${tag.code}'},
      codes = {for (final tag in manifest.tags) tag.code},
      names = {for (final tag in manifest.tags) tag.name};

  final Set<String> keys;
  final Set<String> codes;
  final Set<String> names;

  bool knows(String ref) {
    final index = ref.indexOf(':');
    if (index > 0 && index < ref.length - 1) {
      return keys.contains(ref);
    }
    return codes.contains(ref) || names.contains(ref);
  }
}
