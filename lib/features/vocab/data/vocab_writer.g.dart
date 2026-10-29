// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocab_writer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vocabWriter)
final vocabWriterProvider = VocabWriterProvider._();

final class VocabWriterProvider
    extends $FunctionalProvider<VocabWriter, VocabWriter, VocabWriter>
    with $Provider<VocabWriter> {
  VocabWriterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vocabWriterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vocabWriterHash();

  @$internal
  @override
  $ProviderElement<VocabWriter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VocabWriter create(Ref ref) {
    return vocabWriter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VocabWriter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VocabWriter>(value),
    );
  }
}

String _$vocabWriterHash() => r'a4efc25f25fa938176677d820e952044f67f0478';
