// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'package_importer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(packageImporter)
final packageImporterProvider = PackageImporterProvider._();

final class PackageImporterProvider
    extends
        $FunctionalProvider<
          AsyncValue<PackageImporter>,
          PackageImporter,
          FutureOr<PackageImporter>
        >
    with $FutureModifier<PackageImporter>, $FutureProvider<PackageImporter> {
  PackageImporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'packageImporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$packageImporterHash();

  @$internal
  @override
  $FutureProviderElement<PackageImporter> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PackageImporter> create(Ref ref) {
    return packageImporter(ref);
  }
}

String _$packageImporterHash() => r'2e9c558b99a6e54bccbf87e27d5088ddc73c43d1';
