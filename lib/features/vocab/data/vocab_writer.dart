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
/// - 名称必须非空；code 留空时直接用名称
/// - code 在各自作用域内唯一
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
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const PatchException('分类名称不能为空');
    }
    final trimmedCode = code.trim().isEmpty ? trimmedName : code.trim();

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
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const PatchException('标签名称不能为空');
    }
    final trimmedCode = code.trim().isEmpty ? trimmedName : code.trim();

    return _db.transaction(() async {
      final category = await _findCategory(categoryCode);

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

  /// 编辑分类。`null` 表示这一列不改。
  Future<void> updateCategory(
    String code, {
    String? newCode,
    String? name,
    bool? single,
    bool? ordered,
    int? sort,
  }) async {
    await _db.transaction(() async {
      final category = await (_db.select(
        _db.categories,
      )..where((t) => t.code.equals(code))).getSingleOrNull();
      if (category == null) {
        throw PatchException('分类 $code 不存在');
      }

      final trimmedCode = newCode?.trim();
      if (trimmedCode != null && trimmedCode.isEmpty) {
        throw const PatchException('分类的 code 不能为空');
      }
      final trimmedName = name?.trim();
      if (trimmedName != null && trimmedName.isEmpty) {
        throw const PatchException('分类名称不能为空');
      }

      if (trimmedCode != null && trimmedCode != category.code) {
        final clash = await (_db.select(
          _db.categories,
        )..where((t) => t.code.equals(trimmedCode))).getSingleOrNull();
        if (clash != null) {
          throw PatchException('分类 $trimmedCode 已存在');
        }
      }

      await (_db.update(
        _db.categories,
      )..where((t) => t.id.equals(category.id))).write(
        CategoriesCompanion(
          code: trimmedCode == null ? const Value.absent() : Value(trimmedCode),
          name: trimmedName == null ? const Value.absent() : Value(trimmedName),
          single: single == null ? const Value.absent() : Value(single),
          ordered: ordered == null ? const Value.absent() : Value(ordered),
          sort: sort == null ? const Value.absent() : Value(sort),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }

  /// 删除分类，连同它下面的标签和这些标签在方块上的标注。
  Future<void> deleteCategory(String code) async {
    await _db.transaction(() async {
      final category = await (_db.select(
        _db.categories,
      )..where((t) => t.code.equals(code))).getSingleOrNull();
      if (category == null) {
        throw PatchException('分类 $code 不存在');
      }

      final tagIds = await (_db.select(
        _db.tags,
      )..where((t) => t.categoryId.equals(category.id))).map((t) => t.id).get();
      if (tagIds.isNotEmpty) {
        await (_db.delete(
          _db.blockTags,
        )..where((t) => t.tagId.isIn(tagIds))).go();
      }
      await (_db.delete(
        _db.tags,
      )..where((t) => t.categoryId.equals(category.id))).go();
      await (_db.delete(
        _db.categories,
      )..where((t) => t.id.equals(category.id))).go();
    });
  }

  /// 编辑标签。`null` 表示这一列不改。
  Future<void> updateTag(
    String categoryCode,
    String code, {
    String? newCode,
    String? name,
    int? sort,
  }) async {
    await _db.transaction(() async {
      final category = await _findCategory(categoryCode);
      final tag =
          await (_db.select(_db.tags)..where(
                (t) => t.categoryId.equals(category.id) & t.code.equals(code),
              ))
              .getSingleOrNull();
      if (tag == null) {
        throw PatchException('分类 ${category.name} 里没有标签 $code');
      }

      final trimmedCode = newCode?.trim();
      if (trimmedCode != null && trimmedCode.isEmpty) {
        throw const PatchException('标签的 code 不能为空');
      }
      final trimmedName = name?.trim();
      if (trimmedName != null && trimmedName.isEmpty) {
        throw const PatchException('标签名称不能为空');
      }

      if (trimmedCode != null && trimmedCode != tag.code) {
        final clash =
            await (_db.select(_db.tags)..where(
                  (t) =>
                      t.categoryId.equals(category.id) &
                      t.code.equals(trimmedCode),
                ))
                .getSingleOrNull();
        if (clash != null) {
          throw PatchException('分类 ${category.name} 里已有标签 $trimmedCode');
        }
      }

      if (sort != null && sort != tag.sort && category.ordered) {
        final clash =
            await (_db.select(_db.tags)..where(
                  (t) =>
                      t.categoryId.equals(category.id) &
                      t.sort.equals(sort) &
                      t.id.equals(tag.id).not(),
                ))
                .getSingleOrNull();
        if (clash != null) {
          throw PatchException(
            '有序分类 ${category.name} 的 sort=$sort 已被占用',
            '换一个数字',
          );
        }
      }

      await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(
        TagsCompanion(
          code: trimmedCode == null ? const Value.absent() : Value(trimmedCode),
          name: trimmedName == null ? const Value.absent() : Value(trimmedName),
          sort: sort == null ? const Value.absent() : Value(sort),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }

  /// 删除标签，连同它在方块上的标注。
  Future<void> deleteTag(String categoryCode, String code) async {
    await _db.transaction(() async {
      final category = await _findCategory(categoryCode);
      final tag =
          await (_db.select(_db.tags)..where(
                (t) => t.categoryId.equals(category.id) & t.code.equals(code),
              ))
              .getSingleOrNull();
      if (tag == null) {
        throw PatchException('分类 ${category.name} 里没有标签 $code');
      }

      await (_db.delete(
        _db.blockTags,
      )..where((t) => t.tagId.equals(tag.id))).go();
      await (_db.delete(_db.tags)..where((t) => t.id.equals(tag.id))).go();
    });
  }

  Future<Category> _findCategory(String code) async {
    final category = await (_db.select(
      _db.categories,
    )..where((t) => t.code.equals(code))).getSingleOrNull();
    if (category == null) {
      throw PatchException('分类 $code 不存在');
    }
    return category;
  }

  /// 按拖拽后的顺序重排分类。`moved` 是被拖动的那个。
  ///
  /// 规则：被拖的落到前一个的 `sort + 1`；后面跟它撞车的依次 + 1，
  /// 比它大的不动。`vanilla` 固定排最后，不参与。
  Future<void> reorderCategories(
    List<String> codes, {
    required String moved,
  }) async {
    await _db.transaction(() async {
      final rows = await (_db.select(
        _db.categories,
      )..where((t) => t.code.isIn(codes))).get();
      final byCode = {for (final row in rows) row.code: row};

      final ordered = <({String code, int id, int sort})>[];
      for (final code in codes) {
        final row = byCode[code];
        if (row == null) throw PatchException('分类 $code 不存在');
        if (row.code == 'vanilla') continue;
        ordered.add((code: code, id: row.id, sort: row.sort));
      }

      final now = DateTime.now().toUtc();
      for (final plan in _planSorts(ordered, moved)) {
        await (_db.update(
          _db.categories,
        )..where((t) => t.id.equals(plan.id))).write(
          CategoriesCompanion(sort: Value(plan.sort), updatedAt: Value(now)),
        );
      }
    });
  }

  /// 按拖拽后的顺序重排一个分类下的标签，规则同 [reorderCategories]。
  Future<void> reorderTags(
    String categoryCode,
    List<String> codes, {
    required String moved,
  }) async {
    await _db.transaction(() async {
      final category = await _findCategory(categoryCode);
      final rows = await (_db.select(_db.tags)..where(
            (t) =>
                t.categoryId.equals(category.id) &
                t.code.isIn(codes),
          ))
          .get();
      final byCode = {for (final row in rows) row.code: row};

      final ordered = <({String code, int id, int sort})>[];
      for (final code in codes) {
        final row = byCode[code];
        if (row == null) {
          throw PatchException('分类 ${category.name} 里没有标签 $code');
        }
        ordered.add((code: code, id: row.id, sort: row.sort));
      }

      final now = DateTime.now().toUtc();
      for (final plan in _planSorts(ordered, moved)) {
        await (_db.update(
          _db.tags,
        )..where((t) => t.id.equals(plan.id))).write(
          TagsCompanion(sort: Value(plan.sort), updatedAt: Value(now)),
        );
      }
    });
  }

  /// 拖拽后的 sort 计划，只包含需要写的行。
  ///
  /// 被拖的取前一个的 `sort + 1`（拖到最前面时取后一个的 `sort - 1`），
  /// 后面和它撞车的依次 + 1，比它大的原地不动。
  List<({int id, int sort})> _planSorts(
    List<({String code, int id, int sort})> ordered,
    String moved,
  ) {
    final index = ordered.indexWhere((row) => row.code == moved);
    if (index < 0) throw PatchException('找不到 $moved');
    if (ordered.length == 1) return const [];

    var taken = index == 0
        ? ordered[1].sort - 1
        : ordered[index - 1].sort + 1;

    final planned = <({int id, int sort})>[];
    if (ordered[index].sort != taken) {
      planned.add((id: ordered[index].id, sort: taken));
    }
    for (var i = index + 1; i < ordered.length; i++) {
      if (ordered[i].sort > taken) break;
      taken += 1;
      planned.add((id: ordered[i].id, sort: taken));
    }
    return planned;
  }

  Future<int> _nextCategorySort() async {
    // `vanilla` 固定排最后，不参与新分类的顺延。
    final row = await _db
        .customSelect(
          "SELECT COALESCE(MAX(sort), -1) + 1 AS next "
          "FROM category WHERE code <> 'vanilla'",
        )
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
