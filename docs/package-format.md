# `.mcblocks` 数据包格式

Python 工具和本 app 都按这个格式读写。**改格式必须同时升级 `format_version`，
两边一起改。**

包是 zip，三个部分：

```text
manifest.json
blocks.jsonl
textures/sha/<hash 前两位>/<hash>.webp
```

## manifest.json

```json
{
  "format_version": 2,
  "mc_version": "1.21.1",
  "generated_at": "2026-10-29T09:00:00+00:00",
  "block_count": 1062,
  "texture_count": 972,
  "categories": [
    {"code": "mod", "name": "模组", "single": true, "ordered": false, "sort": -1}
  ],
  "tags": [
    {"category": "mod", "code": "minecraft", "name": "minecraft", "sort": 0}
  ]
}
```

- `format_version` 与代码里的 `supportedFormatVersion` 不一致直接拒绝导入
- `categories[].code` 是标签引用里的前半段
- `tags[].category` 写分类 code，不是分类名

## blocks.jsonl

一行一个方块，UTF-8，紧凑 JSON：

```json
{
  "code": "minecraft:stone",
  "name": null,
  "name_zh": "石头",
  "name_en": "Stone",
  "color_hex": "#7f7f7f",
  "variant_of": null,
  "reviewed": 0,
  "textures": [
    {"key": "all", "hash": "<sha1>", "sort": 0},
    {"key": "tint:平原", "hash": "<sha1>", "sort": 1}
  ],
  "icon": "<sha1>",
  "tags": [
    {"tag": "mod:minecraft", "source": "vanilla"},
    {"tag": "shape:完整方块", "source": "auto"}
  ]
}
```

字段约定：

| 字段 | 说明 |
|---|---|
| `code` | 必填，`命名空间:名称`，全局唯一 |
| `name` / `name_zh` / `name_en` | 可缺；显示顺序 `name > name_zh > name_en > code` |
| `color_hex` | `#rrggbb`，取图标贴图的中位色 |
| `variant_of` | 基础方块的完整 code |
| `reviewed` | `0` / `1`，`1` 的方块导入时不覆盖名字和贴图 |
| `textures` | 材质键 → 贴图 hash，`sort` 决定展示顺序 |
| `icon` | 展示图标；没有可用材质时省略（床、旗帜、头颅、空气） |
| `tags` | `分类code:标签code` + 来源 `auto` / `vanilla` / `user` |

## 贴图

- 内容是 128×128 的 webp，按原始图片字节的 sha1 命名
- 数据库只存相对路径，app 侧解到应用支持目录
- 导入时只解压被引用的贴图；缺文件记一条问题，不中断

## 导入语义

- 默认增量：`reviewed=1` 跳过，其余刷新名字/图标/材质，已有标签不删
- 全量重建：先清空方块、材质、标签、词表、贴图记录，再整体写入
- 词表缺什么补什么，不改已有分类和标签的名字
