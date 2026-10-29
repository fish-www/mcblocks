import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/import_report.dart';
import '../data/package_exporter.dart';
import 'import_controller.dart';

class ImportPage extends ConsumerWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importControllerProvider);
    final controller = ref.read(importControllerProvider.notifier);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('导入数据包', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '把 Python 工具生成的 .mcblocks 文件导入本机数据库。'
          '增量导入不会覆盖已标注的方块。',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<ImportMode>(
            segments: const [
              ButtonSegment(
                value: ImportMode.merge,
                icon: Icon(Icons.merge_outlined),
                label: Text('增量'),
              ),
              ButtonSegment(
                value: ImportMode.rebuild,
                icon: Icon(Icons.restart_alt),
                label: Text('全量重建'),
              ),
            ],
            selected: {state.mode},
            onSelectionChanged: state.busy
                ? null
                : (values) => controller.setMode(values.first),
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: state.busy
                ? null
                : () => controller.pickFile(state.mode),
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('选择 .mcblocks 文件'),
          ),
        ),
        if (state.busy) ...[
          const SizedBox(height: 24),
          _Progress(state: state),
        ],
        if (state.phase == ImportPhase.done && state.report != null) ...[
          const SizedBox(height: 24),
          _Report(report: state.report!),
        ],
        if (state.phase == ImportPhase.failed) ...[
          const SizedBox(height: 24),
          _Failure(message: state.message, hint: state.hint),
        ],
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        Text('导出数据包', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '把当前数据库打包成 .mcblocks，格式和 Python 工具产出的完全一致。',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => _export(context, ref),
            icon: const Icon(Icons.save_alt),
            label: const Text('导出 .mcblocks'),
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final exporter = await ref.read(packageExporterProvider.future);
    final report = await exporter.export();

    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 10)
        .replaceAll('-', '');
    final uri = await FilePicker.saveFile(
      fileName: 'mcblocks-$stamp.mcblocks',
      bytes: report.bytes,
      mimeType: 'application/zip',
      dialogTitle: '保存数据包',
    );
    if (!context.mounted) return;

    if (uri == null) {
      messenger.showSnackBar(const SnackBar(content: Text('已取消导出')));
      return;
    }
    final problems = report.missing.isEmpty
        ? ''
        : '，缺 ${report.missing.length} 张贴图';
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '已导出 ${report.blocks} 个方块 / ${report.textures} 张贴图$problems',
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    final reading = state.phase == ImportPhase.reading;
    final label = reading ? '正在解包…' : '${progress?.stage ?? '写入'}…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: reading || progress == null || progress.total == 0
              ? null
              : progress.done / progress.total,
        ),
        if (progress != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${progress.done} / ${progress.total}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.report});

  final ImportReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const maxProblems = 50;
    final problems = report.problems;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('导入完成', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Stat(label: '新增方块', value: report.blocksInserted),
                _Stat(label: '更新方块', value: report.blocksUpdated),
                _Stat(label: '跳过', value: report.blocksSkipped),
                _Stat(label: '写入贴图', value: report.texturesWritten),
                _Stat(label: '复用贴图', value: report.texturesSkipped),
                _Stat(label: '关联标签', value: report.tagsLinked),
              ],
            ),
            if (problems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('问题 ${problems.length} 条', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final problem in problems.take(maxProblems))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '· $problem',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              if (problems.length > maxProblems)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '还有 ${problems.length - maxProblems} 条未显示',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/blocks'),
              icon: const Icon(Icons.grid_view_outlined),
              label: const Text('查看方块'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: theme.textTheme.titleLarge),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.hint});

  final String? message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '导入失败',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(message ?? '未知错误'),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(hint!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
