import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';
import 'package:mcblocks/core/db/database_provider.dart';
import 'package:mcblocks/features/blocks/ui/blocks_page.dart';

void main() {
  testWidgets('空库显示导入入口', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const BlocksPage()));
    await tester.pumpAndSettle();

    expect(find.text('还没有方块数据'), findsOneWidget);
    expect(find.text('导入数据包'), findsOneWidget);
  });

  testWidgets('有数据时按显示名列出方块', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 10, 29);

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

    await tester.pumpWidget(_wrap(db, const BlocksPage()));
    await tester.pumpAndSettle();

    expect(find.text('共 1 个方块'), findsOneWidget);
    expect(find.text('石头'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
  });
}

Widget _wrap(AppDatabase db, Widget child) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    texturesRootProvider.overrideWith(
      (ref) async => '/tmp/mcblocks-missing',
    ),
  ],
  child: MaterialApp(home: Scaffold(body: child)),
);
