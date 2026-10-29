import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart' hide BlockTag;
import '../../../core/db/database_provider.dart';
import '../../blocks/domain/patch.dart';

part 'vocab_writer.g.dart';

@riverpod
VocabWriter vocabWriter(Ref ref) =>
    VocabWriter(ref.watch(appDatabaseProvider));

/// 词表的写入口。和标注写入一样，一个方法一个事务。
///
/// 规则：
/// - code 必须非空且在各自作用域内唯一
/// - `ordered` 分类的 `sort` 必须唯一；不填时自动取最大值 + 1
class VocabWriter {
  VocabWriter(this._db);

  final AppDatabase _db;

  Future<int> createCategory({
    required String code,
    required String name,
    bool single = false,
    bool ordered = false,
    int? sort,
  }) async {
    final trimmedCode = code.trim();
    final trimmedName = name.trim();
    if (trimmedCode.isEmpty || trimmedName.isEmpty) {
      throw const PatchException('分类的 code 和名称都不能为空');
    }

    return _db.transaction(() async {
      final exists = await (_db.select(
        _db.categories,
      )..where((t) => t.code.equals(trimmedCode))).getSingleOrNull();
      if (exists != null) {
        throw PatchException('分类 $trimmedCode 已存在');
      }

      final now = DateTime.now().toUtc();
      return _db
          .into(_db.categories)
          .insert(
            CategoriesCompanion.insert(
              code: trimmedCode,
              name: trimmedName,
              single: Value(single),
              ordered: Value(ordered),
              sort: Value(sort ?? await _nextCategorySort()),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  Future<int> createTag({
    required String categoryCode,
    required String code,
    required String name,
    int? sort,
  }) async {
    final trimmedCode = code.trim();
    final trimmedName = name.trim();
    if (trimmedCode.isEmpty || trimmedName.isEmpty) {
      throw const PatchException('标签的 code 和名称都不能为空');
    }

    return _db.transaction(() async {
      final category = await (_db.select(
        _db.categories,
      )..where((t) => t.code.equals(categoryCode))).getSingleOrNull();
      if (category == null) {
        throw PatchException('分类 $categoryCode 不存在');
      }

      final exists = await (_db.select(_db.tags)..where(
            (t) => t.categoryId.equals(category.id) & t.code.equals(trimmedCode),
          ))
          .getSingleOrNull();
      if (exists != null) {
        throw PatchException('分类 ${category.name} 里已有标签 $trimmedCode');
      }

      final now = DateTime.now().toUtc();
      final tagSort = sort ?? await _nextTagSort(category.id);
      if (category.ordered) {
        final clash = await (_db.select(_db.tags)..where(
              (t) => t.categoryId.equals(category.id) & t.sort.equals(tagSort),
            ))
            .getSingleOrNull();
        if (clash != null) {
          throw PatchException(
            '有序分类 ${category.name} 的 sort=$tagSort 已被占用',
            '换一个数字，或者留空自动顺延',
          );
        }
      }

      return _db
          .into(_db.tags)
          .insert(
            TagsCompanion.insert(
              categoryId: category.id,
              code: trimmedCode,
              name: trimmedName,
              sort: Value(tagSort),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  Future<int> _nextCategorySort() async {
    final row = await _db
        .customSelect('SELECT COALESCE(MAX(sort), -1) + 1 AS next FROM category')
        .getSingle();
    return row.read<int>('next');
  }

  Future<int> _nextTagSort(int categoryId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(sort), -1) + 1 AS next FROM tag WHERE category_id = ?',
          variables: [Variable.withInt(categoryId)],
        )
        .getSingle();
    return row.read<int>('next');
  }
}
