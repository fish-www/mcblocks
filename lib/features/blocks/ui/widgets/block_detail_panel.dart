import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/block_writer.dart';
import '../../domain/block_detail.dart';
import '../../domain/block_tag.dart';
import '../../domain/block_texture_entry.dart';
import '../../domain/patch.dart';
import '../blocks_providers.dart';
import 'color_editor.dart';
import 'editors.dart';
import 'texture_editor.dart';
import 'texture_viewer.dart';

/// 右侧详情面板和窄屏详情页共用。默认只读，编辑走右上角「更多」。
class BlockDetailPanel extends ConsumerWidget {
  const BlockDetailPanel({required this.code, this.onSelect, super.key});

  final String code;

  /// 点击变体或基础方块时切换选中。
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(blockDetailProvider(code));

    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('读取失败：$error')),
      data: (detail) => detail == null
          ? Center(child: Text('找不到 $code'))
          : _DetailBody(detail: detail, onSelect: onSelect),
    );
  }
}

enum _Action { info, color, tags, textures, review, delete }

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, this.onSelect});

  final BlockDetail detail;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: '点击复制名称',
                child: InkWell(
                  onTap: () => _copy(context, detail.displayName, '名称'),
                  child: Text(
                    detail.displayName,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
            ),
            PopupMenuButton<_Action>(
              tooltip: '更多',
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => _onAction(context, ref, action),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _Action.info,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('编辑信息'),
                  ),
                ),
                const PopupMenuItem(
                  value: _Action.color,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.palette_outlined),
                    title: Text('编辑色值'),
                  ),
                ),
                const PopupMenuItem(
                  value: _Action.tags,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.sell_outlined),
                    title: Text('管理标签'),
                  ),
                ),
                const PopupMenuItem(
                  value: _Action.textures,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.image_outlined),
                    title: Text('管理贴图'),
                  ),
                ),
                PopupMenuItem(
                  value: _Action.review,
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      detail.reviewed ? Icons.undo : Icons.check,
                    ),
                    title: Text(detail.reviewed ? '取消审核' : '标记已审核'),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: _Action.delete,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.delete_outline),
                    title: Text('删除方块'),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 2),
        Tooltip(
          message: '点击复制 code',
          child: InkWell(
            onTap: () => _copy(context, detail.code, 'code'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(detail.code, style: theme.textTheme.bodySmall),
                const SizedBox(width: 4),
                Icon(
                  Icons.copy,
                  size: 13,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _ColorSwatch(colorHex: detail.colorHex),
            const SizedBox(width: 6),
            Text(
              detail.colorHex ?? '色值：空',
              style: theme.textTheme.bodySmall,
            ),
            if (detail.colorHex != null)
              IconButton(
                tooltip: '复制色值',
                iconSize: 14,
                visualDensity: VisualDensity.compact,
                onPressed: () => _copy(context, detail.colorHex!, '色值'),
                icon: const Icon(Icons.copy),
              ),
          ],
        ),
        if (detail.variantOf case final base?) ...[
          const SizedBox(height: 8),
          _Relation(label: '基础方块', blocks: [base], onSelect: onSelect),
        ],
        if (detail.variants.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Relation(
            label: '变体 ${detail.variants.length}',
            blocks: detail.variants,
            onSelect: onSelect,
          ),
        ],
        const SizedBox(height: 16),
        _Textures(
          code: detail.code,
          textures: detail.textures,
          iconHash: detail.iconHash,
        ),
        const SizedBox(height: 16),
        Text('标签', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        if (detail.manualTags.isEmpty)
          Text(
            '还没有标注',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          )
        else
          TagGroupList(
            tags: detail.manualTags,
            onTap: (tag) => _searchByTag(context, ref, tag),
          ),
        if (detail.vanillaTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            title: Text(
              '原版标签 (${detail.vanillaTags.length})',
              style: theme.textTheme.labelLarge,
            ),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            children: [
              TagGroupList(
                tags: detail.vanillaTags,
                onTap: (tag) => _searchByTag(context, ref, tag),
              ),
            ],
          ),
        ],
        if (detail.note case final note? when note.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('备注', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(note, style: theme.textTheme.bodySmall),
        ],
        if (detail.updatedAt case final updated?) ...[
          const SizedBox(height: 16),
          Text(
            '更新于 ${updated.toIso8601String().substring(0, 16)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }

  /// 点标签直接按它筛。
  void _searchByTag(BuildContext context, WidgetRef ref, BlockTag tag) {
    ref.read(blockFilterControllerProvider.notifier).applyTag(tag.ref);
    context.go('/blocks');
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _Action action,
  ) async {
    switch (action) {
      case _Action.info:
        await showBlockInfoEditor(context, code: detail.code);
      case _Action.color:
        final hex = await showColorEditor(
          context,
          textures: detail.textures,
          current: detail.colorHex,
        );
        if (hex == null || !context.mounted) return;
        await _apply(
          context,
          ref,
          () => ref
              .read(blockWriterProvider)
              .apply(
                BlockPatch(
                  code: detail.code,
                  colorHex: Value(hex.isEmpty ? null : hex),
                ),
              ),
          '色值已保存',
        );
      case _Action.tags:
        await showTagEditor(context, code: detail.code);
      case _Action.textures:
        await showTextureEditor(context, code: detail.code);
      case _Action.review:
        await _apply(
          context,
          ref,
          () => ref
              .read(blockWriterProvider)
              .apply(
                BlockPatch(
                  code: detail.code,
                  reviewed: Value(!detail.reviewed),
                ),
              ),
          detail.reviewed ? '已取消审核' : '已标记审核',
        );
      case _Action.delete:
        await _delete(context, ref);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${detail.displayName}？'),
        content: const Text('方块、它的标签和材质映射都会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    await _apply(
      context,
      ref,
      () => ref.read(blockWriterProvider).deleteBlock(detail.code),
      '已删除 ${detail.code}',
    );
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _apply(
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

  Future<void> _copy(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制$label：$text'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.colorHex});

  final String? colorHex;

  @override
  Widget build(BuildContext context) {
    final value = int.tryParse(
      (colorHex ?? '').replaceFirst('#', ''),
      radix: 16,
    );
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: value == null ? null : Color(0xFF000000 | value),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _Relation extends StatelessWidget {
  const _Relation({
    required this.label,
    required this.blocks,
    this.onSelect,
  });

  final String label;
  final List<BlockRef> blocks;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final block in blocks.take(30))
              Tooltip(
                message: block.code,
                child: ActionChip(
                  label: Text(
                    block.displayName,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onSelect == null
                      ? null
                      : () => onSelect!(block.code),
                ),
              ),
            if (blocks.length > 30)
              Text(
                '还有 ${blocks.length - 30} 个',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ],
    );
  }
}

class _Textures extends StatelessWidget {
  const _Textures({
    required this.code,
    required this.textures,
    required this.iconHash,
  });

  final String code;
  final List<BlockTextureEntry> textures;
  final String? iconHash;

  List<BlockTextureEntry> get _entries {
    final seen = <String>{};
    final result = <BlockTextureEntry>[];
    for (final entry in textures) {
      if (!seen.add(entry.key)) continue;
      result.add(entry);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _entries;
    if (entries.isEmpty) {
      return Text(
        '没有可用的贴图',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          TextureTile(
            hash: entry.hash,
            label: entry.key,
            onTap: () => showTextureViewer(
              context,
              code: code,
              key: entry.key,
              hash: entry.hash,
            ),
          ),
      ],
    );
  }
}
