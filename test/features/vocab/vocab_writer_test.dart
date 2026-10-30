import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';
import 'package:mcblocks/features/blocks/data/blocks_repository.dart';
import 'package:mcblocks/features/blocks/domain/patch.dart';
import 'package:mcblocks/features/vocab/data/vocab_writer.dart';

void main() {
  late AppDatabase db;
  late VocabWriter writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    writer = VocabWriter(db);
  });

  tearDown(() => db.close());

  test('新建分类自动顺延 sort', () async {
    await writer.createCategory(code: 'shape', name: '形状', single: true);
    await writer.createCategory(code: 'texture', name: '纹理');

    final rows = await (db.select(
      db.categories,
    )..orderBy([(t) => OrderingTerm(expression: t.sort)])).get();
    expect(rows.map((row) => row.sort), [0, 1]);
    expect(rows.first.single, isTrue);
    expect(rows.first.name, '形状');
  });

  test('分类 code 留空就用名称，名称不能为空', () async {
    await writer.createCategory(code: 'shape', name: '形状');

    await expectLater(
      writer.createCategory(code: 'shape', name: '另一个'),
      throwsA(isA<PatchException>()),
    );

    final id = await writer.createCategory(code: '  ', name: '外形');
    final row = await (db.select(
      db.categories,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.code, '外形');

    await expectLater(
      writer.createCategory(code: 'blank', name: ' '),
      throwsA(isA<PatchException>()),
    );
  });

  test('新建分类跳过 vanilla 的 sort', () async {
    await writer.createCategory(code: 'mod', name: '模组');
    await writer.createCategory(code: 'vanilla', name: '原版', sort: 999);

    await writer.createCategory(code: 'test', name: 'test');

    final row = await (db.select(
      db.categories,
    )..where((t) => t.code.equals('test'))).getSingle();
    expect(row.sort, 1);
    // 读侧把 vanilla 钉在最后。
    final codes = [
      for (final item in await BlocksRepository(db).categories()) item.code,
    ];
    expect(codes, ['mod', 'test', 'vanilla']);
  });

  test('拖拽重排：落到前一个的 sort + 1，后面撞车的依次 + 1', () async {
    await writer.createCategory(code: 'a', name: 'A');
    await writer.createCategory(code: 'b', name: 'B');
    await writer.createCategory(code: 'c', name: 'C');
    await writer.createCategory(code: 'vanilla', name: '原版', sort: 999);

    // a=0, b=1, c=2 → 把 c 拖到 a 后面：c 取 1，b 撞车变 2。
    await writer.reorderCategories(
      ['a', 'c', 'b', 'vanilla'],
      moved: 'c',
    );

    final rows = await (db.select(
      db.categories,
    )..orderBy([(t) => OrderingTerm(expression: t.sort)])).get();
    expect(rows.map((row) => '${row.code}=${row.sort}'), [
      'a=0',
      'c=1',
      'b=2',
      'vanilla=999',
    ]);
  });

  test('拖拽重排：后面的 sort 比它大就不动', () async {
    await writer.createCategory(code: 'a', name: 'A');
    await writer.createCategory(code: 'b', name: 'B', sort: 10);
    await writer.createCategory(code: 'c', name: 'C', sort: 20);

    // 把 a 拖到 b 后面：a 取 11，c=20 比它大，原地不动。
    await writer.reorderCategories(['b', 'a', 'c'], moved: 'a');

    final rows = await (db.select(
      db.categories,
    )..orderBy([(t) => OrderingTerm(expression: t.sort)])).get();
    expect(rows.map((row) => '${row.code}=${row.sort}'), [
      'b=10',
      'a=11',
      'c=20',
    ]);
  });

  test('拖拽重排：拖到最前面取后一个的 sort - 1', () async {
    await writer.createCategory(code: 'a', name: 'A');
    await writer.createCategory(code: 'b', name: 'B');

    await writer.reorderCategories(['b', 'a'], moved: 'b');

    final rows = await (db.select(
      db.categories,
    )..orderBy([(t) => OrderingTerm(expression: t.sort)])).get();
    expect(rows.map((row) => '${row.code}=${row.sort}'), ['b=-1', 'a=0']);
  });

  test('拖拽重排：标签同样规则', () async {
    await writer.createCategory(code: 'texture', name: '纹理');
    await writer.createTag(categoryCode: 'texture', code: '平滑', name: '平滑');
    await writer.createTag(categoryCode: 'texture', code: '粗糙', name: '粗糙');
    await writer.createTag(categoryCode: 'texture', code: '哑光', name: '哑光');

    // 0 平滑, 1 粗糙, 2 哑光 → 把哑光拖到平滑后面：哑光 1，粗糙 2。
    await writer.reorderTags('texture', ['平滑', '哑光', '粗糙'], moved: '哑光');

    final rows = await (db.select(
      db.tags,
    )..orderBy([(t) => OrderingTerm(expression: t.sort)])).get();
    expect(rows.map((row) => '${row.code}=${row.sort}'), [
      '平滑=0',
      '哑光=1',
      '粗糙=2',
    ]);

    await expectLater(
      writer.reorderTags('texture', ['不存在'], moved: '不存在'),
      throwsA(isA<PatchException>()),
    );
  });

  test('标签 code 留空就用名称', () async {
    await writer.createCategory(code: 'texture', name: '纹理');

    final id = await writer.createTag(
      categoryCode: 'texture',
      code: '',
      name: '平滑',
    );
    final row = await (db.select(db.tags)..where((t) => t.id.equals(id)))
        .getSingle();
    expect(row.code, '平滑');
  });

  test('新建标签落到指定分类', () async {
    await writer.createCategory(code: 'texture', name: '纹理');
    await writer.createTag(categoryCode: 'texture', code: '平滑', name: '平滑');
    await writer.createTag(categoryCode: 'texture', code: '粗糙', name: '粗糙');

    final tags = await (db.select(
      db.tags,
    )..orderBy([(t) => OrderingTerm(expression: t.sort)])).get();
    expect(tags.map((tag) => tag.code), ['平滑', '粗糙']);
    expect(tags.map((tag) => tag.sort), [0, 1]);
  });

  test('同分类里标签 code 不能重复', () async {
    await writer.createCategory(code: 'texture', name: '纹理');
    await writer.createTag(categoryCode: 'texture', code: '平滑', name: '平滑');

    await expectLater(
      writer.createTag(categoryCode: 'texture', code: '平滑', name: '再一个'),
      throwsA(isA<PatchException>()),
    );
  });

  test('有序分类的 sort 不能撞车', () async {
    await writer.createCategory(
      code: 'roughness',
      name: '粗糙度',
      ordered: true,
    );
    await writer.createTag(
      categoryCode: 'roughness',
      code: '光滑',
      name: '光滑',
    );

    await expectLater(
      writer.createTag(
        categoryCode: 'roughness',
        code: '粗糙',
        name: '粗糙',
        sort: 0,
      ),
      throwsA(isA<PatchException>()),
    );

    final tag = await writer.createTag(
      categoryCode: 'roughness',
      code: '粗糙',
      name: '粗糙',
      sort: 5,
    );
    expect(tag, greaterThan(0));
  });

  test('分类不存在时报错', () async {
    await expectLater(
      writer.createTag(categoryCode: 'nope', code: 'x', name: 'x'),
      throwsA(isA<PatchException>()),
    );
  });

  test('编辑分类改 code / 名称 / 开关，code 撞车报错', () async {
    await writer.createCategory(code: 'shape', name: '形状');
    await writer.createCategory(code: 'texture', name: '纹理');

    await writer.updateCategory(
      'shape',
      newCode: 'form',
      name: '外形',
      single: false,
      ordered: true,
      sort: 42,
    );

    final row = await (db.select(
      db.categories,
    )..where((t) => t.code.equals('form'))).getSingle();
    expect(row.name, '外形');
    expect(row.single, isFalse);
    expect(row.ordered, isTrue);
    expect(row.sort, 42);

    await expectLater(
      writer.updateCategory('form', newCode: 'texture'),
      throwsA(isA<PatchException>()),
    );
    await expectLater(
      writer.updateCategory('form', name: ' '),
      throwsA(isA<PatchException>()),
    );
  });

  test('vanilla 分类也能删', () async {
    await writer.createCategory(code: 'vanilla', name: '原版');
    await writer.createTag(categoryCode: 'vanilla', code: 'logs', name: 'logs');

    await writer.deleteCategory('vanilla');

    expect(await db.select(db.categories).get(), isEmpty);
    expect(await db.select(db.tags).get(), isEmpty);
  });

  test('删除分类连同标签和方块标注一起清掉', () async {
    await writer.createCategory(code: 'texture', name: '纹理');
    final tag = await writer.createTag(
      categoryCode: 'texture',
      code: '平滑',
      name: '平滑',
    );
    final blockId = await _block(db, 'minecraft:stone');
    await _tagBlock(db, blockId, tag);

    final repo = BlocksRepository(db);
    expect(await repo.tagUsage('texture', '平滑'), 1);
    expect(await repo.categoryUsage('texture'), 1);

    await writer.deleteCategory('texture');

    expect(await db.select(db.categories).get(), isEmpty);
    expect(await db.select(db.tags).get(), isEmpty);
    expect(await db.select(db.blockTags).get(), isEmpty);
    // 方块本身留着，只是没了这个标签。
    expect(await db.select(db.blocks).get(), hasLength(1));
    expect(await repo.tagUsage('texture', '平滑'), 0);
  });

  test('编辑标签改名、改 code、改 sort', () async {
    await writer.createCategory(
      code: 'roughness',
      name: '粗糙度',
      ordered: true,
    );
    await writer.createTag(categoryCode: 'roughness', code: 'a', name: 'a');
    await writer.createTag(categoryCode: 'roughness', code: 'b', name: 'b');

    await writer.updateTag('roughness', 'b', newCode: 'c', name: 'C', sort: 5);

    final row = await (db.select(
      db.tags,
    )..where((t) => t.code.equals('c'))).getSingle();
    expect(row.name, 'C');
    expect(row.sort, 5);

    await expectLater(
      writer.updateTag('roughness', 'c', newCode: 'a'),
      throwsA(isA<PatchException>()),
    );
    await expectLater(
      writer.updateTag('roughness', 'c', sort: 0),
      throwsA(isA<PatchException>()),
    );
    await expectLater(
      writer.updateTag('roughness', 'c', name: ''),
      throwsA(isA<PatchException>()),
    );
  });

  test('删除标签只清掉它自己的标注', () async {
    await writer.createCategory(code: 'texture', name: '纹理');
    final smooth = await writer.createTag(
      categoryCode: 'texture',
      code: '平滑',
      name: '平滑',
    );
    final rough = await writer.createTag(
      categoryCode: 'texture',
      code: '粗糙',
      name: '粗糙',
    );
    final stone = await _block(db, 'minecraft:stone');
    final dirt = await _block(db, 'minecraft:dirt');
    await _tagBlock(db, stone, smooth);
    await _tagBlock(db, stone, rough);
    await _tagBlock(db, dirt, smooth);

    final repo = BlocksRepository(db);
    expect(await repo.tagUsage('texture', '平滑'), 2);
    expect(await repo.categoryUsage('texture'), 2);

    await writer.deleteTag('texture', '平滑');

    final rows = await db.select(db.blockTags).get();
    expect(rows, hasLength(1));
    expect(rows.single.tagId, rough);
    expect(await db.select(db.tags).get(), hasLength(1));
    expect(await repo.categoryUsage('texture'), 1);
  });
}

Future<int> _block(AppDatabase db, String code) {
  final now = DateTime.now().toUtc();
  return db
      .into(db.blocks)
      .insert(BlocksCompanion.insert(code: code, createdAt: now, updatedAt: now));
}

Future<void> _tagBlock(AppDatabase db, int blockId, int tagId) {
  final now = DateTime.now().toUtc();
  return db
      .into(db.blockTags)
      .insert(
        BlockTagsCompanion.insert(
          blockId: blockId,
          tagId: tagId,
          createdAt: now,
          updatedAt: now,
        ),
      );
}
