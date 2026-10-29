// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'package_exporter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(packageExporter)
final packageExporterProvider = PackageExporterProvider._();

final class PackageExporterProvider
    extends
        $FunctionalProvider<
          AsyncValue<PackageExporter>,
          PackageExporter,
          FutureOr<PackageExporter>
        >
    with $FutureModifier<PackageExporter>, $FutureProvider<PackageExporter> {
  PackageExporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'packageExporterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$packageExporterHash();

  @$internal
  @override
  $FutureProviderElement<PackageExporter> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PackageExporter> create(Ref ref) {
    return packageExporter(ref);
  }
}

String _$packageExporterHash() => r'cabc59e4f6a840c2d178acf4ddf4691ce4d3ef38';
