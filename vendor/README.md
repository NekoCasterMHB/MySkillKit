# vendor/ — 兜底技能本体

本目录**通常应为空**。仅当某个技能找不到公开上游（无法用 `git` 来源）时，才把它的本体放进来，并在 `manifest.json` 里标记为 `"type": "embedded"`。

- 每个技能一个子目录：`vendor/<name>/SKILL.md`（可带 `references/`、`scripts/` 等）
- 规则：目录名 = 技能名；frontmatter 必须含 `name` 与 `description`（≤1024 字符）
- 安装时随仓库复制，更新 = 更新本仓库
