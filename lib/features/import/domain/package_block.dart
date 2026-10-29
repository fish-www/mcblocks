import '../../blocks/domain/tag_source.dart';
import 'import_exception.dart';

/// `blocks.jsonl` 的一行。
final class PackageBlock {
  const PackageBlock({
    required this.code,
    required this.textures,
    required this.tags,
    this.icon,
    this.name,
    this.nameEn,
    this.nameZh,
    this.colorHex,
    this.variantOf,
    this.reviewed = false,
  });

  final String code;
  final String? name;
  final String? nameEn;
  final String? nameZh;
  final String? colorHex;

  /// 基础方块的 code，没有变体关系时为空。
  final String? variantOf;
  final bool reviewed;

  /// 模型解析出的全部材质，按 `sort` 排序。
  final List<PackageTexture> textures;

  /// 展示图标 hash。没有可用贴图的方块为空。
  final String? icon;

  /// 标签和来源。导入时 `auto` 只作用于新方块，
  /// `vanilla` / `user` 对已有方块也补，但低优先级不覆盖高优先级。
  final List<PackageTag> tags;

  factory PackageBlock.fromJson(Map<String, Object?> json) {
    final code = json['code'];
    if (code is! String || code.isEmpty) {
      throw const ImportException('方块行缺少 code');
    }

    final textures = <PackageTexture>[];
    final rawTextures = json['textures'];
    if (rawTextures is List) {
      for (final item in rawTextures) {
        if (item is Map<String, Object?>) {
          textures.add(PackageTexture.fromJson(item));
        }
      }
    }

    final rawTags = json['tags'];
    return PackageBlock(
      code: code,
      name: json['name'] as String?,
      nameEn: json['name_en'] as String?,
      nameZh: json['name_zh'] as String?,
      colorHex: json['color_hex'] as String?,
      variantOf: json['variant_of'] as String?,
      reviewed: json['reviewed'] == 1 || json['reviewed'] == true,
      textures: textures,
      icon: json['icon'] as String?,
      tags: [
        if (rawTags is List)
          for (final item in rawTags)
            if (item is Map<String, Object?>) PackageTag.fromJson(item),
      ],
    );
  }
}

/// 数据包里的一条材质映射。
final class PackageTexture {
  const PackageTexture({
    required this.key,
    required this.hash,
    required this.sort,
  });

  final String key;
  final String hash;
  final int sort;

  factory PackageTexture.fromJson(Map<String, Object?> json) =>
      PackageTexture(
        key: json['key'] as String? ?? '',
        hash: json['hash'] as String? ?? '',
        sort: json['sort'] as int? ?? 0,
      );
}

/// 一个标签引用。`tag` 是 `分类:标签` 或裸标签，`source` 是
/// `auto` / `vanilla` / `user`，缺省为 `auto`。
final class PackageTag {
  const PackageTag(this.ref, this.source);

  final String ref;
  final TagSource source;

  factory PackageTag.fromJson(Map<String, Object?> json) {
    final ref = json['tag'];
    if (ref is! String || ref.isEmpty) {
      throw const ImportException('标签项缺少 tag');
    }

    final source = switch (json['source']) {
      null || 'auto' => TagSource.auto,
      'vanilla' => TagSource.vanilla,
      'user' => TagSource.user,
      final other => throw ImportException('未知的标签来源 $other'),
    };

    return PackageTag(ref, source);
  }
}
