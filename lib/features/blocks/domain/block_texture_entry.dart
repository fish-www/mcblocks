/// 方块的一条材质映射。`sort` 小的先显示。
final class BlockTextureEntry {
  const BlockTextureEntry({
    required this.key,
    required this.hash,
    required this.sort,
  });

  final String key;
  final String hash;
  final int sort;
}
