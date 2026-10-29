import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';
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

  test('分类 code 不能重复，也不能为空', () async {
    await writer.createCategory(code: 'shape', name: '形状');

    await expectLater(
      writer.createCategory(code: 'shape', name: '另一个'),
      throwsA(isA<PatchException>()),
    );
    await expectLater(
      writer.createCategory(code: '  ', name: '空 code'),
      throwsA(isA<PatchException>()),
    );
    await expectLater(
      writer.createCategory(code: 'blank', name: ' '),
      throwsA(isA<PatchException>()),
    );
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
}
