import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:mcblocks/core/db/app_database.dart';
import 'package:mcblocks/features/blocks/data/blocks_repository.dart';
import 'package:mcblocks/features/blocks/domain/block_filter.dart';
import 'package:mcblocks/features/blocks/domain/block_list_item.dart';

void main() {
  late AppDatabase db;
  late BlocksRepository repo;
  final now = DateTime.utc(2026, 10, 29);

  late int colorCategory;
  late int shapeCategory;

  Future<int> insertCategory(
    String code, {
    bool single = true,
    bool ordered = false,
    int sort = 0,
  }) => db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          code: code,
          name: code,
          single: Value(single),
          ordered: Value(ordered),
          sort: Value(sort),
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> insertTag(int categoryId, String code, {int sort = 0}) => db
      .into(db.tags)
      .insert(
        TagsCompanion.insert(
          categoryId: categoryId,
          code: code,
          name: code,
          sort: Value(sort),
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> insertBlock(
    String code, {
    String? nameZh,
    String? nameEn,
    int? variantOf,
    bool reviewed = false,
  }) => db
      .into(db.blocks)
      .insert(
        BlocksCompanion.insert(
          code: code,
          nameZh: Value(nameZh),
          nameEn: Value(nameEn),
          variantOf: Value(variantOf),
          reviewed: Value(reviewed),
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<void> tagBlock(int blockId, int tagId) => db
      .into(db.blockTags)
      .insert(
        BlockTagsCompanion.insert(
          blockId: blockId,
          tagId: tagId,
          source: const Value('auto'),
          createdAt: now,
          updatedAt: now,
        ),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = BlocksRepository(db);

    colorCategory = await insertCategory('色系', ordered: true, sort: 10);
    shapeCategory = await insertCategory('形状', sort: 20);

    final grey = await insertTag(colorCategory, '灰', sort: 10);
    final white = await insertTag(colorCategory, '白', sort: 20);
    final cube = await insertTag(shapeCategory, '立方', sort: 10);
    final slab = await insertTag(shapeCategory, '台阶', sort: 20);

    final stone = await insertBlock('stone', nameZh: '石头', nameEn: 'Stone');
    final stoneSlab = await insertBlock(
      'stone_slab',
      nameZh: '石台阶',
      variantOf: stone,
    );
    final stoneBricks = await insertBlock('stone_bricks', nameZh: '石砖');
    final whiteWool = await insertBlock(
      'white_wool',
      nameZh: '白色羊毛',
      nameEn: 'White Wool',
      reviewed: true,
    );

    await tagBlock(stone, grey);
    await tagBlock(stone, cube);
    await tagBlock(stoneSlab, slab);
    await tagBlock(stoneBricks, grey);
    await tagBlock(stoneBricks, slab);
    await tagBlock(whiteWool, white);
  });

  tearDown(() => db.close());

  /// 测试里只关心行，不关心总数。
  Future<List<BlockListItem>> query(BlockFilter filter) async =>
      (await repo.query(filter)).items;

  test('collapsed mode hides variants and reports their count', () async {
    final rows = await query(const BlockFilter());

    expect(rows.map((row) => row.code), ['stone', 'stone_bricks', 'white_wool']);
    expect(rows.first.variantCount, 1);
    expect(rows.first.displayName, '石头');
    expect(rows.last.variantCount, 0);
  });

  test('tag conditions match across the variant family', () async {
    final collapsed = await query(
      const BlockFilter(tags: ['形状:台阶']),
    );
    expect(collapsed.map((row) => row.code), ['stone', 'stone_bricks']);

    final uncollapsed = await query(
      const BlockFilter(tags: ['形状:台阶'], collapse: false),
    );
    expect(uncollapsed.map((row) => row.code), ['stone_bricks', 'stone_slab']);
  });

  test('all / any / none combine with AND and OR', () async {
    final all = await query(
      const BlockFilter(tags: ['色系:灰', '形状:立方']),
    );
    expect(all.map((row) => row.code), ['stone']);

    final any = await query(
      const BlockFilter(mode: TagMode.any, tags: ['色系:白', '形状:台阶']),
    );
    expect(any.map((row) => row.code), ['stone', 'stone_bricks', 'white_wool']);

    final none = await query(const BlockFilter(mode: TagMode.none, tags: ['形状:立方']));
    expect(none.map((row) => row.code), ['stone_bricks', 'white_wool']);
  });

  test('bare tag matches the tag code', () async {
    final rows = await query(const BlockFilter(tags: ['灰']));
    expect(rows.map((row) => row.code), ['stone', 'stone_bricks']);
  });

  test('range filters ordered categories inclusively', () async {
    final rows = await query(
      const BlockFilter(range: TagRange(category: '色系', from: 15, to: 30)),
    );
    expect(rows.map((row) => row.code), ['white_wool']);
  });

  test('search covers code and localized names', () async {
    final byChinese = await query(const BlockFilter(search: '石'));
    expect(byChinese.map((row) => row.code), ['stone', 'stone_bricks']);

    final byEnglish = await query(const BlockFilter(search: 'wool'));
    expect(byEnglish.map((row) => row.code), ['white_wool']);
  });

  test('unreviewedOnly hides reviewed blocks', () async {
    final rows = await query(const BlockFilter(unreviewedOnly: true));
    expect(rows.map((row) => row.code), ['stone', 'stone_bricks']);
  });

  test('items carry tag labels with display names in sort order', () async {
    final rows = await query(const BlockFilter(tags: ['形状:立方']));
    expect(rows.single.tags.map((tag) => tag.label), ['色系:灰', '形状:立方']);
    expect(rows.single.tags.map((tag) => tag.ref), ['色系:灰', '形状:立方']);
  });

  test('count ignores the page limit and reports the matched total', () async {
    final page = await repo.query(const BlockFilter(limit: 1));
    expect(page.items, hasLength(1));
    expect(page.total, 3);
  });

  test('detail returns textures, tags and variants', () async {
    final stone = await repo.detail('stone');
    expect(stone, isNotNull);
    expect(stone!.displayName, '石头');
    expect(stone.variants.map((variant) => variant.code), ['stone_slab']);
    expect(stone.variants.single.displayName, '石台阶');
    expect(stone.variantCount, 1);
    expect(stone.manualTags.map((tag) => tag.label), ['色系:灰', '形状:立方']);

    final slab = await repo.detail('stone_slab');
    expect(slab!.variantOf?.code, 'stone');
    expect(slab.variantOf?.displayName, '石头');
    expect(slab.textures, isEmpty);
    expect(await repo.detail('missing'), isNull);
  });

  test('默认按更新时间倒序，可以切到 code 升序', () async {
    final old = DateTime.utc(2020, 1, 1);
    await db
        .into(db.blocks)
        .insert(
          BlocksCompanion.insert(
            code: 'aardvark',
            nameZh: const Value('土豚'),
            createdAt: old,
            updatedAt: old,
          ),
        );

    // 其它方块的 updatedAt 是 now（更晚），所以新插入的老方块排最后。
    final byUpdate = await query(const BlockFilter());
    expect(byUpdate.map((row) => row.code).toList(), [
      'stone',
      'stone_bricks',
      'white_wool',
      'aardvark',
    ]);

    final byCode = await query(
      const BlockFilter(sort: BlockSort.codeAsc),
    );
    expect(byCode.map((row) => row.code).first, 'aardvark');

    final byCodeDesc = await query(
      const BlockFilter(sort: BlockSort.codeDesc),
    );
    expect(byCodeDesc.map((row) => row.code).first, 'white_wool');
  });

  test('categories list tags in sort order', () async {
    final categories = await repo.categories();
    expect(categories.map((c) => c.name), ['色系', '形状']);
    expect(categories.first.ordered, isTrue);
    expect(categories.first.tags.map((t) => t.name), ['灰', '白']);
  });
}
