# mcblocks

Minecraft 方块的本地标注工具：导入 `.mcblocks` 数据包，给方块打标签、设色值、管理
贴图，再导出成同样格式的包。

```bash
fvm flutter run -d linux
```

- 数据包由 `mc-blocks`（Python 工具）从客户端 jar 或 mod 源码提取产生
- 桌面优先，同时支持移动端
- 包格式见 `docs/package-format.md`

技术栈、目录结构和开发约定见 `AGENTS.md`，分层和数据流见 `docs/architecture.md`。
