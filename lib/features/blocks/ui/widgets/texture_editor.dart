import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/block_writer.dart';
import '../../domain/block_detail.dart';
import '../../domain/block_texture_entry.dart';
import '../../domain/patch.dart';
import '../blocks_providers.dart';
import 'block_thumbnail.dart';
import 'texture_viewer.dart';

/// 贴图管理：加、删、改名、排序。
Future<void> showTextureEditor(BuildContext context, {required String code}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TextureEditor(code: code),
  );
}

class _TextureEditor extends ConsumerWidget {
  const _TextureEditor({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(blockDetailProvider(code));

    return Dialog(
      child: SizedBox(
        width: 560,
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
    final textures = detail.textures;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '贴图 · ${detail.code}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
              label: const Text('添加贴图'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (textures.isEmpty)
          Text('还没有贴图', style: theme.textTheme.bodySmall)
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final entry in textures)
                    _TextureRow(
                      detail: detail,
                      entry: entry,
                      writer: ref.read(blockWriterProvider),
                      onDone: (message) =>
                          _notify(context, ref, message),
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

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFile(
      dialogTitle: '选择贴图（png/jpg/webp）',
      type: FileType.image,
    );
    final path = picked?.path;
    if (path == null) return;

    final bytes = await File(path).readAsBytes();
    if (!context.mounted) return;

    final name = await _askName(context, initial: 'texture');
    if (name == null || name.isEmpty || !context.mounted) return;

    await _write(
      context,
      ref,
      () => ref
          .read(blockWriterProvider)
          .addTexture(detail.code, key: name, bytes: bytes),
      '已添加 $name',
    );
  }

  Future<void> _notify(BuildContext context, WidgetRef ref, String message) {
    ref.invalidate(blockDetailProvider(detail.code));
    ref.invalidate(blockPageProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    return Future.value();
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

class _TextureRow extends ConsumerWidget {
  const _TextureRow({
    required this.detail,
    required this.entry,
    required this.writer,
    required this.onDone,
  });

  final BlockDetail detail;
  final BlockTextureEntry entry;
  final BlockWriter writer;
  final Future<void> Function(String message) onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isIcon = entry.hash == detail.iconHash;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: InkWell(
        onTap: () => showTextureViewer(
          context,
          code: detail.code,
          key: entry.key,
          hash: entry.hash,
        ),
        child: BlockThumbnail(hash: entry.hash, size: 48),
      ),
      title: Row(
        children: [
          Flexible(child: Text(entry.key)),
          if (isIcon) ...[
            const SizedBox(width: 6),
            Chip(
              label: Text(
                '图标',
                style: theme.textTheme.labelSmall,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
      subtitle: Text(
        'sort ${entry.sort} · ${entry.hash.substring(0, 8)}',
        style: theme.textTheme.labelSmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '上移',
            iconSize: 18,
            onPressed: () => _run(
              context,
              ref,
              () => writer.moveTexture(detail.code, entry.key, -1),
              '已上移 ${entry.key}',
            ),
            icon: const Icon(Icons.arrow_upward),
          ),
          IconButton(
            tooltip: '下移',
            iconSize: 18,
            onPressed: () => _run(
              context,
              ref,
              () => writer.moveTexture(detail.code, entry.key, 1),
              '已下移 ${entry.key}',
            ),
            icon: const Icon(Icons.arrow_downward),
          ),
          IconButton(
            tooltip: '重命名',
            iconSize: 18,
            onPressed: () => _rename(context, ref),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '删除',
            iconSize: 18,
            onPressed: () => _run(
              context,
              ref,
              () => writer.deleteTexture(detail.code, entry.key),
              '已删除 ${entry.key}',
            ),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final name = await _askName(context, initial: entry.key);
    if (name == null || name == entry.key || !context.mounted) return;
    await _run(
      context,
      ref,
      () => writer.renameTexture(detail.code, entry.key, name),
      '已重命名为 $name',
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String message,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (!context.mounted) return;
      await onDone(message);
    } on PatchException catch (error) {
      final text = error.hint == null
          ? error.message
          : '${error.message}\n${error.hint}';
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }
  }
}

Future<String?> _askName(BuildContext context, {required String initial}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('材质名'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '例：side'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}
