// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocks_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 当前筛选条件。列表和计数都从这里派生。

@ProviderFor(BlockFilterController)
final blockFilterControllerProvider = BlockFilterControllerProvider._();

/// 当前筛选条件。列表和计数都从这里派生。
final class BlockFilterControllerProvider
    extends $NotifierProvider<BlockFilterController, BlockFilter> {
  /// 当前筛选条件。列表和计数都从这里派生。
  BlockFilterControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blockFilterControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blockFilterControllerHash();

  @$internal
  @override
  BlockFilterController create() => BlockFilterController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlockFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlockFilter>(value),
    );
  }
}

String _$blockFilterControllerHash() =>
    r'1cb4323217f194d613f08cf963cb7468ebfc66b8';

/// 当前筛选条件。列表和计数都从这里派生。

abstract class _$BlockFilterController extends $Notifier<BlockFilter> {
  BlockFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BlockFilter, BlockFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BlockFilter, BlockFilter>,
              BlockFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(blockPage)
final blockPageProvider = BlockPageProvider._();

final class BlockPageProvider
    extends
        $FunctionalProvider<
          AsyncValue<BlockPage>,
          BlockPage,
          FutureOr<BlockPage>
        >
    with $FutureModifier<BlockPage>, $FutureProvider<BlockPage> {
  BlockPageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blockPageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blockPageHash();

  @$internal
  @override
  $FutureProviderElement<BlockPage> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<BlockPage> create(Ref ref) {
    return blockPage(ref);
  }
}

String _$blockPageHash() => r'465db65c1cc8e2b5321ce436b5d5b3f3d3be3951';

@ProviderFor(categories)
final categoriesProvider = CategoriesProvider._();

final class CategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CategoryWithTags>>,
          List<CategoryWithTags>,
          FutureOr<List<CategoryWithTags>>
        >
    with
        $FutureModifier<List<CategoryWithTags>>,
        $FutureProvider<List<CategoryWithTags>> {
  CategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoriesHash();

  @$internal
  @override
  $FutureProviderElement<List<CategoryWithTags>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CategoryWithTags>> create(Ref ref) {
    return categories(ref);
  }
}

String _$categoriesHash() => r'276d14e642306587f606392620348f882b7b8816';

@ProviderFor(blockDetail)
final blockDetailProvider = BlockDetailFamily._();

final class BlockDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<BlockDetail?>,
          BlockDetail?,
          FutureOr<BlockDetail?>
        >
    with $FutureModifier<BlockDetail?>, $FutureProvider<BlockDetail?> {
  BlockDetailProvider._({
    required BlockDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'blockDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$blockDetailHash();

  @override
  String toString() {
    return r'blockDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BlockDetail?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BlockDetail?> create(Ref ref) {
    final argument = this.argument as String;
    return blockDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BlockDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$blockDetailHash() => r'894e874fe3709d1cb58dc9782dfd07df6a43ddc2';

final class BlockDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BlockDetail?>, String> {
  BlockDetailFamily._()
    : super(
        retry: null,
        name: r'blockDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BlockDetailProvider call(String code) =>
      BlockDetailProvider._(argument: code, from: this);

  @override
  String toString() => r'blockDetailProvider';
}

/// 宽屏时右侧详情面板显示哪个方块。

@ProviderFor(SelectedBlock)
final selectedBlockProvider = SelectedBlockProvider._();

/// 宽屏时右侧详情面板显示哪个方块。
final class SelectedBlockProvider
    extends $NotifierProvider<SelectedBlock, String?> {
  /// 宽屏时右侧详情面板显示哪个方块。
  SelectedBlockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedBlockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedBlockHash();

  @$internal
  @override
  SelectedBlock create() => SelectedBlock();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$selectedBlockHash() => r'cf63ac02d94a97fa1315fe9e6611c484c0a75496';

/// 宽屏时右侧详情面板显示哪个方块。

abstract class _$SelectedBlock extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
