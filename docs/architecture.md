# 架构

## 目标

单机、单用户、离线可用的 Minecraft 方块标注工具：导入 `.mcblocks` 数据包，按词表
给方块打标签、设色值、管理贴图，再导出成同样格式的包。桌面优先，同时支持移动端。

不做账号、云同步、多人在线。

## 分层

```text
ui/           页面、对话框、widget
  ↓ ref.watch / ref.read
state/        Riverpod providers（筛选状态、查询结果、选中项）
  ↓
data/         BlocksRepository（读）、BlockWriter（写）、Package*（导入导出）
  ↓
core/db/      drift schema、连接、AppDatabase
```

规则：

- UI 不写 SQL，不直接改表；所有写操作走 `BlockWriter`，读走 `BlocksRepository`。
- 一个写方法一个事务，校验失败整体回滚。
- provider 只做「把参数变成查询结果」，不藏业务规则。
- 预发布阶段不做迁移：`schemaVersion` 不一致时清空重建。

## 数据库结构

| 表 | 作用 | 关键点 |
|---|---|---|
| `meta` | 键值对 | `mc_version`、`package_format_version`、`imported_at` |
| `block` | 方块 | `code` 唯一且带命名空间；`icon_id`；`variant_of` 自引用；`reviewed` |
| `texture` | 贴图 | `hash` 唯一；`rel_path` 相对路径 |
| `block_texture` | 方块 → 材质 | `(block_id, key)` 主键；`sort` 决定展示顺序 |
| `category` | 属性维度 | `single` 单选、`ordered` 可区间、`sort` |
| `tag` | 词表值 | `(category_id, code)` 唯一；`sort` |
| `block_tag` | 方块 → 标签 | `source` 为 `user` / `vanilla` / `auto` |

标签来源优先级：`user > vanilla > auto`，低优先级不覆盖高优先级；`vanilla`
标签不允许手工删除。

`mod_id` 不单独建表：「模组」是一个分类（`code=mod`，单选，`sort=-1`），标签值
就是命名空间（`minecraft`、`create`）。

## 数据流

### 导入

`PackageReader`（isolate 里跑）解压 + 解析 + 校验引用关系 → `PackageImporter`
在一个事务里写库：

1. 词表补缺（不覆盖已有名字）
2. 贴图落盘（内容寻址，已存在则跳过）
3. 方块 upsert：`reviewed=1` 整体跳过；其余刷新名字、图标、材质
4. 变体解析，成环直接断开并记录
5. 标签关联：`auto` 只给新方块，`vanilla` / `user` 对已有方块也补
6. 写 meta

### 查询

`BlocksRepository.query(BlockFilter)` 返回一页数据和匹配总数：

- 折叠模式只返回基础方块，标签条件作用于整个变体家族（相关 `EXISTS` 子查询）
- 名称搜索覆盖 `code` / `name` / `name_zh` / `name_en`
- 排序：最近更新（默认）/ code ↑↓ / 名称，都按白名单拼片段
- 计数与取页共用同一份 WHERE，避免分页数字漂移

### 写入

`BlockWriter` 的每个方法都是事务：

```text
apply(BlockPatch)   色值、审核状态、增删标签（单选分类自动替换）
createBlock         新建，code 校验 命名空间:名称、全局唯一
updateBlock         改 code / 名字 / 图标用哪张材质
deleteBlock         连带清掉 block_tag、block_texture，变体指向断开
addTexture          图片转 128px webp，按 sha1 落盘
rename/delete/moveTexture   材质键改名、删除、排序
```

### 导出

`PackageExporter` 把当前库打回 `.mcblocks`：manifest（版本、词表）、
blocks.jsonl（一行一个方块）、被引用的贴图。缺文件只统计，不让导出失败。

## 界面

- 宽屏（≥1000px）：左侧列表 + 右侧详情面板；窄屏：列表点进详情页。
- 详情页默认只读，编辑统一收进右上角「更多」菜单（信息、色值、标签、贴图、审核、
  删除）。
- 点标签 = 按该标签搜索；点贴图 = 放大查看 + 下载。
- 列表默认按更新时间倒序；翻页保留上一页内容，只显示一条细进度条。
