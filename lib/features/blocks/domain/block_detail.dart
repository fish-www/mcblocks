import 'block_tag.dart';
import 'block_texture_entry.dart';

/// 变体或基础方块的引用，带显示名。
final class BlockRef {
  const BlockRef({
    required this.code,
    this.name,
    this.nameZh,
    this.nameEn,
  });

  final String code;
  final String? name;
  final String? nameZh;
  final String? nameEn;

  /// `name > name_zh > name_en > code`
  String get displayName => name ?? nameZh ?? nameEn ?? code;
}

/// 详情页需要的全部字段。
final class BlockDetail {
  const BlockDetail({
    required this.id,
    required this.code,
    required this.reviewed,
    required this.variantCount,
    required this.tags,
    required this.variants,
    required this.textures,
    this.iconHash,
    this.name,
    this.nameEn,
    this.nameZh,
    this.note,
    this.colorHex,
    this.variantOf,
    this.updatedAt,
  });

  final int id;
  final String code;
  final bool reviewed;
  final int variantCount;

  /// 全部标签，包含原版标签。
  final List<BlockTag> tags;

  /// 直接变体，按 code 排序。
  final List<BlockRef> variants;

  /// 材质列表，按 `sort` 排序。
  final List<BlockTextureEntry> textures;

  /// 展示图标 hash；空气这类没有图标的方块为空。
  final String? iconHash;

  final String? name;
  final String? nameEn;
  final String? nameZh;
  final String? note;
  final String? colorHex;
  final BlockRef? variantOf;
  final DateTime? updatedAt;

  /// `name > name_zh > name_en > code`
  String get displayName => name ?? nameZh ?? nameEn ?? code;

  List<BlockTag> get vanillaTags =>
      [for (final tag in tags) if (tag.isVanilla) tag];

  List<BlockTag> get manualTags =>
      [for (final tag in tags) if (!tag.isVanilla) tag];
}
