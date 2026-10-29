import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../../core/db/database_provider.dart';
import '../../domain/block_texture_entry.dart';

/// 编辑色值：自动生成 / 吸色 / 手动。返回值是 `#rrggbb` 或空串（清空）。
Future<String?> showColorEditor(
  BuildContext context, {
  required List<BlockTextureEntry> textures,
  String? current,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ColorEditor(textures: textures, current: current),
  );
}

enum _Mode { auto, pick, manual }

class _ColorEditor extends ConsumerStatefulWidget {
  const _ColorEditor({required this.textures, this.current});

  final List<BlockTextureEntry> textures;
  final String? current;

  @override
  ConsumerState<_ColorEditor> createState() => _ColorEditorState();
}

class _ColorEditorState extends ConsumerState<_ColorEditor> {
  _Mode _mode = _Mode.auto;
  BlockTextureEntry? _texture;
  Color _picked = const Color(0xFF7F7F7F);
  String? _autoHex;

  bool get _hasTextures => widget.textures.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _texture = _hasTextures ? widget.textures.first : null;
    final current = widget.current;
    if (current != null) {
      final value = int.tryParse(current.replaceFirst('#', ''), radix: 16);
      if (value != null) _picked = Color(0xFF000000 | value);
    }
    if (!_hasTextures) _mode = _Mode.manual;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final root = ref.watch(texturesRootProvider);

    return Dialog(
      child: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('设置色值', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<_Mode>(
                segments: [
                  ButtonSegment(
                    value: _Mode.auto,
                    label: const Text('自动生成'),
                    enabled: _hasTextures,
                  ),
                  ButtonSegment(
                    value: _Mode.pick,
                    label: const Text('吸色'),
                    enabled: _hasTextures,
                  ),
                  const ButtonSegment(value: _Mode.manual, label: Text('手动')),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (values) =>
                    setState(() => _mode = values.first),
              ),
              const SizedBox(height: 16),
              SizedBox(height: 260, child: _body(root, theme)),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context, ''),
                    child: const Text('清空'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _result()),
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AsyncValue<String> root, ThemeData theme) {
    switch (_mode) {
      case _Mode.auto:
        return _autoBody(root, theme);
      case _Mode.pick:
        return _pickBody(root, theme);
      case _Mode.manual:
        return SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _picked,
            onColorChanged: (color) => setState(() => _picked = color),
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        );
    }
  }

  Widget _autoBody(AsyncValue<String> root, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<BlockTextureEntry>(
          initialValue: _texture,
          decoration: const InputDecoration(labelText: '使用的贴图'),
          items: [
            for (final entry in widget.textures)
              DropdownMenuItem(value: entry, child: Text(entry.key)),
          ],
          onChanged: (value) => setState(() {
            _texture = value;
            _autoHex = null;
          }),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton.tonal(
              onPressed: () => _computeMedian(root),
              child: const Text('计算中位色'),
            ),
            const SizedBox(width: 12),
            if (_autoHex != null) ...[
              _swatch(_autoHex!),
              const SizedBox(width: 8),
              Text(_autoHex!, style: theme.textTheme.bodySmall),
            ] else
              Text(
                '取贴图里不透明像素的中位色',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ],
    );
  }

  Widget _pickBody(AsyncValue<String> root, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<BlockTextureEntry>(
          initialValue: _texture,
          decoration: const InputDecoration(labelText: '使用的贴图'),
          items: [
            for (final entry in widget.textures)
              DropdownMenuItem(value: entry, child: Text(entry.key)),
          ],
          onChanged: (value) => setState(() => _texture = value),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _TextureCanvas(
            entry: _texture,
            root: root,
            onPick: (color) => setState(() => _picked = color),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _swatch(_hexOf(_picked)),
            const SizedBox(width: 8),
            Text(_hexOf(_picked), style: theme.textTheme.bodySmall),
            const SizedBox(width: 12),
            Text('点图片取像素颜色', style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }

  String _result() => switch (_mode) {
    _Mode.auto => _autoHex ?? _hexOf(_picked),
    _Mode.pick || _Mode.manual => _hexOf(_picked),
  };

  Future<void> _computeMedian(AsyncValue<String> root) async {
    final entry = _texture;
    final base = root.asData?.value;
    if (entry == null || base == null) return;

    final file = File(
      p.join(base, 'sha', entry.hash.substring(0, 2), '${entry.hash}.webp'),
    );
    if (!file.existsSync()) return;
    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) return;

    final reds = <int>[];
    final greens = <int>[];
    final blues = <int>[];
    for (final pixel in decoded) {
      if (pixel.a < 128) continue;
      reds.add(pixel.r.toInt());
      greens.add(pixel.g.toInt());
      blues.add(pixel.b.toInt());
    }
    if (reds.isEmpty) return;

    int median(List<int> values) {
      values.sort();
      return values[values.length ~/ 2];
    }

    final hex =
        '#${median(reds).toRadixString(16).padLeft(2, '0')}'
        '${median(greens).toRadixString(16).padLeft(2, '0')}'
        '${median(blues).toRadixString(16).padLeft(2, '0')}';
    setState(() => _autoHex = hex);
  }

  Widget _swatch(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Color(0xFF000000 | value),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }

  static String _hexOf(Color color) {
    String channel(double value) =>
        (value * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${channel(color.r)}${channel(color.g)}${channel(color.b)}';
  }
}

/// 显示贴图并支持点选像素。
class _TextureCanvas extends StatelessWidget {
  const _TextureCanvas({
    required this.entry,
    required this.root,
    required this.onPick,
  });

  final BlockTextureEntry? entry;
  final AsyncValue<String> root;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    final selected = entry;
    final base = root.asData?.value;
    if (selected == null || base == null) {
      return const Center(child: Text('没有可用的贴图'));
    }

    final file = File(
      p.join(
        base,
        'sha',
        selected.hash.substring(0, 2),
        '${selected.hash}.webp',
      ),
    );
    if (!file.existsSync()) {
      return const Center(child: Text('贴图文件缺失'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        return GestureDetector(
          onTapDown: (details) async {
            final bytes = await file.readAsBytes();
            final decoded = img.decodeImage(bytes);
            if (decoded == null) return;
            final x = (details.localPosition.dx / size.width * decoded.width)
                .clamp(0, decoded.width - 1)
                .toInt();
            final y = (details.localPosition.dy / size.height * decoded.height)
                .clamp(0, decoded.height - 1)
                .toInt();
            final pixel = decoded.getPixel(x, y);
            onPick(
              Color.fromARGB(
                pixel.a.toInt(),
                pixel.r.toInt(),
                pixel.g.toInt(),
                pixel.b.toInt(),
              ),
            );
          },
          child: Image.file(
            file,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
        );
      },
    );
  }
}

