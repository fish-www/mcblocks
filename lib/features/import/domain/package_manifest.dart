import 'import_exception.dart';

/// 数据包里的 `manifest.json`。
///
/// 字段名和 Python 侧生成器保持一致，改这里就要同步改生成器。
final class PackageManifest {
  const PackageManifest({
    required this.formatVersion,
    required this.mcVersion,
    required this.categories,
    required this.tags,
    this.generatedAt,
  });

  static const int supportedFormatVersion = 2;

  final int formatVersion;
  final String mcVersion;
  final String? generatedAt;
  final List<ManifestCategory> categories;
  final List<ManifestTag> tags;

  factory PackageManifest.fromJson(Map<String, Object?> json) {
    final formatVersion = json['format_version'];
    if (formatVersion is! int) {
      throw const ImportException('manifest.json 缺少 format_version');
    }
    if (formatVersion != supportedFormatVersion) {
      throw ImportException(
        '数据包格式版本 $formatVersion，本程序只支持 $supportedFormatVersion',
        '用新版 Python 工具重新生成数据包',
      );
    }

    final rawCategories = json['categories'];
    final rawTags = json['tags'];
    if (rawCategories is! List || rawTags is! List) {
      throw const ImportException('manifest.json 缺少 categories 或 tags');
    }

    return PackageManifest(
      formatVersion: formatVersion,
      mcVersion: json['mc_version'] as String? ?? '',
      generatedAt: json['generated_at'] as String?,
      categories: [
        for (final item in rawCategories)
          ManifestCategory.fromJson(item as Map<String, Object?>),
      ],
      tags: [
        for (final item in rawTags)
          ManifestTag.fromJson(item as Map<String, Object?>),
      ],
    );
  }
}

/// 一个属性维度。
final class ManifestCategory {
  const ManifestCategory({
    required this.code,
    required this.name,
    this.single = false,
    this.ordered = false,
    this.sort = 0,
  });

  final String code;
  final String name;
  final bool single;
  final bool ordered;
  final int sort;

  factory ManifestCategory.fromJson(Map<String, Object?> json) {
    final code = json['code'];
    if (code is! String || code.isEmpty) {
      throw const ImportException('manifest.json 里有分类缺少 code');
    }
    return ManifestCategory(
      code: code,
      name: json['name'] as String? ?? code,
      single: json['single'] == true,
      ordered: json['ordered'] == true,
      sort: json['sort'] as int? ?? 0,
    );
  }
}

/// 一个词表值，`category` 是分类 code。
final class ManifestTag {
  const ManifestTag({
    required this.category,
    required this.code,
    required this.name,
    this.sort = 0,
  });

  final String category;
  final String code;
  final String name;
  final int sort;

  factory ManifestTag.fromJson(Map<String, Object?> json) {
    final category = json['category'];
    final code = json['code'];
    if (category is! String || category.isEmpty) {
      throw const ImportException('manifest.json 里有标签缺少 category');
    }
    if (code is! String || code.isEmpty) {
      throw const ImportException('manifest.json 里有标签缺少 code');
    }
    return ManifestTag(
      category: category,
      code: code,
      name: json['name'] as String? ?? code,
      sort: json['sort'] as int? ?? 0,
    );
  }
}
