import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';
import 'package:mcblocks/core/db/database_provider.dart';
import 'package:mcblocks/features/blocks/ui/blocks_page.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 29);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    for (var index = 0; index < 25; index++) {
      final suffix = index.toString().padLeft(2, '0');
      await db
          .into(db.blocks)
          .insert(
            BlocksCompanion.insert(
              code: 'block_$suffix',
              nameZh: Value('方块$suffix'),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(() => db.close());

  testWidgets('分页：每页 20 条，支持上下页、首尾页和跳转', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          texturesRootProvider.overrideWith(
            (ref) async => '/tmp/mcblocks-missing',
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: BlocksPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('共 25 个方块'), findsOneWidget);
    expect(find.text('第 1 / 2 页'), findsOneWidget);
    expect(find.text('方块00'), findsOneWidget);
    expect(find.text('方块20'), findsNothing);

    await tester.tap(find.byTooltip('下一页'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 / 2 页'), findsOneWidget);
    expect(find.text('方块20'), findsOneWidget);
    expect(find.text('方块00'), findsNothing);
    expect(find.text('方块24'), findsOneWidget);

    await tester.tap(find.byTooltip('首页'));
    await tester.pumpAndSettle();
    expect(find.text('第 1 / 2 页'), findsOneWidget);

    await tester.tap(find.byTooltip('尾页'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 / 2 页'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '页码'), '1');
    await tester.tap(find.text('跳转'));
    await tester.pumpAndSettle();
    expect(find.text('第 1 / 2 页'), findsOneWidget);
    expect(find.text('方块00'), findsOneWidget);
  });

  testWidgets('翻页时列表不清空，只出一条细进度条', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          texturesRootProvider.overrideWith(
            (ref) async => '/tmp/mcblocks-missing',
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: BlocksPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('下一页'));
    await tester.pump(); // 只推进一帧：数据还在路上

    // 上一页的内容还在，只多了一条进度条，不会整块闪成转圈。
    expect(find.text('方块00'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('方块20'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
