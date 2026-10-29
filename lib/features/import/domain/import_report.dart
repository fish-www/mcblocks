/// 导入模式。
enum ImportMode {
  /// 按 code 增量写入，`reviewed=1` 的方块保持原样，已有标签不删。
  merge,

  /// 先清空方块、标签、词表、贴图记录，再整体写入。
  rebuild,
}

/// 一次导入的结果。
final class ImportReport {
  ImportReport([Iterable<String> initialProblems = const []]) {
    problems.addAll(initialProblems);
  }

  int blocksInserted = 0;
  int blocksUpdated = 0;
  int blocksSkipped = 0;
  int texturesWritten = 0;
  int texturesSkipped = 0;
  int tagsLinked = 0;

  /// 逐条可跳过问题，例如贴图缺失、变体指向不存在的方块。
  final List<String> problems = [];
}

/// 进度回调的载荷。
final class ImportProgress {
  const ImportProgress(this.stage, this.done, this.total);

  final String stage;
  final int done;
  final int total;
}