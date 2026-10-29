import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../blocks/domain/category_with_tags.dart';
import '../../blocks/domain/patch.dart';
import '../../blocks/ui/blocks_providers.dart';
import '../data/vocab_writer.dart';

/// 词表：看分类和标签，补新的。
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
            data: (items) => ListView(
              children: [
                for (final category in items)
                  _CategoryTile(category: category),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createCategory(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<_CategoryDraft>(
      context: context,
      builder: (_) => const _CreateCategoryDialog(),
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
          ),
      '分类 ${draft.name} 已创建',
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});

  final CategoryWithTags category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ExpansionTile(
      title: Row(
        children: [
          Text(category.name),
          const SizedBox(width: 8),
          Text(
            '${category.code} · ${category.tags.length} 个标签',
            style: theme.textTheme.labelSmall,
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
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in category.tags)
                Chip(
                  label: Text(tag.name),
                  visualDensity: VisualDensity.compact,
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('新建标签'),
                onPressed: () => _createTag(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _createTag(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<_TagDraft>(
      context: context,
      builder: (_) => _CreateTagDialog(category: category),
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

/// 写入后刷新词表和方块列表。
Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  Future<int> Function() action,
  String message,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    ref.invalidate(categoriesProvider);
    ref.invalidate(blockPageProvider);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  } on PatchException catch (error) {
    final text = error.hint == null
        ? error.message
        : '${error.message}\n${error.hint}';
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }
}

class _CategoryDraft {
  const _CategoryDraft({
    required this.code,
    required this.name,
    required this.single,
    required this.ordered,
  });

  final String code;
  final String name;
  final bool single;
  final bool ordered;
}

class _CreateCategoryDialog extends StatefulWidget {
  const _CreateCategoryDialog();

  @override
  State<_CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<_CreateCategoryDialog> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _single = true;
  bool _ordered = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建分类'),
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
                hintText: '例：texture',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例：纹理',
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
          onPressed: () => Navigator.pop(
            context,
            _CategoryDraft(
              code: _code.text,
              name: _name.text,
              single: _single,
              ordered: _ordered,
            ),
          ),
          child: const Text('创建'),
        ),
      ],
    );
  }
}

class _TagDraft {
  const _TagDraft({required this.code, required this.name});

  final String code;
  final String name;
}

class _CreateTagDialog extends StatefulWidget {
  const _CreateTagDialog({required this.category});

  final CategoryWithTags category;

  @override
  State<_CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends State<_CreateTagDialog> {
  final _code = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('在「${widget.category.name}」新建标签'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _code,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '名称'),
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
            _TagDraft(code: _code.text, name: _name.text),
          ),
          child: const Text('创建'),
        ),
      ],
    );
  }
}
