import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart' hide BlockTag;
import '../../../core/db/database_provider.dart';
import '../domain/block_detail.dart';
import '../domain/block_filter.dart';
import '../domain/block_list_item.dart';
import '../domain/block_page.dart';
import '../domain/block_tag.dart';
import '../domain/block_texture_entry.dart';
import '../domain/category_with_tags.dart';
import '../domain/tag_source.dart';

part 'blocks_repository.g.dart';

@riverpod
BlocksRepository blocksRepository(Ref ref) =>
    BlocksRepository(ref.watch(appDatabaseProvider));

/// 方块列表的读侧。
///
/// 家族查询需要相关 `EXISTS` 子查询，所以保留原生 SQL，不写成 builder。
/// 写操作走 patch 层，不经过这里。
class BlocksRepository {
  BlocksRepository(this._db);

  final AppDatabase _db;

  Future<BlockPage> query(BlockFilter filter) async {
    final (where, variables) = _where(filter);

    final rows = await _db
        .customSelect(
          '''
SELECT b.id AS id, b.code AS code, b.name AS name, b.name_zh AS name_zh,
       b.name_en AS name_en, b.color_hex AS color_hex, b.reviewed AS reviewed,
       icon.hash AS icon_hash,
       (SELECT COUNT(*) FROM block v WHERE v.variant_of = b.id) AS variant_count
FROM block b
LEFT JOIN texture icon ON icon.id = b.icon_id
WHERE $where
ORDER BY ${_orderBy(filter.sort)}
LIMIT ? OFFSET ?
''',
          variables: [
            ...variables,
            Variable.withInt(filter.limit),
            Variable.withInt(filter.offset),
          ],
        )
        .get();

    final totalRow = await _db
        .customSelect(
          'SELECT COUNT(*) AS total FROM block b WHERE $where',
          variables: variables,
        )
        .getSingle();

    final tags = await _tagsFor([for (final row in rows) row.read<int>('id')]);

    return BlockPage(
      total: totalRow.read<int>('total'),
      items: [
        for (final row in rows)
          _item(row, tags[row.read<int>('id')] ?? const []),
      ],
    );
  }

  Future<BlockDetail?> detail(String code) async {
    final row = await _db
        .customSelect(
          '''
SELECT b.id AS id, b.code AS code, b.name AS name, b.name_zh AS name_zh,
       b.name_en AS name_en, b.note AS note, b.color_hex AS color_hex,
       b.reviewed AS reviewed, b.updated_at AS updated_at,
       v.code AS variant_code, v.name AS variant_name,
       v.name_zh AS variant_name_zh, v.name_en AS variant_name_en,
       icon.hash AS icon,
       (SELECT COUNT(*) FROM block child WHERE child.variant_of = b.id) AS variant_count
FROM block b
LEFT JOIN block v ON v.id = b.variant_of
LEFT JOIN texture icon ON icon.id = b.icon_id
WHERE b.code = ?
''',
          variables: [Variable.withString(code)],
        )
        .getSingleOrNull();
    if (row == null) return null;

    final id = row.read<int>('id');
    final tags = (await _tagsFor([id]))[id] ?? const <BlockTag>[];
    final variants = await (_db.select(_db.blocks)
          ..where((t) => t.variantOf.equals(id))
          ..orderBy([(t) => OrderingTerm(expression: t.code)]))
        .get();

    return BlockDetail(
      id: id,
      code: row.read<String>('code'),
      name: row.read<String?>('name'),
      nameZh: row.read<String?>('name_zh'),
      nameEn: row.read<String?>('name_en'),
      note: row.read<String?>('note'),
      colorHex: row.read<String?>('color_hex'),
      reviewed: row.read<int>('reviewed') != 0,
      variantOf: switch (row.read<String?>('variant_code')) {
        final code? => BlockRef(
          code: code,
          name: row.read<String?>('variant_name'),
          nameZh: row.read<String?>('variant_name_zh'),
          nameEn: row.read<String?>('variant_name_en'),
        ),
        null => null,
      },
      variantCount: row.read<int>('variant_count'),
      updatedAt: _time(row.read<int?>('updated_at')),
      textures: await _texturesFor(id),
      iconHash: row.read<String?>('icon'),
      tags: tags,
      variants: [
        for (final variant in variants)
          BlockRef(
            code: variant.code,
            name: variant.name,
            nameZh: variant.nameZh,
            nameEn: variant.nameEn,
          ),
      ],
    );
  }

  /// 词表按分类分组，顺序按 `sort`。
  Future<List<CategoryWithTags>> categories() async {
    final categoryRows = await (_db.select(_db.categories)..orderBy([
          (t) => OrderingTerm(expression: t.sort),
          (t) => OrderingTerm(expression: t.code),
        ]))
        .get();
    final tagRows = await (_db.select(_db.tags)..orderBy([
          (t) => OrderingTerm(expression: t.sort),
          (t) => OrderingTerm(expression: t.code),
        ]))
        .get();

    final grouped = <int, List<TagOption>>{};
    for (final tag in tagRows) {
      (grouped[tag.categoryId] ??= []).add(
        TagOption(code: tag.code, name: tag.name, sort: tag.sort),
      );
    }

    return [
      for (final category in categoryRows)
        CategoryWithTags(
          code: category.code,
          name: category.name,
          single: category.single,
          ordered: category.ordered,
          tags: grouped[category.id] ?? const [],
        ),
    ];
  }

  Future<List<BlockTextureEntry>> _texturesFor(int blockId) async {
    final rows = await _db
        .customSelect(
          '''
SELECT bt.key AS key, bt.sort AS sort, t.hash AS hash
FROM block_texture bt
JOIN texture t ON t.id = bt.texture_id
WHERE bt.block_id = ?
ORDER BY bt.sort, bt.key
''',
          variables: [Variable.withInt(blockId)],
        )
        .get();
    return [
      for (final row in rows)
        BlockTextureEntry(
          key: row.read<String>('key'),
          hash: row.read<String>('hash'),
          sort: row.read<int>('sort'),
        ),
    ];
  }

  Future<Map<int, List<BlockTag>>> _tagsFor(List<int> blockIds) async {
    if (blockIds.isEmpty) return const {};

    final placeholders = List.filled(blockIds.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          '''
SELECT bt.block_id AS block_id, bt.source AS source,
       c.code AS category_code, c.name AS category_name,
       t.code AS tag_code, t.name AS tag_name
FROM block_tag bt
JOIN tag t ON t.id = bt.tag_id
JOIN category c ON c.id = t.category_id
WHERE bt.block_id IN ($placeholders)
ORDER BY c.sort, c.code, t.sort, t.code
''',
          variables: [for (final id in blockIds) Variable.withInt(id)],
        )
        .get();

    final result = <int, List<BlockTag>>{};
    for (final row in rows) {
      (result[row.read<int>('block_id')] ??= []).add(
        BlockTag(
          categoryCode: row.read<String>('category_code'),
          categoryName: row.read<String>('category_name'),
          tagCode: row.read<String>('tag_code'),
          tagName: row.read<String>('tag_name'),
          source: TagSource.parse(row.read<String>('source')),
        ),
      );
    }
    return result;
  }

  BlockListItem _item(QueryRow row, List<BlockTag> tags) => BlockListItem(
    id: row.read<int>('id'),
    code: row.read<String>('code'),
    name: row.read<String?>('name'),
    nameZh: row.read<String?>('name_zh'),
    nameEn: row.read<String?>('name_en'),
    colorHex: row.read<String?>('color_hex'),
    iconHash: row.read<String?>('icon_hash'),
    reviewed: row.read<int>('reviewed') != 0,
    variantCount: row.read<int>('variant_count'),
    tags: tags,
  );

  /// 排序片段只在白名单里取，不拼用户输入。
  String _orderBy(BlockSort sort) => switch (sort) {
    BlockSort.updatedDesc => 'b.updated_at DESC, b.code ASC',
    BlockSort.codeAsc => 'b.code ASC',
    BlockSort.codeDesc => 'b.code DESC',
    BlockSort.nameAsc =>
      'COALESCE(b.name, b.name_zh, b.name_en, b.code) ASC, b.code ASC',
  };

  /// 生成 WHERE 和对应的位置参数。计数和取页共用同一份条件。
  (String, List<Variable<Object>>) _where(BlockFilter filter) {
    final conditions = <String>[];
    final variables = <Variable<Object>>[];

    if (filter.collapse) conditions.add('b.variant_of IS NULL');
    if (filter.unreviewedOnly) conditions.add('b.reviewed = 0');

    final search = filter.search.trim();
    if (search.isNotEmpty) {
      final pattern = '%$search%';
      conditions.add(
        '(b.code LIKE ? OR b.name LIKE ? OR b.name_zh LIKE ? '
        'OR b.name_en LIKE ?)',
      );
      variables.addAll(List.filled(4, Variable.withString(pattern)));
    }

    // 折叠模式下，标签条件命中基础方块或任一变体。
    final family = filter.collapse
        ? '(fam.id = b.id OR fam.variant_of = b.id)'
        : 'fam.id = b.id';
    String familyOf(String match) =>
        'EXISTS (SELECT 1 FROM block fam '
        'JOIN block_tag bt ON bt.block_id = fam.id '
        'JOIN tag tg ON tg.id = bt.tag_id '
        'JOIN category c ON c.id = tg.category_id '
        'WHERE $family AND ($match))';

    final matches = [for (final raw in filter.tags) _tagMatch(raw)];
    switch (filter.mode) {
      case TagMode.all:
        for (final match in matches) {
          conditions.add(familyOf(match.sql));
          variables.addAll(match.variables);
        }
      case TagMode.any:
        if (matches.isNotEmpty) {
          conditions.add(familyOf(matches.map((m) => m.sql).join(' OR ')));
          variables.addAll(matches.expand((m) => m.variables));
        }
      case TagMode.none:
        if (matches.isNotEmpty) {
          conditions.add(
            'NOT ${familyOf(matches.map((m) => m.sql).join(' OR '))}',
          );
          variables.addAll(matches.expand((m) => m.variables));
        }
    }

    final range = filter.range;
    if (range != null) {
      conditions.add(
        'EXISTS (SELECT 1 FROM block fam '
        'JOIN block_tag bt ON bt.block_id = fam.id '
        'JOIN tag tg ON tg.id = bt.tag_id '
        'JOIN category c ON c.id = tg.category_id '
        'WHERE $family AND c.code = ? AND tg.sort BETWEEN ? AND ?)',
      );
      variables.addAll([
        Variable.withString(range.category),
        Variable.withInt(range.from),
        Variable.withInt(range.to),
      ]);
    }

    return (conditions.isEmpty ? '1' : conditions.join(' AND '), variables);
  }

  /// `分类:标签` 或 `标签`；裸值先匹配 code，再匹配 name。
  _Match _tagMatch(String raw) {
    final index = raw.indexOf(':');
    final hasCategory = index > 0 && index < raw.length - 1;
    final category = hasCategory ? raw.substring(0, index) : null;
    final value = hasCategory ? raw.substring(index + 1) : raw;

    final variables = <Variable<Object>>[
      Variable.withString(value),
      Variable.withString(value),
    ];
    final sql = StringBuffer('(tg.code = ? OR tg.name = ?)');
    if (category != null) {
      sql.write(' AND c.code = ?');
      variables.add(Variable.withString(category));
    }
    return _Match(sql.toString(), variables);
  }

  /// drift 默认把 DateTime 存成 Unix 秒。
  DateTime? _time(int? seconds) => seconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
            .toLocal();
}

final class _Match {
  const _Match(this.sql, this.variables);

  final String sql;
  final List<Variable<Object>> variables;
}
