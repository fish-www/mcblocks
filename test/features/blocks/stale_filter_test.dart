import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';
import 'package:mcblocks/core/db/database_provider.dart';
import 'package:mcblocks/features/blocks/domain/block_filter.dart';
import 'package:mcblocks/features/blocks/ui/blocks_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime.utc(2026, 10, 29);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );

    final category = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            code: '色系',
            name: '色系',
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final code in ['灰', '白']) {
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              categoryId: category,
              code: code,
              name: code,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('词表删掉标签后，筛选里的旧 ref 自动摘掉', () async {
    final controller = container.read(blockFilterControllerProvider.notifier);
    controller.toggleTag('色系:灰');
    controller.toggleTag('色系:白');

    await (db.delete(db.tags)..where((t) => t.code.equals('灰'))).go();
    await controller.dropStaleTags();

    expect(container.read(blockFilterControllerProvider).tags, ['色系:白']);
  });

  test('词表删掉分类后，筛选的标签和区间一起清掉', () async {
    final controller = container.read(blockFilterControllerProvider.notifier);
    controller.toggleTag('色系:灰');
    controller.setRange(const TagRange(category: '色系', from: 0, to: 1));

    await db.delete(db.tags).go();
    await db.delete(db.categories).go();
    await controller.dropStaleTags();

    final state = container.read(blockFilterControllerProvider);
    expect(state.tags, isEmpty);
    expect(state.range, isNull);
  });
}
