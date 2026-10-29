import 'package:drift/drift.dart';

import 'tag_source.dart';

/// 标注写入失败。message 说问题，hint 说怎么改。
final class PatchException implements Exception {
  const PatchException(this.message, [this.hint]);

  final String message;
  final String? hint;

  @override
  String toString() => hint == null ? message : '$message\n$hint';
}

/// 一个要加上的标签。
final class PatchTag {
  const PatchTag(this.ref, {this.source = TagSource.user});

  final String ref;
  final TagSource source;
}

/// 一次标注修改。`Value.absent` 表示不改这一列。
final class BlockPatch {
  const BlockPatch({
    required this.code,
    this.colorHex = const Value.absent(),
    this.reviewed = const Value.absent(),
    this.addTags = const [],
    this.removeTags = const [],
  });

  final String code;
  final Value<String?> colorHex;
  final Value<bool> reviewed;
  final List<PatchTag> addTags;

  /// 要摘掉的 `分类code:标签code`。
  final List<String> removeTags;
}
