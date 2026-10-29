import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('schema 版本不一致时整库重建', () async {
    final dir = await Directory.systemTemp.createTemp('mcblocks_migrate');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/blocks.db';

    // 手造一个旧库：多一张旧表，schema 版本落后。
    final raw = sqlite3.open(path);
    raw.execute('CREATE TABLE old_stuff (x INTEGER)');
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    final db = AppDatabase(NativeDatabase(File(path)));
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = {for (final row in tables) row.read<String>('name')};
    final blocks = await db
        .customSelect('SELECT COUNT(*) AS n FROM block')
        .getSingle();

    expect(names, isNot(contains('old_stuff')));
    expect(names, containsAll(['block', 'block_texture']));
    expect(blocks.read<int>('n'), 0);
    await db.close();
  });
}
