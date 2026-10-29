import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 29);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('creates the six contract tables', () async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = rows.map((row) => row.read<String>('name')).toSet();
    expect(names, containsAll(<String>[
      'meta',
      'block',
      'texture',
      'category',
      'tag',
      'block_tag',
    ]));
  });

  test('foreign keys are enforced', () async {
    await expectLater(
      db
          .into(db.blockTags)
          .insert(
            BlockTagsCompanion.insert(
              blockId: 999,
              tagId: 999,
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('tag code is unique per category', () async {
    final categoryId = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            code: '色系',
            name: '色系',
            createdAt: now,
            updatedAt: now,
          ),
        );

    Future<int> insertTag() => db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            categoryId: categoryId,
            code: '灰',
            name: '灰',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await insertTag();
    await expectLater(insertTag(), throwsA(isA<SqliteException>()));
  });
}
