// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 数据库必须常驻：drift 的连接跑在后台 isolate 里，
/// 一旦 provider 被自动回收，连接关闭，正在进行的 import 会直接失败。

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// 数据库必须常驻：drift 的连接跑在后台 isolate 里，
/// 一旦 provider 被自动回收，连接关闭，正在进行的 import 会直接失败。

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// 数据库必须常驻：drift 的连接跑在后台 isolate 里，
  /// 一旦 provider 被自动回收，连接关闭，正在进行的 import 会直接失败。
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'70c3dbadb2ffa5347d5e7a99875b56e51b8511d8';

/// 贴图根目录。UI 拼 `sha/<hash 前两位>/<hash>.webp` 读文件。

@ProviderFor(texturesRoot)
final texturesRootProvider = TexturesRootProvider._();

/// 贴图根目录。UI 拼 `sha/<hash 前两位>/<hash>.webp` 读文件。

final class TexturesRootProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// 贴图根目录。UI 拼 `sha/<hash 前两位>/<hash>.webp` 读文件。
  TexturesRootProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'texturesRootProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$texturesRootHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return texturesRoot(ref);
  }
}

String _$texturesRootHash() => r'5e1e952f7dcf4cc3200c102e4ad66f0690df04f4';
