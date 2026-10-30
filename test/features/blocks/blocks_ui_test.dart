import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';
import 'package:mcblocks/core/db/database_provider.dart';
import 'package:mcblocks/features/blocks/ui/blocks_page.dart';
import 'package:mcblocks/features/blocks/ui/widgets/block_detail_panel.dart';
import 'package:mcblocks/features/blocks/ui/widgets/block_thumbnail.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 29);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    final color = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            code: '色系',
            name: '色系',
            single: const Value(true),
            sort: const Value(10),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final vanilla = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            code: 'vanilla',
            name: '原版',
            sort: const Value(40),
            createdAt: now,
            updatedAt: now,
          ),
        );

    Future<int> tag(int categoryId, String code) => db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            categoryId: categoryId,
            code: code,
            name: code,
            createdAt: now,
            updatedAt: now,
          ),
        );

    final grey = await tag(color, '灰');
    final white = await tag(color, '白');
    final pickaxe = await tag(vanilla, 'mineable/pickaxe');

    Future<int> block(String code, String nameZh) => db
        .into(db.blocks)
        .insert(
          BlocksCompanion.insert(
            code: code,
            nameZh: Value(nameZh),
            createdAt: now,
            updatedAt: now,
          ),
        );

    Future<void> link(int blockId, int tagId, String source) => db
        .into(db.blockTags)
        .insert(
          BlockTagsCompanion.insert(
            blockId: blockId,
            tagId: tagId,
            source: Value(source),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final stone = await block('stone', '石头');
    final glass = await block('glass', '玻璃');
    await link(stone, grey, 'user');
    await link(stone, pickaxe, 'vanilla');
    await link(glass, white, 'auto');
  });

  tearDown(() => db.close());

  testWidgets('列表只显示非原版标签', (tester) async {
    await tester.pumpWidget(_wrap(db, const BlocksPage()));
    await tester.pumpAndSettle();

    expect(find.textContaining('色系:灰'), findsOneWidget);
    expect(find.textContaining('mineable'), findsNothing);
    expect(find.textContaining('共 2 个方块'), findsOneWidget);
  });

  testWidgets('点标签筛选后列表收敛', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(db, const BlocksPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, '筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '白'));
    await tester.pumpAndSettle();

    expect(find.text('玻璃'), findsOneWidget);
    expect(find.text('石头'), findsNothing);
    expect(find.text('筛选 1'), findsOneWidget);
  });

  testWidgets('点列表或拖动列表时筛选面板自动收起', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(db, const BlocksPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, '筛选'));
    await tester.pumpAndSettle();
    expect(find.text('清除筛选'), findsOneWidget);

    // 点列表区域（这里点列表上方的计数文本）：面板收起。
    await tester.tap(find.text('共 2 个方块'));
    await tester.pumpAndSettle();
    expect(find.text('清除筛选'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, '筛选'));
    await tester.pumpAndSettle();
    expect(find.text('清除筛选'), findsOneWidget);

    // 拖动列表（哪怕内容不够长）也算离开面板。
    await tester.drag(find.byType(ListView).first, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.text('清除筛选'), findsNothing);
  });

  testWidgets('同一模式下多选走交集，切到任一走并集', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(db, const BlocksPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, '筛选'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, '灰'));
    await tester.pumpAndSettle();
    expect(find.text('石头'), findsOneWidget);
    expect(find.text('玻璃'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, '白'));
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的方块'), findsOneWidget);

    await tester.tap(find.text('任一'));
    await tester.pumpAndSettle();
    expect(find.text('石头'), findsOneWidget);
    expect(find.text('玻璃'), findsOneWidget);
    expect(find.text('共 2 个方块'), findsOneWidget);
  });

  testWidgets('详情页可以标记审核', (tester) async {
    await tester.pumpWidget(_wrap(db, const BlockDetailPanel(code: 'stone')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标记已审核'));
    await tester.pumpAndSettle();

    final row = await (db.select(
      db.blocks,
    )..where((t) => t.code.equals('stone'))).getSingle();
    expect(row.reviewed, isTrue);
  });

  testWidgets('点名称和 code 都会复制', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(_wrap(db, const BlockDetailPanel(code: 'stone')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('石头'));
    await tester.pumpAndSettle();
    expect(copied, contains('石头'));

    await tester.tap(find.text('stone'));
    await tester.pumpAndSettle();
    expect(copied, contains('stone'));
  });

  testWidgets('缩略图尺寸固定 40×40', (tester) async {
    await tester.pumpWidget(
      _wrap(
        db,
        const Center(
          child: BlockThumbnail(
            hash: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(BlockThumbnail)), const Size(40, 40));
  });

  testWidgets('详情页原版标签默认折叠', (tester) async {
    await tester.pumpWidget(
      _wrap(db, const BlockDetailPanel(code: 'stone')),
    );
    await tester.pumpAndSettle();

    expect(find.text('原版标签 (1)'), findsOneWidget);
    expect(find.text('mineable/pickaxe'), findsNothing);
    // 标签按分类竖排：左边分类名，右边标签。
    expect(find.text('色系：'), findsOneWidget);
    expect(find.text('灰'), findsOneWidget);

    await tester.tap(find.text('原版标签 (1)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('mineable/pickaxe'), findsWidgets);
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
