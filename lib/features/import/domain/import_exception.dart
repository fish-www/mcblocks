/// 数据包格式错误。message 说明问题，hint 说明怎么修。
final class ImportException implements Exception {
  const ImportException(this.message, [this.hint]);

  final String message;
  final String? hint;

  @override
  String toString() => hint == null ? message : '$message\n$hint';
}
