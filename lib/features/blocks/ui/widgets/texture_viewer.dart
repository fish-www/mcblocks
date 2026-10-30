import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/db/database_provider.dart';

/// 放大查看一张贴图，可以下载原文件。
Future<void> showTextureViewer(
  BuildContext context, {
  required String code,
  required String key,
  required String hash,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TextureViewer(code: code, textureKey: key, hash: hash),
  );
}

class _TextureViewer extends ConsumerWidget {
  const _TextureViewer({
    required this.code,
    required this.textureKey,
    required this.hash,
  });

  final String code;
  final String textureKey;
  final String hash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = ref.watch(texturesRootProvider);
    final theme = Theme.of(context);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$code · $textureKey',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              hash,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 384,
              height: 384,
              child: root.maybeWhen(
                data: (path) => Image.file(
                  File(
                    p.join(path, 'sha', hash.substring(0, 2), '$hash.webp'),
                  ),
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) => const Center(
                    child: Text('贴图文件缺失'),
                  ),
                ),
                orElse: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _download(context, root),
                  icon: const Icon(Icons.download),
                  label: const Text('下载'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context, AsyncValue<String> root) async {
    final base = root.asData?.value;
    if (base == null) return;

    final file = File(
      p.join(base, 'sha', hash.substring(0, 2), '$hash.webp'),
    );
    if (!file.existsSync()) return;

    final messenger = ScaffoldMessenger.of(context);
    final uri = await FilePicker.saveFile(
      fileName: '$code-$textureKey.webp',
      bytes: await file.readAsBytes(),
      mimeType: 'image/webp',
      dialogTitle: '保存贴图',
    );
    if (uri != null) {
      messenger.showSnackBar(SnackBar(content: Text('已保存到 $uri')));
    }
  }
}
