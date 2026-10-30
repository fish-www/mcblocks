import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/block_filter.dart';
import '../domain/block_list_item.dart';
import '../domain/block_page.dart';
import '../data/block_writer.dart';
import '../domain/patch.dart';
import 'blocks_providers.dart';
import 'widgets/block_detail_panel.dart';
import 'widgets/block_thumbnail.dart';
import 'widgets/filter_panel.dart';

/// 宽屏（>= 1000）列表和详情并排，窄屏列表独占，详情走独立页面。
class BlocksPage extends ConsumerStatefulWidget {
  const BlocksPage({super.key});

  @override
  ConsumerState<BlocksPage> createState() => _BlocksPageState();
}

class _BlocksPageState extends ConsumerState<BlocksPage> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _filterOpen = false;

  /// 翻页/刷新时先留着上一页，避免列表整块闪一下。
  BlockPage? _lastPage;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(blockPageProvider);
    final filter = ref.watch(blockFilterControllerProvider);
    final selected = ref.watch(selectedBlockProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final hasFilter =
        filter.tags.isNotEmpty ||
        filter.range != null ||
        filter.search.trim().isNotEmpty ||
        filter.unreviewedOnly;

    final data = page.asData?.value;
    if (data != null) _lastPage = data;
    final shown = data ?? _lastPage;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text('方块', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _createBlock,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新建方块'),
              ),
            ],
          ),
        ),
        _Toolbar(
          search: _search,
          sort: filter.sort,
          onSort: ref.read(blockFilterControllerProvider.notifier).setSort,
          filterOpen: _filterOpen,
          filterCount: filter.tags.length,
          onSearch: ref.read(blockFilterControllerProvider.notifier).setSearch,
          onToggleFilter: () => setState(() => _filterOpen = !_filterOpen),
        ),
        if (_filterOpen)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: const SingleChildScrollView(child: FilterPanel()),
          ),
        const Divider(height: 1),
        // 点面板以外的任何地方、或者拖动列表，都当作「看完了」，自动收起。
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _closeFilter(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (page.isLoading && shown != null)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: shown == null
                      ? (page.hasError && !page.isLoading
                            ? Center(child: Text('读取失败：${page.error}'))
                            : const Center(child: CircularProgressIndicator()))
                      : shown.items.isEmpty
                      ? _EmptyState(hasFilter: hasFilter)
                      : wide
                      ? Row(
                          children: [
                            Expanded(child: _list(shown, wide)),
                            const VerticalDivider(width: 1),
                            SizedBox(
                              width: 380,
                              child: selected == null
                                  ? const Center(child: Text('选一个方块看详情'))
                                  : BlockDetailPanel(
                                      code: selected,
                                      onSelect: (code) => ref
                                          .read(selectedBlockProvider.notifier)
                                          .select(code),
                                    ),
                            ),
                          ],
                        )
                      : _list(shown, wide),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _closeFilter() {
    if (_filterOpen) setState(() => _filterOpen = false);
  }

  Future<void> _createBlock() async {
    final draft = await showDialog<_NewBlockDraft>(
      context: context,
      builder: (_) => const _NewBlockDialog(),
    );
    if (draft == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(blockWriterProvider)
          .createBlock(
            code: draft.code,
            name: draft.name,
            nameZh: draft.nameZh,
          );
      ref.invalidate(blockPageProvider);
      messenger.showSnackBar(SnackBar(content: Text('已创建 ${draft.code}')));
    } on PatchException catch (error) {
      final text = error.hint == null
          ? error.message
          : '${error.message}\n${error.hint}';
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Widget _list(BlockPage page, bool wide) {
    final filter = ref.watch(blockFilterControllerProvider);
    final pageIndex = filter.offset ~/ BlockFilterController.pageSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '共 ${page.total} 个方块',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: _scroll,
            itemCount: page.items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _BlockTile(
              block: page.items[index],
              onTap: () {
                final code = page.items[index].code;
                if (wide) {
                  ref.read(selectedBlockProvider.notifier).select(code);
                } else {
                  context.go('/blocks/$code');
                }
              },
            ),
          ),
        ),
        _PaginationBar(
          page: pageIndex,
          total: page.total,
          onPage: (target) {
            ref
                .read(blockFilterControllerProvider.notifier)
                .jumpTo(target, page.total);
            if (_scroll.hasClients) _scroll.jumpTo(0);
          },
        ),
      ],
    );
  }
}

class _PaginationBar extends StatefulWidget {
  const _PaginationBar({
    required this.page,
    required this.total,
    required this.onPage,
  });

  final int page;
  final int total;
  final ValueChanged<int> onPage;

  @override
  State<_PaginationBar> createState() => _PaginationBarState();
}

class _PaginationBarState extends State<_PaginationBar> {
  final TextEditingController _jump = TextEditingController();

  @override
  void dispose() {
    _jump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageCount = BlockFilterController.lastPageIndex(widget.total) + 1;
    final isFirst = widget.page <= 0;
    final isLast = widget.page >= pageCount - 1;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: '首页',
            onPressed: isFirst ? null : () => widget.onPage(0),
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: '上一页',
            onPressed: isFirst ? null : () => widget.onPage(widget.page - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '第 ${widget.page + 1} / $pageCount 页',
            style: theme.textTheme.labelLarge,
          ),
          IconButton(
            tooltip: '下一页',
            onPressed: isLast ? null : () => widget.onPage(widget.page + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: '尾页',
            onPressed: isLast ? null : () => widget.onPage(pageCount - 1),
            icon: const Icon(Icons.last_page),
          ),
          const Spacer(),
          SizedBox(
            width: 72,
            child: TextField(
              controller: _jump,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '页码',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submitJump(pageCount),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => _submitJump(pageCount),
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }

  void _submitJump(int pageCount) {
    final raw = int.tryParse(_jump.text.trim());
    if (raw == null) return;
    final target = (raw - 1).clamp(0, pageCount - 1);
    _jump.clear();
    widget.onPage(target);
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.sort,
    required this.onSort,
    required this.filterOpen,
    required this.filterCount,
    required this.onSearch,
    required this.onToggleFilter,
  });

  final TextEditingController search;
  final BlockSort sort;
  final ValueChanged<BlockSort> onSort;
  final bool filterOpen;
  final int filterCount;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: search,
              onChanged: onSearch,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: '搜索名称或 code',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          DropdownButton<BlockSort>(
            value: sort,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final option in BlockSort.values)
                DropdownMenuItem(value: option, child: Text(option.label)),
            ],
            onChanged: (value) {
              if (value != null) onSort(value);
            },
          ),
          FilterChip(
            avatar: Icon(
              filterOpen ? Icons.filter_alt : Icons.filter_alt_outlined,
              size: 18,
            ),
            label: Text(filterCount == 0 ? '筛选' : '筛选 $filterCount'),
            selected: filterOpen || filterCount > 0,
            showCheckmark: false,
            onSelected: (_) => onToggleFilter(),
          ),
        ],
      ),
    );
  }
}

class _NewBlockDraft {
  const _NewBlockDraft({required this.code, this.name, this.nameZh});

  final String code;
  final String? name;
  final String? nameZh;
}

class _NewBlockDialog extends StatefulWidget {
  const _NewBlockDialog();

  @override
  State<_NewBlockDialog> createState() => _NewBlockDialogState();
}

class _NewBlockDialogState extends State<_NewBlockDialog> {
  final _code = TextEditingController();
  final _nameZh = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _nameZh.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建方块'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _code,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'code',
                hintText: '小写字母、数字、下划线',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameZh,
              decoration: const InputDecoration(labelText: '中文名'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '英文名'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _NewBlockDraft(
              code: _code.text.trim(),
              name: _name.text.trim(),
              nameZh: _nameZh.text.trim(),
            ),
          ),
          child: const Text('创建'),
        ),
      ],
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hasFilter) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('没有匹配的方块'),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: ref.read(blockFilterControllerProvider.notifier).clear,
              icon: const Icon(Icons.clear_all),
              label: const Text('清除筛选'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.grid_view_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text('还没有方块数据'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go('/import'),
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('导入数据包'),
          ),
        ],
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.block, required this.onTap});

  final BlockListItem block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = block.manualTags;
    final subtitle = [
      block.code,
      ...tags.map((tag) => tag.label),
    ].join('  ·  ');

    return ListTile(
      onTap: onTap,
      leading: BlockThumbnail(hash: block.iconHash),
      title: Row(
        children: [
          Flexible(child: Text(block.displayName)),
          if (block.variantCount > 0) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: '${block.variantCount} 个变体',
              child: Text(
                '+${block.variantCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
          if (!block.reviewed) ...[
            const SizedBox(width: 8),
            Text(
              '未审核',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      dense: true,
    );
  }
}
