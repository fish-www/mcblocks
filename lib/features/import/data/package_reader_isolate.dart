import 'dart:isolate';
import 'dart:typed_data';

import '../domain/parsed_package.dart';
import 'package_reader.dart';

/// 解压和 JSON 解析是 CPU 活，放进 isolate 跑，别卡 UI。
Future<ParsedPackage> parsePackageInIsolate(Uint8List bytes) =>
    Isolate.run(() => const PackageReader().parse(bytes));
