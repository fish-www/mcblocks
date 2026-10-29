import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/core/db/app_database.dart';
import 'package:mcblocks/core/db/database_provider.dart';

void main() {
  test('对照组：autoDispose provider 在无监听时会被回收', () async {
    var created = 0;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final provider = Provider.autoDispose<int>((ref) => ++created);
    container.read(provider);
    await Future<void>.delayed(Duration.zero);
    container.read(provider);

    expect(created, 2);
  });

  test('数据库 provider 常驻，导入期间不会被回收', () async {
    var created = 0;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          created++;
          final database = AppDatabase(NativeDatabase.memory());
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    // 模拟导入控制器：只 read，不挂监听。
    final first = container.read(appDatabaseProvider);
    await Future<void>.delayed(Duration.zero);
    final second = container.read(appDatabaseProvider);

    expect(identical(first, second), isTrue);
    expect(created, 1);

    // 连接还活着：能继续执行语句。
    await second.customStatement('SELECT 1');
  });
}
