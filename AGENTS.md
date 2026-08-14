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
3. **逐个询问技能（禁止全自动安装）**：读 `manifest.json` 列出所有技能，**一个一个**向用户展示（名称 + 用途），单独询问「要装吗？」。不要默认全装，不要跳过询问；用户明确说「全部装」时才批量执行
4. **按用户选择逐个安装**：
   - `type: git` → `git clone --depth 1 --filter=blob:none --sparse -b <ref> <url> /tmp/src && git -C /tmp/src sparse-checkout set <path>`，然后 `cp -R /tmp/src/<path> 目标/.agents/skills/<name>/`
   - `type: local` → 从 `<path>`（本机 `~/.agents/skills/<name>`）直接复制；其他机器上跳过并提示「该技能仅在所有者机器可用」
   - `type: embedded` → `cp -R vendor/<name> 目标/.agents/skills/<name>/`
   - 也可以让用户选择后运行 `install.sh <技能名>...`（不要直接运行不带参数的 `install.sh`，那会全量安装）
5. **记录版本**：在 `<目标根>/.agents/.skillkit-installed.json` 写入 `{ "skills": { "<name>": { "source": …, "commit": …, "installedAt": … } } }`（commit 用 `git -C /tmp/src rev-parse HEAD`）
6. **校验**：确认每个安装目录含 `SKILL.md`，frontmatter 有 `name`（= 目录名）与 `description`（≤1024 字符）
7. **报告项目当前状态**：装完（或用户拒绝后）输出两份清单：
   - **skills 列表**：`<项目>/.agents/skills/` 下实际存在的技能目录（含已有的）
   - **MCP 列表**：`<项目>/.agents/mcp.json` 中的服务器（名称 + URL）；若装到了用户级，同时列出 `~/.zcode/cli/config.json` 中 `mcp.servers` 的名称
   - 最后提示「技能/MCP 在会话启动时加载，需新开会话生效」

## 任务：检查 / 更新已安装技能

当用户说「检查 / 更新项目里的 skills」时：

1. 读 `<目标根>/.agents/.skillkit-installed.json`；没有则告知「无 kit 安装记录」
2. 对每个 `type: git` 技能：`git ls-remote <url> refs/heads/<ref>`（标签用 `refs/tags/<ref>`）取最新 commit，与记录对比
3. 报告过期项；用户确认后按安装流程重新拉取覆盖，**覆盖前先把旧目录备份到 `<目标>/.agents/skills/.backup/<name>-<时间戳>/`**
4. `type: local`：提示「本地来源，直接看 `~/.agents/skills/<name>` 即可」；`type: embedded`：随本仓库更新

## 任务：配置 MCP 服务器（与技能安装一起）

安装 / 更新技能后，检查 `manifest.json` 的 `mcpServers` 段。对其中 `skills` 列表与本次安装技能相关的每个服务器，**单独询问用户**「要配置这个 MCP 服务器吗？」（展示名称 + URL + 关联技能），**只有用户同意才写入**，不要自动全配。

写入目标：

- 项目级安装 → 写入 / 合并 `<目标项目>/.agents/mcp.json`（顶层 `mcpServers` 键，ZCode 工作区兼容标准，自动连接）
- 用户级安装 → 合并到 `~/.zcode/cli/config.json` 的 `mcp.servers`（**先备份原文件**，保留原有其他配置）

合并规则：

- 服务器条目格式必须严格（未知字段会导致服务器被丢弃）：
  - http/sse：`{ "type": "http", "url": "…" }`
  - stdio：`{ "type": "stdio", "command": "…", "args": […], "env": {…} }`
- 按 URL 去重：目标中已存在同 URL 的服务器（无论名字）则跳过
- 不要写入任何密钥；需要认证的服务器（如 OAuth）在报告中提示用户首次连接时完成授权
- MCP 服务器在会话启动时自动连接，需新开会话生效

## 任务：维护清单（新增 / 刷新技能）

- 新增技能：`node scripts/update-manifest.mjs add <name> --source git --url <url> --path <path> --ref <ref>`（或 `--source local --path …` / `--source embedded`）
- 刷新各技能最新 commit 与描述：`node scripts/update-manifest.mjs refresh`
- 校验清单与 vendor 技能：`node scripts/validate.mjs`

## 重要规则

- **交互确认是默认行为**：安装每个技能、配置每个 MCP 服务器前，都逐个询问用户确认，不自动全装、不全配（除非用户明确说「全部装」）
- 技能目录名必须等于技能名；`description` ≤1024 字符，否则技能无法被加载
- MCP 服务器名与 URL 由 `manifest.json` 的 `mcpServers` 维护；配置文件格式严格（见上），合并时按 URL 去重、保留原有配置
- 用户级 `~/.agents/skills/` 优先于项目级 `.agents/skills/`：同名技能用户级会遮蔽项目级，安装 / 更新时提醒用户
- 本仓库的变更（manifest / 协议 / 脚本）直接 commit + push 即可，AI 侧无需任何额外配置
