# MySkillKit — AI 技能安装协议

本仓库是**纯来源清单**式个人 AI 技能集：不保存技能本体，只记录每个技能的上游来源（`manifest.json`）。
安装 = 按清单从源头拉取**最新版**，因此从本仓库不可能装到旧版本。

## 技能清单

见 `manifest.json`。每个条目：

- `name` — 技能名（kebab-case，也是安装后的目录名）
- `description` — 技能用途（帮助 AI 与用户选择）
- `source.type` — `git`（上游公开仓库）/ `local`（本机用户级目录，仅限所有者机器）/ `embedded`（本仓库 `vendor/` 兜底）
- `source.url` / `source.path` / `source.ref` — git 来源的仓库地址、技能子目录、分支或标签
- `version.commit` — 最近一次同步时上游的 commit（版本标识）

## 任务：把技能安装到目标项目

当用户说「用 MySkillKit 安装/初始化 skills」或给出本仓库地址时：

1. **获取本仓库**：若你手头没有本地副本，先 `git clone --depth 1 <仓库地址> /tmp/MySkillKit`
2. **确认目标**：项目级 → 当前工作目录的 `.agents/skills/`；用户级 → `~/.agents/skills/`。不确定就问用户
3. **确认选择**：读 `manifest.json` 列出技能，与用户确认装哪些（默认全部）
4. **逐个安装**：
   - `type: git` → `git clone --depth 1 --filter=blob:none --sparse -b <ref> <url> /tmp/src && git -C /tmp/src sparse-checkout set <path>`，然后 `cp -R /tmp/src/<path> 目标/.agents/skills/<name>/`
   - `type: local` → 从 `<path>`（本机 `~/.agents/skills/<name>`）直接复制；其他机器上跳过并提示「该技能仅在所有者机器可用」
   - `type: embedded` → `cp -R vendor/<name> 目标/.agents/skills/<name>/`
5. **记录版本**：在 `<目标根>/.agents/.skillkit-installed.json` 写入 `{ "skills": { "<name>": { "source": …, "commit": …, "installedAt": … } } }`（commit 用 `git -C /tmp/src rev-parse HEAD`）
6. **校验**：确认每个安装目录含 `SKILL.md`，frontmatter 有 `name`（= 目录名）与 `description`（≤1024 字符）
7. **报告**：装了什么、来源仓库、对应 commit；提示「技能在会话启动时加载，需新开会话生效」

## 任务：检查 / 更新已安装技能

当用户说「检查 / 更新项目里的 skills」时：

1. 读 `<目标根>/.agents/.skillkit-installed.json`；没有则告知「无 kit 安装记录」
2. 对每个 `type: git` 技能：`git ls-remote <url> refs/heads/<ref>`（标签用 `refs/tags/<ref>`）取最新 commit，与记录对比
3. 报告过期项；用户确认后按安装流程重新拉取覆盖，**覆盖前先把旧目录备份到 `<目标>/.agents/skills/.backup/<name>-<时间戳>/`**
4. `type: local`：提示「本地来源，直接看 `~/.agents/skills/<name>` 即可」；`type: embedded`：随本仓库更新

## 任务：维护清单（新增 / 刷新技能）

- 新增技能：`node scripts/update-manifest.mjs add <name> --source git --url <url> --path <path> --ref <ref>`（或 `--source local --path …` / `--source embedded`）
- 刷新各技能最新 commit 与描述：`node scripts/update-manifest.mjs refresh`
- 校验清单与 vendor 技能：`node scripts/validate.mjs`

## 重要规则

- 技能目录名必须等于技能名；`description` ≤1024 字符，否则技能无法被加载
- 用户级 `~/.agents/skills/` 优先于项目级 `.agents/skills/`：同名技能用户级会遮蔽项目级，安装 / 更新时提醒用户
- 本仓库的变更（manifest / 协议 / 脚本）直接 commit + push 即可，AI 侧无需任何额外配置
