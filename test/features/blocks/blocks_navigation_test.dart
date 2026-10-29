import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/app/router.dart';
import 'package:mcblocks/core/db/app_database.dart';
import 'package:mcblocks/core/db/database_provider.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 29);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final stone = await db
        .into(db.blocks)
        .insert(
          BlocksCompanion.insert(
            code: 'stone',
            nameZh: const Value('石头'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.blocks)
        .insert(
          BlocksCompanion.insert(
            code: 'stone_slab',
            nameZh: const Value('石台阶'),
            variantOf: Value(stone),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() => db.close());

  testWidgets('窄屏点变体进入详情后可以返回上一页', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          texturesRootProvider.overrideWith(
            (ref) async => '/tmp/mcblocks-missing',
          ),
        ],
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('石头'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '石头'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, '石台阶'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '石台阶'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '石头'), findsOneWidget);
  });
}
