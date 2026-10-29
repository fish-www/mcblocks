// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'block_writer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(blockWriter)
final blockWriterProvider = BlockWriterProvider._();

final class BlockWriterProvider
    extends $FunctionalProvider<BlockWriter, BlockWriter, BlockWriter>
    with $Provider<BlockWriter> {
  BlockWriterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blockWriterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blockWriterHash();

  @$internal
  @override
  $ProviderElement<BlockWriter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BlockWriter create(Ref ref) {
    return blockWriter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlockWriter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlockWriter>(value),
    );
  }
}

String _$blockWriterHash() => r'0da110c35b8824f0fb8b87974096849d708d06b7';
