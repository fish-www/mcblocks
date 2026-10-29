import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/block_filter.dart';
import '../../domain/category_with_tags.dart';
import '../blocks_providers.dart';

/// 筛选面板：先选标签组合方式，再点标签。
class FilterPanel extends ConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(blockFilterControllerProvider);
    final controller = ref.read(blockFilterControllerProvider.notifier);
    final categories = ref.watch(categoriesProvider);

    return categories.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('词表读取失败：$error'),
      ),
      data: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text('标签模式', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(width: 8),
                SegmentedButton<TagMode>(
                  segments: [
                    for (final mode in TagMode.values)
                      ButtonSegment(value: mode, label: Text(mode.label)),
                  ],
                  selected: {filter.mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (values) =>
                      controller.setMode(values.first),
                ),
                const SizedBox(width: 16),
                _Toggle(
                  label: '只看未审核',
                  value: filter.unreviewedOnly,
                  onChanged: controller.setUnreviewedOnly,
                ),
                const SizedBox(width: 12),
                _Toggle(
                  label: '折叠变体',
                  value: filter.collapse,
                  onChanged: controller.setCollapse,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: controller.clear,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('清除筛选'),
                ),
              ],
            ),
          ),
          for (final category in items)
            if (category.isVanilla)
              _VanillaCategory(
                category: category,
                filter: filter,
                onToggle: controller.toggleTag,
              )
            else
              _CategorySection(
                category: category,
                filter: filter,
                onToggle: controller.toggleTag,
                onRange: controller.setRange,
              ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.filter,
    required this.onToggle,
    required this.onRange,
  });

  final CategoryWithTags category;
  final BlockFilter filter;
  final ValueChanged<String> onToggle;
  final ValueChanged<TagRange?> onRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = filter.range?.category == category.code ? filter.range : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(category.name, style: theme.textTheme.labelLarge),
              if (category.ordered) ...[
                const SizedBox(width: 12),
                _RangePicker(
                  category: category,
                  range: range,
                  onChanged: onRange,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in category.tags)
                _TagChip(
                  category: category,
                  tag: tag,
                  filter: filter,
                  onToggle: onToggle,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VanillaCategory extends StatelessWidget {
  const _VanillaCategory({
    required this.category,
    required this.filter,
    required this.onToggle,
  });

  final CategoryWithTags category;
  final BlockFilter filter;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        '${category.name}标签 (${category.tags.length})',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in category.tags)
              _TagChip(
                category: category,
                tag: tag,
                filter: filter,
                onToggle: onToggle,
              ),
          ],
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.category,
    required this.tag,
    required this.filter,
    required this.onToggle,
  });

  final CategoryWithTags category;
  final TagOption tag;
  final BlockFilter filter;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final ref = tag.refIn(category.code);
    return FilterChip(
      label: Text(tag.name),
      selected: filter.tags.contains(ref),
      onSelected: (_) => onToggle(ref),
    );
  }
}

/// 有序分类的区间选择，两端都含。
class _RangePicker extends StatelessWidget {
  const _RangePicker({
    required this.category,
    required this.range,
    required this.onChanged,
  });

  final CategoryWithTags category;
  final TagRange? range;
  final ValueChanged<TagRange?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (category.tags.isEmpty) return const SizedBox.shrink();

    final sorted = [...category.tags]..sort((a, b) => a.sort.compareTo(b.sort));
    final from = range?.from ?? sorted.first.sort;
    final to = range?.to ?? sorted.last.sort;

    Widget dropdown(int value, ValueChanged<int?> onPicked) =>
        DropdownButton<int>(
          value: value,
          isDense: true,
          underline: const SizedBox.shrink(),
          style: Theme.of(context).textTheme.bodySmall,
          items: [
            for (final tag in sorted)
              DropdownMenuItem(value: tag.sort, child: Text(tag.name)),
          ],
          onChanged: onPicked,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dropdown(from, (value) {
          if (value != null) {
            onChanged(
              TagRange(
                category: category.code,
                from: value,
                to: value > to ? value : to,
              ),
            );
          }
        }),
        const Text(' ~ '),
        dropdown(to, (value) {
          if (value != null) {
            onChanged(
              TagRange(
                category: category.code,
                from: value < from ? value : from,
                to: value,
              ),
            );
          }
        }),
        if (range != null)
          IconButton(
            tooltip: '清除区间',
            iconSize: 16,
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }
}
