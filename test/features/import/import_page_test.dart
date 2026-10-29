import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcblocks/features/import/ui/import_page.dart';

void main() {
  testWidgets('导入页提供模式和文件选择', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ImportPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('导入数据包'), findsOneWidget);
    expect(find.text('增量'), findsOneWidget);
    expect(find.text('全量重建'), findsOneWidget);
    expect(find.text('选择 .mcblocks 文件'), findsOneWidget);
  });
}
