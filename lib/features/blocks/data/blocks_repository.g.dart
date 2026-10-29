// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocks_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(blocksRepository)
final blocksRepositoryProvider = BlocksRepositoryProvider._();

final class BlocksRepositoryProvider
    extends
        $FunctionalProvider<
          BlocksRepository,
          BlocksRepository,
          BlocksRepository
        >
    with $Provider<BlocksRepository> {
  BlocksRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blocksRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blocksRepositoryHash();

  @$internal
  @override
  $ProviderElement<BlocksRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BlocksRepository create(Ref ref) {
    return blocksRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlocksRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlocksRepository>(value),
    );
  }
}

String _$blocksRepositoryHash() => r'67bdbc768317379d75364b323f4310bd1850948c';
