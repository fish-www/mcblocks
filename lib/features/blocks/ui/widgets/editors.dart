import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/block_writer.dart';
import '../../domain/block_detail.dart';
import '../../domain/block_tag.dart';
import '../../domain/category_with_tags.dart';
import '../../domain/patch.dart';
import '../blocks_providers.dart';
import 'block_thumbnail.dart';

/// 标签管理：加、删都在这里。
Future<void> showTagEditor(BuildContext context, {required String code}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TagEditor(code: code),
  );
}

class _TagEditor extends ConsumerWidget {
  const _TagEditor({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(blockDetailProvider(code));

    return Dialog(
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: detail.when(
            loading: () => const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text('读取失败：$error'),
            data: (detail) => detail == null
                ? const Text('方块不存在')
                : _Body(detail: detail),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final BlockDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('标签 · ${detail.code}', style: theme.textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addTag(context, ref),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加标签'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (detail.tags.isEmpty)
          Text('还没有标签', style: theme.textTheme.bodySmall)
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final tag in detail.tags)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(tag.label),
                      subtitle: Text(tag.ref, style: theme.textTheme.labelSmall),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tag.isVanilla)
                            Chip(
                              label: Text(
                                '原版',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          IconButton(
                            tooltip: '删除',
                            iconSize: 18,
                            onPressed: () => _write(
                              context,
                              ref,
                              () => ref
                                  .read(blockWriterProvider)
                                  .apply(
                                    BlockPatch(
                                      code: detail.code,
                                      removeTags: [tag.ref],
                                    ),
                                  ),
                              '已移除 ${tag.label}',
                            ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ),
      ],
    );
  }

  Future<void> _addTag(BuildContext context, WidgetRef ref) async {
    final categories = await ref.read(categoriesProvider.future);
    if (!context.mounted) return;

    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _AddTagDialog(
        categories: categories,
        existing: {for (final tag in detail.tags) tag.ref},
      ),
    );
    if (picked == null || !context.mounted) return;

    await _write(
      context,
      ref,
      () => ref
          .read(blockWriterProvider)
          .apply(BlockPatch(code: detail.code, addTags: [PatchTag(picked)])),
      '已添加 $picked',
    );
  }

  Future<void> _write(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String message,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(blockDetailProvider(detail.code));
      ref.invalidate(blockPageProvider);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on PatchException catch (error) {
      final text = error.hint == null
          ? error.message
          : '${error.message}\n${error.hint}';
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }
  }
}

/// 选分类再选标签，已经在身上的标签置灰。
class _AddTagDialog extends StatefulWidget {
  const _AddTagDialog({required this.categories, required this.existing});

  final List<CategoryWithTags> categories;
  final Set<String> existing;

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  CategoryWithTags? _category;
  TagOption? _tag;

  @override
  Widget build(BuildContext context) {
    final category = _category;
    final candidates = category?.tags ?? const <TagOption>[];

    return AlertDialog(
      title: const Text('添加标签'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<CategoryWithTags>(
              initialValue: category,
              decoration: const InputDecoration(labelText: '分类'),
              items: [
                for (final item in widget.categories)
                  DropdownMenuItem(value: item, child: Text(item.name)),
              ],
              onChanged: (value) => setState(() {
                _category = value;
                _tag = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TagOption>(
              initialValue: _tag,
              decoration: const InputDecoration(labelText: '标签'),
              items: [
                for (final tag in candidates)
                  if (!widget.existing.contains(tag.refIn(category!.code)))
                    DropdownMenuItem(value: tag, child: Text(tag.name)),
              ],
              onChanged: (value) => setState(() => _tag = value),
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
          onPressed: category == null || _tag == null
              ? null
              : () => Navigator.pop(context, _tag!.refIn(category.code)),
          child: const Text('添加'),
        ),
      ],
    );
  }
}

/// 详情页标签区：按分类竖排，左边分类名，冒号右边的标签可以换行。
class TagGroupList extends StatelessWidget {
  const TagGroupList({required this.tags, required this.onTap, super.key});

  final List<BlockTag> tags;
  final ValueChanged<BlockTag> onTap;

  static const double _labelWidth = 72;

  List<({String name, List<BlockTag> tags})> get _groups {
    final grouped = <String, List<BlockTag>>{};
    for (final tag in tags) {
      (grouped[tag.categoryName] ??= []).add(tag);
    }
    return [
      for (final entry in grouped.entries)
        (name: entry.key, tags: entry.value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in _groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${group.name}：',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final tag in group.tags)
                        ActionChip(
                          label: Text(
                            tag.tagName,
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          tooltip: '按 ${tag.label} 搜索',
                          onPressed: () => onTap(tag),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 缩略图 + 名字，贴图编辑和详情页都用。
class TextureTile extends StatelessWidget {
  const TextureTile({
    required this.hash,
    required this.label,
    this.onTap,
    this.trailing,
    super.key,
  });

  final String hash;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: BlockThumbnail(hash: hash, size: 64),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 76,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}

/// 编辑方块基本信息：code、名字、图标用哪张材质。
Future<void> showBlockInfoEditor(
  BuildContext context, {
  required String code,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _BlockInfoEditor(code: code),
  );
}

class _BlockInfoEditor extends ConsumerWidget {
  const _BlockInfoEditor({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(blockDetailProvider(code));

    return Dialog(
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: detail.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text('读取失败：$error'),
            data: (detail) => detail == null
                ? const Text('方块不存在')
                : _InfoForm(detail: detail),
          ),
        ),
      ),
    );
  }
}

class _InfoForm extends ConsumerStatefulWidget {
  const _InfoForm({required this.detail});

  final BlockDetail detail;

  @override
  ConsumerState<_InfoForm> createState() => _InfoFormState();
}

class _InfoFormState extends ConsumerState<_InfoForm> {
  late final TextEditingController _code = TextEditingController(
    text: widget.detail.code,
  );
  late final TextEditingController _nameZh = TextEditingController(
    text: widget.detail.nameZh ?? '',
  );
  late final TextEditingController _nameEn = TextEditingController(
    text: widget.detail.nameEn ?? '',
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.detail.name ?? '',
  );

  /// null 表示不用图标，否则是材质键。
  String? _iconKey;

  @override
  void initState() {
    super.initState();
    for (final entry in widget.detail.textures) {
      if (entry.hash == widget.detail.iconHash) {
        _iconKey = entry.key;
        break;
      }
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _nameZh.dispose();
    _nameEn.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '编辑方块 · ${detail.code}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          decoration: const InputDecoration(
            labelText: 'code',
            helperText: '命名空间:名称，小写字母、数字、下划线',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameZh,
          decoration: const InputDecoration(labelText: '中文名'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameEn,
          decoration: const InputDecoration(labelText: '英文名'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: '覆盖名（优先显示）',
            helperText: '留空就用中文名',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _iconKey,
          decoration: const InputDecoration(labelText: '图标使用的贴图'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('不用图标')),
            for (final entry in detail.textures)
              DropdownMenuItem<String?>(
                value: entry.key,
                child: Text(entry.key),
              ),
          ],
          onChanged: (value) => setState(() => _iconKey = value),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            const Spacer(),
            FilledButton(onPressed: _save, child: const Text('保存')),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final selected = ref.read(selectedBlockProvider.notifier);
    try {
      final updated = await ref
          .read(blockWriterProvider)
          .updateBlock(
            widget.detail.code,
            newCode: _code.text,
            name: _name.text,
            nameZh: _nameZh.text,
            nameEn: _nameEn.text,
            iconKey: _iconKey,
            clearIcon: _iconKey == null,
          );
      ref.invalidate(blockDetailProvider(widget.detail.code));
      ref.invalidate(blockDetailProvider(updated));
      ref.invalidate(blockPageProvider);
      if (updated != widget.detail.code) selected.select(updated);
      messenger.showSnackBar(const SnackBar(content: Text('已保存')));
      navigator.pop();
    } on PatchException catch (error) {
      final text = error.hint == null
          ? error.message
          : '${error.message}\n${error.hint}';
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }
  }
}
