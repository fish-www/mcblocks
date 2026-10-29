/// 列表排序方式。
enum BlockSort {
  updatedDesc('最近更新'),
  codeAsc('code ↑'),
  codeDesc('code ↓'),
  nameAsc('名称');

  const BlockSort(this.label);

  final String label;
}

/// 选中的标签怎么组合。
enum TagMode {
  /// 全部都要有。
  all('包含'),

  /// 命中任意一个就行。
  any('任一'),

  /// 一个都不能有。
  none('排除');

  const TagMode(this.label);

  final String label;
}

/// 一次方块查询的全部条件。
///
/// 标签条件用和 JSONL 一致的 `分类:标签` 写法；
/// 只写 `标签` 时同时匹配 code 和 name。
final class BlockFilter {
  const BlockFilter({
    this.search = '',
    this.sort = BlockSort.updatedDesc,
    this.mode = TagMode.all,
    this.tags = const [],
    this.range,
    this.unreviewedOnly = false,
    this.collapse = true,
    this.limit = 200,
    this.offset = 0,
  });

  /// 匹配 `code`、`name`、`name_zh`、`name_en`。
  final String search;

  final BlockSort sort;

  /// 选中的标签，全部按 [mode] 组合。
  final List<String> tags;

  final TagMode mode;

  final TagRange? range;
  final bool unreviewedOnly;

  /// 折叠模式只返回基础方块，标签条件作用于整个变体家族。
  final bool collapse;

  final int limit;
  final int offset;

  BlockFilter copyWith({
    String? search,
    BlockSort? sort,
    TagMode? mode,
    List<String>? tags,
    TagRange? range,
    bool clearRange = false,
    bool? unreviewedOnly,
    bool? collapse,
    int? limit,
    int? offset,
  }) {
    return BlockFilter(
      search: search ?? this.search,
      sort: sort ?? this.sort,
      mode: mode ?? this.mode,
      tags: tags ?? this.tags,
      range: clearRange ? null : range ?? this.range,
      unreviewedOnly: unreviewedOnly ?? this.unreviewedOnly,
      collapse: collapse ?? this.collapse,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}

/// `ordered` 类别按 `tag.sort` 过滤，含两端。
final class TagRange {
  const TagRange({
    required this.category,
    required this.from,
    required this.to,
  });

  final String category;
  final int from;
  final int to;
}
