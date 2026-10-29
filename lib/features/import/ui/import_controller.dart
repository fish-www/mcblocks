import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../blocks/ui/blocks_providers.dart';
import '../data/package_importer.dart';
import '../data/package_reader_isolate.dart';
import '../domain/import_exception.dart';
import '../domain/import_report.dart';

part 'import_controller.g.dart';

enum ImportPhase { idle, reading, writing, done, failed }

/// 导入页的状态。每次新导入都整体替换，不做增量合并。
final class ImportState {
  const ImportState({
    this.phase = ImportPhase.idle,
    this.mode = ImportMode.merge,
    this.progress,
    this.report,
    this.message,
    this.hint,
  });

  final ImportPhase phase;
  final ImportMode mode;
  final ImportProgress? progress;
  final ImportReport? report;
  final String? message;
  final String? hint;

  bool get busy => phase == ImportPhase.reading || phase == ImportPhase.writing;

  ImportState withProgress(ImportProgress progress) => ImportState(
    phase: phase,
    mode: mode,
    progress: progress,
    report: report,
    message: message,
    hint: hint,
  );
}

@riverpod
class ImportController extends _$ImportController {
  @override
  ImportState build() => const ImportState();

  /// 切换导入模式会清掉上一次的结果，避免旧报告误导。
  void setMode(ImportMode mode) {
    if (state.busy) return;
    state = ImportState(mode: mode);
  }

  /// 选文件后立刻导入。取消选择时状态不动。
  Future<void> pickFile(ImportMode mode) async {
    final picked = await FilePicker.pickFile(
      dialogTitle: '选择 .mcblocks 数据包',
      type: FileType.any,
    );
    if (picked == null) return;

    final path = picked.path;
    if (path == null) {
      state = ImportState(
        phase: ImportPhase.failed,
        mode: mode,
        message: '读不到所选文件的路径',
        hint: '把数据包拷到本地目录后再选一次',
      );
      return;
    }
    await run(path: path, mode: mode);
  }

  Future<void> run({required String path, required ImportMode mode}) async {
    state = ImportState(phase: ImportPhase.reading, mode: mode);
    try {
      final bytes = await File(path).readAsBytes();
      final package = await parsePackageInIsolate(bytes);

      state = ImportState(phase: ImportPhase.writing, mode: mode);
      final importer = await ref.read(packageImporterProvider.future);
      final report = await importer.import(
        package,
        mode: mode,
        onProgress: (progress) => state = state.withProgress(progress),
      );

      ref.invalidate(blockPageProvider);
      ref.invalidate(categoriesProvider);
      state = ImportState(phase: ImportPhase.done, mode: mode, report: report);
    } on ImportException catch (error) {
      state = ImportState(
        phase: ImportPhase.failed,
        mode: mode,
        message: error.message,
        hint: error.hint,
      );
    } catch (error) {
      state = ImportState(
        phase: ImportPhase.failed,
        mode: mode,
        message: '$error',
        hint: '确认文件是 .mcblocks 数据包，且没有被别的程序占用',
      );
    }
  }
}
