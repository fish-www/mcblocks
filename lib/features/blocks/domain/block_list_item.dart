import 'block_tag.dart';

/// 方块列表的一行。[id] 只在数据层内部和 UI 的 key 里出现，
/// 对外标识只用 `code`。
final class BlockListItem {
  const BlockListItem({
    required this.id,
    required this.code,
    required this.reviewed,
    required this.variantCount,
    required this.tags,
    this.name,
    this.nameZh,
    this.nameEn,
    this.colorHex,
    this.iconHash,
  });

  final int id;
  final String code;
  final bool reviewed;

  /// 直接变体数量；非折叠模式恒为 0。
  final int variantCount;

  /// 标签，按分类、标签的 sort 排序。
  final List<BlockTag> tags;

  /// 列表只显示非原版标签，原版标签留给详情页。
  List<BlockTag> get manualTags =>
      [for (final tag in tags) if (!tag.isVanilla) tag];

  List<BlockTag> get vanillaTags =>
      [for (final tag in tags) if (tag.isVanilla) tag];

  final String? name;
  final String? nameZh;
  final String? nameEn;
  final String? colorHex;

  /// 展示图标 hash，文件在 `textures/sha/<hash 前两位>/<hash>.webp`。
  /// 空气这类没有图标的方块为空。
  final String? iconHash;

  /// `name > name_zh > name_en > code`
  String get displayName => name ?? nameZh ?? nameEn ?? code;
}
