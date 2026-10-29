import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/db/database_provider.dart';

/// 128px 的 webp 贴图，像素画不插值。
class BlockThumbnail extends ConsumerWidget {
  const BlockThumbnail({
    required this.hash,
    this.size = 40,
    super.key,
  });

  final String? hash;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.texture,
        size: size / 2,
        color: Theme.of(context).colorScheme.outline,
      ),
    );

    final textureHash = hash;
    if (textureHash == null) return placeholder;

    final root = ref.watch(texturesRootProvider);

    return root.maybeWhen(
      data: (path) {
        // 尺寸硬约束 + 颜色用 Image.color 混合：不额外建图层，
        // 不可能把 tint 刷到图片外面。
        return SizedBox(
          width: size,
          height: size,
          child: Image.file(
            File(
              p.join(
                path,
                'sha',
                textureHash.substring(0, 2),
                '$textureHash.webp',
              ),
            ),
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, _, _) => placeholder,
          ),
        );
      },
      orElse: () => placeholder,
    );
  }
}
