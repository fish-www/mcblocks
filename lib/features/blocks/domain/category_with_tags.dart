/// 一个分类和它下面的全部标签，筛选面板用。
final class CategoryWithTags {
  const CategoryWithTags({
    required this.code,
    required this.name,
    required this.single,
    required this.ordered,
    required this.tags,
  });

  final String code;
  final String name;
  final bool single;
  final bool ordered;
  final List<TagOption> tags;

  bool get isVanilla => code == 'vanilla';
}

final class TagOption {
  const TagOption({required this.code, required this.name, required this.sort});

  final String code;
  final String name;
  final int sort;

  /// 筛选用的 `分类:标签`，和 JSONL / 数据包一致。
  String refIn(String category) => '$category:$code';
}
