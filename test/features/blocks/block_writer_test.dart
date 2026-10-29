import 'package:drift/drift.dart' show Value;
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';
import 'package:mcblocks/features/blocks/data/block_writer.dart';
import 'package:mcblocks/features/blocks/domain/patch.dart';

void main() {
  late AppDatabase db;
  late BlockWriter writer;
  late Directory textures;
  final now = DateTime.utc(2026, 10, 29);

  late int colorCategory;
  late int vanityCategory;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    textures = Directory.systemTemp.createTempSync('mcblocks_writer');
    writer = BlockWriter(db, texturesDirectory: () async => textures);

    colorCategory = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            code: '色系',
            name: '色系',
            single: const Value(true),
            ordered: const Value(true),
            sort: const Value(10),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final shape = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            code: '形状',
            name: '形状',
            single: const Value(true),
            sort: const Value(20),
            createdAt: now,
            updatedAt: now,
          ),
        );
    vanityCategory = await db
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

    Future<int> tag(int categoryId, String code, {int sort = 0}) => db
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

    final grey = await tag(colorCategory, '灰', sort: 1);
    await tag(colorCategory, '白', sort: 2);
    final cube = await tag(shape, '立方');
    final pickaxe = await tag(vanityCategory, 'mineable/pickaxe');
    await tag(vanityCategory, 'logs');

    final stone = await db
        .into(db.blocks)
        .insert(
          BlocksCompanion.insert(
            code: 'stone',
            nameZh: const Value('石头'),
            colorHex: const Value('#7f7f7f'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    Future<void> link(int tagId, String source) => db
        .into(db.blockTags)
        .insert(
          BlockTagsCompanion.insert(
            blockId: stone,
            tagId: tagId,
            source: Value(source),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await link(grey, 'auto');
    await link(cube, 'user');
    await link(pickaxe, 'vanilla');
  });

  tearDown(() async {
    await db.close();
    if (textures.existsSync()) textures.deleteSync(recursive: true);
  });

  Future<Block> stone() => (db.select(
    db.blocks,
  )..where((t) => t.code.equals('stone'))).getSingle();

  Future<List<String>> tagRefs() async {
    final rows = await db
        .customSelect(
          '''
SELECT c.code AS category, t.code AS tag, bt.source AS source
FROM block_tag bt
JOIN tag t ON t.id = bt.tag_id
JOIN category c ON c.id = t.category_id
ORDER BY c.code, t.code
''',
        )
        .get();
    return [
      for (final row in rows)
        '${row.read<String>('category')}:${row.read<String>('tag')}'
            '(${row.read<String>('source')})',
    ];
  }

  test('单选分类加新值会替换旧值', () async {
    await writer.apply(
      const BlockPatch(code: 'stone', addTags: [PatchTag('色系:白')]),
    );

    expect(await tagRefs(), contains('色系:白(user)'));
    expect(await tagRefs(), isNot(contains('色系:灰(auto)')));
  });

  test('多选分类只在末尾追加', () async {
    await writer.apply(
      const BlockPatch(code: 'stone', addTags: [PatchTag('vanilla:logs')]),
    );

    final refs = await tagRefs();
    expect(refs, contains('vanilla:mineable/pickaxe(vanilla)'));
    expect(refs, contains('vanilla:logs(user)'));
  });

  test('可以删除自动和手动标签', () async {
    await writer.apply(
      const BlockPatch(code: 'stone', removeTags: ['形状:立方', '色系:灰']),
    );
    expect(await tagRefs(), ['vanilla:mineable/pickaxe(vanilla)']);
  });

  test('原版标签不能手工删除，且不影响其他修改', () async {
    await expectLater(
      writer.apply(
        const BlockPatch(
          code: 'stone',
          reviewed: Value(true),
          removeTags: ['vanilla:mineable/pickaxe'],
        ),
      ),
      throwsA(isA<PatchException>()),
    );
    expect((await stone()).reviewed, isFalse);
    expect(await tagRefs(), contains('vanilla:mineable/pickaxe(vanilla)'));
  });

  test('未知标签让整次修改回滚', () async {
    await expectLater(
      writer.apply(
        const BlockPatch(
          code: 'stone',
          reviewed: Value(true),
          addTags: [PatchTag('色系:紫')],
        ),
      ),
      throwsA(isA<PatchException>()),
    );
    expect((await stone()).reviewed, isFalse);
  });

  test('可以切换审核状态', () async {
    await writer.apply(const BlockPatch(code: 'stone', reviewed: Value(true)));
    expect((await stone()).reviewed, isTrue);

    await writer.apply(const BlockPatch(code: 'stone', reviewed: Value(false)));
    expect((await stone()).reviewed, isFalse);
  });

  test('找不到方块直接报错', () async {
    await expectLater(
      writer.apply(const BlockPatch(code: 'nope', reviewed: Value(true))),
      throwsA(isA<PatchException>()),
    );
  });

  test('新建方块：code 唯一且格式受限', () async {
    final id = await writer.createBlock(
      code: 'test:custom_block',
      nameZh: '自定义方块',
      colorHex: '#AABBCC',
    );
    expect(id, greaterThan(0));
    final row = await (db.select(
      db.blocks,
    )..where((t) => t.code.equals('test:custom_block'))).getSingle();
    expect(row.nameZh, '自定义方块');
    expect(row.colorHex, '#aabbcc');

    await expectLater(
      writer.createBlock(code: 'test:custom_block'),
      throwsA(isA<PatchException>()),
    );
    await expectLater(
      writer.createBlock(code: 'Bad Code'),
      throwsA(isA<PatchException>()),
    );
    await expectLater(
      writer.createBlock(code: 'x:y', colorHex: '#12345'),
      throwsA(isA<PatchException>()),
    );
  });

  test('删除方块连带标签和材质', () async {
    await writer.deleteBlock('stone');
    expect(await db.select(db.blocks).get(), isEmpty);
    expect(await db.select(db.blockTags).get(), isEmpty);
    expect(await db.select(db.blockTextures).get(), isEmpty);
  });

  test('材质可以重命名、排序、删除', () async {
    await writer.createBlock(code: 'test:tex_block');
    await writer.addTexture(
      'test:tex_block',
      key: 'a',
      bytes: _png(0xAA),
    );
    await writer.addTexture(
      'test:tex_block',
      key: 'b',
      bytes: _png(0xBB),
    );

    await writer.renameTexture('test:tex_block', 'a', 'side');
    await writer.moveTexture('test:tex_block', 'b', -1);
    final rows = await (db.select(
      db.blockTextures,
    )..orderBy([(t) => OrderingTerm(expression: t.sort)])).get();
    expect(rows.map((row) => row.key), ['b', 'side']);

    await writer.deleteTexture('test:tex_block', 'b');
    final left = await db.select(db.blockTextures).get();
    expect(left.map((row) => row.key), ['side']);
  });

  test('加贴图会写入文件和 texture 行，并补齐图标', () async {
    await writer.createBlock(code: 'test:tex_block2');
    await writer.addTexture('test:tex_block2', key: 'all', bytes: _png(0x11));

    final block = await (db.select(
      db.blocks,
    )..where((t) => t.code.equals('test:tex_block2'))).getSingle();
    expect(block.iconId, isNotNull);
    final texture = await (db.select(
      db.textures,
    )..where((t) => t.id.equals(block.iconId!))).getSingle();
    final file = File(
      '${textures.path}/sha/${texture.hash.substring(0, 2)}/${texture.hash}.webp',
    );
    expect(file.existsSync(), isTrue);
  });

  test('编辑信息：改 code、名字和图标', () async {
    await writer.createBlock(code: 'test:edit_me', nameZh: '旧名字');
    await writer.addTexture('test:edit_me', key: 'all', bytes: _png(0x33));

    final updated = await writer.updateBlock(
      'test:edit_me',
      newCode: 'test:edited',
      nameZh: '新名字',
      nameEn: '',
      iconKey: 'all',
    );
    expect(updated, 'test:edited');

    final row = await (db.select(
      db.blocks,
    )..where((t) => t.code.equals('test:edited'))).getSingle();
    expect(row.nameZh, '新名字');
    expect(row.nameEn, isNull);
    expect(row.iconId, isNotNull);

    // 再传空字符串就是清空。
    await writer.updateBlock('test:edited', nameZh: '');
    final cleared = await (db.select(
      db.blocks,
    )..where((t) => t.code.equals('test:edited'))).getSingle();
    expect(cleared.nameZh, isNull);

    await expectLater(
      writer.updateBlock('edited', newCode: 'minecraft:stone'),
      throwsA(isA<PatchException>()),
    );
  });
}

Uint8List _png(int shade) {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgba8(shade, shade, shade, 255));
  return Uint8List.fromList(img.encodePng(image));
}
