import 'dart:typed_data';

import 'package_block.dart';
import 'package_manifest.dart';

/// 解压并解析完成的数据包，不持有任何文件句柄。
final class ParsedPackage {
  const ParsedPackage({
    required this.manifest,
    required this.blocks,
    required this.textures,
    required this.problems,
  });

  final PackageManifest manifest;
  final List<PackageBlock> blocks;

  /// 贴图 hash -> webp 字节。
  final Map<String, Uint8List> textures;

  /// 解析阶段发现的可跳过问题，逐条给人看。
  final List<String> problems;
}
