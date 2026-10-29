# AGENTS.md

## 项目

`mcblocks` 是 Minecraft 方块的本地标注工具：导入 Python 工具生成的 `.mcblocks`
数据包，人工打标签、设色值、管理贴图，再导出数据包。

- Flutter 3.47 / Dart 3.13（由 FVM 固定，命令统一走 `fvm flutter ...`）
- 状态：Riverpod 3（codegen）
- 数据库：drift 2（SQLite，桌面 + 移动端同一套 schema）
- 路由：go_router
- 包：`archive`（解压/打包数据包）、`file_picker`、`image`、`flutter_colorpicker`

## 常用命令

```bash
fvm flutter test                 # 全部测试
fvm flutter analyze              # 静态检查
fvm dart run build_runner build  # 改了 @riverpod / drift 表之后
fvm flutter run -d linux         # 桌面端跑起来
```

## 目录

```text
lib/
  main.dart                 入口：ProviderScope + McBlocksApp
  app/                      路由、主题、导航外壳
  core/db/                  drift schema、连接、provider
  features/blocks/          方块列表、筛选、详情、写入、导出所需的读接口
    domain/                 BlockFilter / BlockListItem / BlockDetail / BlockTag / Patch
    data/                   BlocksRepository（读）、BlockWriter（唯一写入口）
    ui/                     列表页、详情页、各种编辑对话框
  features/import/          数据包的解析、导入、导出
    data/                   PackageReader / PackageImporter / PackageExporter
    domain/                 manifest、block、异常、导入报告
    ui/                     导入页（含导出）
  features/vocab/           词表管理（分类与标签）
test/                       与 lib/ 同构；数据层用内存 SQLite，UI 用 widget test
```

## 硬约束

1. **写操作只有一个入口**：`features/blocks/data/block_writer.dart`。一个方法一个
   事务，失败整体回滚；校验放在这里，UI 只负责收集输入。
2. **读操作走 repository**：`blocks_repository.dart` 里的 SQL 是唯一查询来源，
   UI 不许直接写 SQL。
3. **`core/db` 不含业务规则**：schema 和连接之外不放逻辑。
4. **不做 schema 迁移**：`schemaVersion` 变了就清空重建（见 `app_database.dart`），
   数据靠重新导入。改 schema 必须同时递增版本号。
5. **`code` 全局唯一且带命名空间**（`minecraft:stone`、`create:zinc_block`），
   mod 只作为「模组」分类下的标签存在，没有单独的 mod 表。
6. **贴图按内容寻址**：`textures/sha/<hash 前两位>/<hash>.webp`，数据库只存相对
   路径，同一张图只落一份盘。
7. **图标不编造**：只取方块模型自己的材质键，没有就留空。颜色取图标贴图的中位色。
8. **群系染色在导入时烘好**（`tint:平原` 等），运行时不再上色。
9. UI 层不做数据推导：能算在 repository / writer 里的不要放到 widget 里。

## 数据契约

`.mcblocks` 包的格式见 `docs/package-format.md`。Python 工具负责生产，本 app 既
导入也导出，两边改动必须同步格式版本号。

## 测试

- 数据层（repository / writer / importer / exporter）用 `NativeDatabase.memory()`
  和临时贴图目录，不碰真实数据。
- UI 用 `ProviderScope` + `appDatabaseProvider.overrideWithValue(...)` 注入内存库。
- 改核心逻辑后至少跑 `flutter test`；改 schema 或 provider 后先跑 build_runner。
