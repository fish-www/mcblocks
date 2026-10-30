import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../blocks/data/blocks_repository.dart';
import '../../blocks/domain/category_with_tags.dart';
import '../../blocks/domain/patch.dart';
import '../../blocks/ui/blocks_providers.dart';
import '../data/vocab_writer.dart';

/// 词表：看分类和标签，增改删。
class VocabPage extends ConsumerWidget {
  const VocabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('词表', style: theme.textTheme.titleMedium),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _createCategory(context, ref),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('新建分类'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: categories.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('读取失败：$error')),
            data: (items) => ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              onReorderItem: (oldIndex, newIndex) =>
                  _reorderCategories(context, ref, items, oldIndex, newIndex),
              itemBuilder: (context, index) => _CategoryTile(
                key: ValueKey(items[index].code),
                index: index,
                category: items[index],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createCategory(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<_CategoryDraft>(
      context: context,
      builder: (_) => const _CategoryDialog(),
    );
    if (draft == null || !context.mounted) return;

    await _run(
      context,
      ref,
      () => ref
          .read(vocabWriterProvider)
          .createCategory(
            code: draft.code,
            name: draft.name,
            single: draft.single,
            ordered: draft.ordered,
            sort: draft.sort,
          ),
      '分类 ${draft.name} 已创建',
    );
  }

  Future<void> _reorderCategories(
    BuildContext context,
    WidgetRef ref,
    List<CategoryWithTags> items,
    int oldIndex,
    int newIndex,
  ) async {
    // `vanilla` 永远在末尾，只在其余分类之间排。
    final codes = [
      for (final item in items)
        if (!item.isVanilla) item.code,
    ];
    final moved = items[oldIndex].code;
    if (moved == 'vanilla') return;

    codes.remove(moved);
    // `onReorderItem` 已经把 newIndex 算成移除后的下标。
    final target = newIndex > codes.length ? codes.length : newIndex;
    codes.insert(target, moved);

    await _run(
      context,
      ref,
      () => ref
          .read(vocabWriterProvider)
          .reorderCategories(codes, moved: moved),
      '分类顺序已更新',
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({
    required this.index,
    required this.category,
    super.key,
  });

  final int index;
  final CategoryWithTags category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ExpansionTile(
      leading: category.isVanilla
          ? null
          : ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_indicator),
            ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${category.code} · ${category.tags.length} 个标签 · '
              'sort ${category.sort}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
          if (category.single) ...[
            const SizedBox(width: 8),
            _Badge(text: '单选'),
          ],
          if (category.ordered) ...[
            const SizedBox(width: 4),
            _Badge(text: '有序'),
          ],
        ],
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        // 三个动作同一行、同一格式；窄屏放不下就自动换行。
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            children: [
              TextButton.icon(
                onPressed: () => _createTag(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新建标签'),
              ),
              TextButton.icon(
                onPressed: () => _editCategory(context, ref),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑分类'),
              ),
              TextButton.icon(
                onPressed: () => _deleteCategory(context, ref),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除分类'),
              ),
            ],
          ),
        ),
        if (category.tags.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            itemCount: category.tags.length,
            onReorderItem: (oldIndex, newIndex) =>
                _reorderTags(context, ref, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final tag = category.tags[index];
              return Padding(
                key: ValueKey(tag.code),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator, size: 18),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InputChip(
                          label: Text(tag.name),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _editTag(context, ref, tag),
                          onDeleted: () => _deleteTag(context, ref, tag),
                        ),
                      ),
                    ),
                    Text(
                      'sort ${tag.sort}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _reorderTags(
    BuildContext context,
    WidgetRef ref,
    int oldIndex,
    int newIndex,
  ) async {
    final codes = [for (final tag in category.tags) tag.code];
    final moved = codes.removeAt(oldIndex);
    codes.insert(newIndex, moved);

    await _run(
      context,
      ref,
      () => ref
          .read(vocabWriterProvider)
          .reorderTags(category.code, codes, moved: moved),
      '标签顺序已更新',
    );
  }

  Future<void> _editCategory(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<_CategoryDraft>(
      context: context,
      builder: (_) => _CategoryDialog(existing: category),
    );
    if (draft == null || !context.mounted) return;

    await _run(
      context,
      ref,
      () => ref
          .read(vocabWriterProvider)
          .updateCategory(
            category.code,
            newCode: draft.code,
            name: draft.name,
            single: draft.single,
            ordered: draft.ordered,
            sort: draft.sort,
          ),
      '分类 ${draft.name} 已保存',
    );
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref) async {
    final used = await ref
        .read(blocksRepositoryProvider)
        .categoryUsage(category.code);
    if (!context.mounted) return;

    final ok = await _confirmDelete(
      context,
      title: '删除分类「${category.name}」？',
      message:
          '它下面有 ${category.tags.length} 个标签，这些标签一共用在 $used 个方块上。'
          '删除会同时移除这些标注，且不可撤销。',
    );
    if (!ok || !context.mounted) return;

    await _run(
      context,
      ref,
      () => ref.read(vocabWriterProvider).deleteCategory(category.code),
      '分类 ${category.name} 已删除',
    );
  }

  Future<void> _editTag(
    BuildContext context,
    WidgetRef ref,
    TagOption tag,
  ) async {
    final draft = await showDialog<_TagDraft>(
      context: context,
      builder: (_) => _TagDialog(category: category, existing: tag),
    );
    if (draft == null || !context.mounted) return;

    await _run(
      context,
      ref,
      () => ref
          .read(vocabWriterProvider)
          .updateTag(
            category.code,
            tag.code,
            newCode: draft.code,
            name: draft.name,
            sort: draft.sort,
          ),
      '标签 ${draft.name} 已保存',
    );
  }

  Future<void> _deleteTag(
    BuildContext context,
    WidgetRef ref,
    TagOption tag,
  ) async {
    final used = await ref
        .read(blocksRepositoryProvider)
        .tagUsage(category.code, tag.code);
    if (!context.mounted) return;

    final ok = await _confirmDelete(
      context,
      title: '删除标签「${tag.name}」？',
      message: used == 0
          ? '没有方块在用这个标签。'
          : '有 $used 个方块在用这个标签，删除会同时移除这些标注，且不可撤销。',
    );
    if (!ok || !context.mounted) return;

    await _run(
      context,
      ref,
      () => ref.read(vocabWriterProvider).deleteTag(category.code, tag.code),
      '标签 ${tag.name} 已删除',
    );
  }

  Future<void> _createTag(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<_TagDraft>(
      context: context,
      builder: (_) => _TagDialog(category: category),
    );
    if (draft == null || !context.mounted) return;

    await _run(
      context,
      ref,
      () => ref
          .read(vocabWriterProvider)
          .createTag(
            categoryCode: category.code,
            code: draft.code,
            name: draft.name,
            sort: draft.sort,
          ),
      '标签 ${draft.name} 已创建',
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: theme.textTheme.labelSmall),
    );
  }
}

/// 写入后刷新词表、方块列表和详情。
Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
  String message,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    ref.invalidate(categoriesProvider);
    ref.invalidate(blockPageProvider);
    ref.invalidate(blockDetailProvider);
    // 改名或删掉的标签可能还留在筛选里，先摘掉。
    await ref.read(blockFilterControllerProvider.notifier).dropStaleTags();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  } on PatchException catch (error) {
    final text = error.hint == null
        ? error.message
        : '${error.message}\n${error.hint}';
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }
}

/// 删除前的确认框。默认 `false`。
Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _CategoryDraft {
  const _CategoryDraft({
    required this.code,
    required this.name,
    required this.single,
    required this.ordered,
    this.sort,
  });

  final String code;
  final String name;
  final bool single;
  final bool ordered;
  final int? sort;
}

/// 新建和编辑共用。`existing` 为空就是新建。
class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.existing});

  final CategoryWithTags? existing;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _code = TextEditingController(text: widget.existing?.code);
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _sort = TextEditingController(
    text: widget.existing?.sort.toString(),
  );
  late bool _single = widget.existing?.single ?? true;
  late bool _ordered = widget.existing?.ordered ?? false;
  String? _sortError;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _sort.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _sort.text.trim();
    final sort = raw.isEmpty ? null : int.tryParse(raw);
    if (raw.isNotEmpty && sort == null) {
      setState(() => _sortError = 'sort 要写整数');
      return;
    }
    Navigator.pop(
      context,
      _CategoryDraft(
        code: _code.text,
        name: _name.text,
        single: _single,
        ordered: _ordered,
        sort: sort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? '编辑分类' : '新建分类'),
      scrollable: true,
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'code',
                hintText: '例：texture，留空就用名称',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例：纹理',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sort,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'sort',
                hintText: editing ? '列表顺序，小的在前' : '留空自动顺延',
                errorText: _sortError,
              ),
            ),
            SwitchListTile(
              value: _single,
              onChanged: (value) => setState(() => _single = value),
              title: const Text('单选'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _ordered,
              onChanged: (value) => setState(() => _ordered = value),
              title: const Text('有序（可做区间筛选）'),
              contentPadding: EdgeInsets.zero,
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
          onPressed: _submit,
          child: Text(editing ? '保存' : '创建'),
        ),
      ],
    );
  }
}

class _TagDraft {
  const _TagDraft({required this.code, required this.name, this.sort});

  final String code;
  final String name;
  final int? sort;
}

/// 新建和编辑共用。`existing` 为空就是新建。
class _TagDialog extends StatefulWidget {
  const _TagDialog({required this.category, this.existing});

  final CategoryWithTags category;
  final TagOption? existing;

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late final _code = TextEditingController(text: widget.existing?.code);
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _sort = TextEditingController(
    text: widget.existing?.sort.toString(),
  );
  String? _sortError;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _sort.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _sort.text.trim();
    final sort = raw.isEmpty ? null : int.tryParse(raw);
    if (raw.isNotEmpty && sort == null) {
      setState(() => _sortError = 'sort 要写整数');
      return;
    }
    Navigator.pop(
      context,
      _TagDraft(code: _code.text, name: _name.text, sort: sort),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final title = editing ? '编辑标签' : '在「${widget.category.name}」新建标签';

    return AlertDialog(
      title: Text(title),
      scrollable: true,
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'code',
                hintText: '留空就用名称',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sort,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'sort',
                hintText: widget.category.ordered
                    ? '有序分类里必须唯一，留空自动顺延'
                    : '列表顺序，小的在前；留空自动顺延',
                errorText: _sortError,
              ),
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
          onPressed: _submit,
          child: Text(editing ? '保存' : '创建'),
        ),
      ],
    );
  }
}
