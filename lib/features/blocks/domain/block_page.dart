import 'block_list_item.dart';

/// 一页方块和匹配到的总数。`items` 受 [BlockFilter.limit] 限制。
final class BlockPage {
  const BlockPage({required this.items, required this.total});

  final List<BlockListItem> items;
  final int total;
}
