import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/blocks_repository.dart';
import '../domain/block_detail.dart';
import '../domain/block_filter.dart';
import '../domain/block_page.dart';
import '../domain/category_with_tags.dart';

part 'blocks_providers.g.dart';

/// 当前筛选条件。列表和计数都从这里派生。
@riverpod
class BlockFilterController extends _$BlockFilterController {
  static const int pageSize = 20;

  Timer? _debounce;

  @override
  BlockFilter build() {
    ref.onDispose(() => _debounce?.cancel());
    return const BlockFilter(limit: pageSize);
  }

  /// 输入停下来再查，避免每敲一个字打一次库。
  void setSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 200),
      () => state = state.copyWith(
        search: value,
        limit: pageSize,
        offset: 0,
      ),
    );
  }

  /// 标签只有选中和未选中，怎么组合由 [TagMode] 决定。
  void toggleTag(String ref) {
    final tags = [...state.tags];
    if (!tags.remove(ref)) tags.add(ref);
    state = state.copyWith(tags: tags, limit: pageSize, offset: 0);
  }

  void setSort(BlockSort sort) =>
      state = state.copyWith(sort: sort, limit: pageSize, offset: 0);

  void setMode(TagMode mode) =>
      state = state.copyWith(mode: mode, limit: pageSize, offset: 0);

  void setRange(TagRange? range) {
    state = range == null
        ? state.copyWith(clearRange: true, limit: pageSize, offset: 0)
        : state.copyWith(range: range, limit: pageSize, offset: 0);
  }

  void setUnreviewedOnly(bool value) =>
      state = state.copyWith(unreviewedOnly: value, limit: pageSize, offset: 0);

  void setCollapse(bool value) =>
      state = state.copyWith(collapse: value, limit: pageSize, offset: 0);

  int get page => state.offset ~/ pageSize;

  void goToPage(int target) {
    final page = target < 0 ? 0 : target;
    state = state.copyWith(limit: pageSize, offset: page * pageSize);
  }

  void firstPage() => goToPage(0);

  void previousPage() => goToPage(page - 1);

  void nextPage() => goToPage(page + 1);

  void lastPage(int total) => goToPage(lastPageIndex(total));

  void jumpTo(int page, int total) =>
      goToPage(page > lastPageIndex(total) ? lastPageIndex(total) : page);

  /// 总页数减一，至少为 0。
  static int lastPageIndex(int total) =>
      total <= 0 ? 0 : ((total - 1) ~/ pageSize);

  void clear() => state = const BlockFilter(limit: pageSize);

  /// 从详情页点标签跳过来：只按这个标签筛，其它条件清掉。
  void applyTag(String ref) =>
      state = BlockFilter(limit: pageSize, tags: [ref]);
}

@riverpod
Future<BlockPage> blockPage(Ref ref) {
  final filter = ref.watch(blockFilterControllerProvider);
  return ref.watch(blocksRepositoryProvider).query(filter);
}

@riverpod
Future<List<CategoryWithTags>> categories(Ref ref) =>
    ref.watch(blocksRepositoryProvider).categories();

@riverpod
Future<BlockDetail?> blockDetail(Ref ref, String code) =>
    ref.watch(blocksRepositoryProvider).detail(code);

/// 宽屏时右侧详情面板显示哪个方块。
@riverpod
class SelectedBlock extends _$SelectedBlock {
  @override
  String? build() => null;

  void select(String? code) => state = code;
}
