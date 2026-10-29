import 'tag_source.dart';

/// 一个方块身上的标签，带分类和标签的显示名。
final class BlockTag {
  const BlockTag({
    required this.categoryCode,
    required this.categoryName,
    required this.tagCode,
    required this.tagName,
    required this.source,
  });

  final String categoryCode;
  final String categoryName;
  final String tagCode;
  final String tagName;
  final TagSource source;

  /// 筛选和写回用的 `分类code:标签code`。
  String get ref => '$categoryCode:$tagCode';

  /// 界面上的 `分类名:标签名`。
  String get label => '$categoryName:$tagName';

  bool get isVanilla => categoryCode == 'vanilla';
}
