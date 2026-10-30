import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';
import 'package:mcblocks/core/db/database_provider.dart';
import 'package:mcblocks/features/vocab/ui/vocab_page.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 29);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            code: 'mod',
            name: '模组',
            sort: const Value(1),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final texture = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            code: 'texture',
            name: '纹理',
            sort: const Value(3),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            code: 'vanilla',
            name: '原版',
            sort: const Value(999),
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final (code, sort) in [('平滑', 7), ('粗糙', 8)]) {
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              categoryId: texture,
              code: code,
              name: code,
              sort: Value(sort),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(() => db.close());

  testWidgets('分类行显示 sort，卡片和标签都能拖', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: VocabPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('texture · 2 个标签 · sort 3'), findsOneWidget);
    // mod、texture 有拖拽手柄，vanilla 没有。
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));

    await tester.tap(find.text('纹理'));
    await tester.pumpAndSettle();

    expect(find.text('sort 7'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(4));
  });

  testWidgets('拖分类手柄会写回新的 sort 顺序', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: VocabPage())),
      ),
    );
    await tester.pumpAndSettle();

    // 0 是 mod，1 是 texture。把 texture 拖到最前。
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_indicator).at(1)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final rows = await (db.select(
      db.categories,
    )..orderBy([(t) => OrderingTerm(expression: t.sort)])).get();
    expect(rows.map((row) => '${row.code}=${row.sort}'), [
      'texture=0',
      'mod=1',
      'vanilla=999',
    ]);
  });

  testWidgets('拖标签手柄会写回新的 sort 顺序', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: VocabPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('纹理'));
    await tester.pumpAndSettle();

    // 手柄顺序：mod、texture 两个分类，然后「平滑」、「粗糙」两个标签。
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_indicator).at(2)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final rows = await (db.select(
      db.tags,
    )..orderBy([(t) => OrderingTerm(expression: t.sort)])).get();
    expect(rows.map((row) => row.code), ['粗糙', '平滑']);
  });

  testWidgets('新建分类：光标落在名称，sort 能填', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: VocabPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建分类'));
    await tester.pumpAndSettle();

    // 不点任何输入框，直接打字应该落在「名称」里。
    tester.testTextInput.enterText('测试');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      '测试',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      '',
    );

    await tester.enterText(find.byType(TextField).at(2), '42');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    final row = await (db.select(
      db.categories,
    )..where((t) => t.code.equals('测试'))).getSingle();
    expect(row.sort, 42);
  });
}
