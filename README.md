# MySkillKit — 个人 AI 技能合集（纯来源清单版）

> 给 AI 一个仓库地址，它就能把你的常用 skills 自动装进任何项目。

本仓库是**纯来源清单**式的个人技能集：**不保存技能本体**，只维护一份 `manifest.json` 技能清单，记录每个技能的上游公开来源。安装时直接按清单从源头拉取**最新版** —— 从结构上杜绝"装到旧版本"的问题。

## 包含的技能（15 个）

| 技能 | 用途 | 上游来源 |
|---|---|---|
| `design` | 全链路设计：logo / CIP / 图标 / 横幅 / 海报 / 幻灯片 | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) |
| `ui-styling` | shadcn/ui + Tailwind 界面样式与无障碍 | 同上 |
| `ui-ux-pro-max` | UI/UX 设计智能（79 风格 / 192 配色 / 74 字体搭配） | 同上 |
| `design-system` | 三层设计令牌（primitive→semantic→component）+ 组件规范 | 同上 |
| `banner-design` | 多平台横幅 / 广告图设计 | 同上 |
| `brand` | 品牌声音、视觉识别、信息框架 | 同上 |
| `slides` | Chart.js 战略演示文稿 | 同上 |
| `nuxt-ui` | 用 @nuxt/ui v4 构建界面 | [nuxt/ui](https://github.com/nuxt/ui)（官方） |
| `supabase` | Supabase 全产品开发（DB/Auth/Edge/Storage…） | [supabase/agent-skills](https://github.com/supabase/agent-skills)（官方） |
| `cloudflare` | Cloudflare 全平台开发（Workers/Pages/KV/D1/R2/AI/安全） | [cloudflare/skills](https://github.com/cloudflare/skills)（官方） |
| `durable-objects` | Cloudflare Durable Objects：有状态协同/RPC/SQLite | 同上 |
| `wrangler` | Cloudflare Workers CLI 部署与开发 | 同上 |
| `workers-best-practices` | Cloudflare Workers 生产最佳实践审查 | 同上 |
| `web-design-engineer` | 浏览器渲染视觉产物（页面/仪表盘/原型） | [ConardLi/garden-skills](https://github.com/ConardLi/garden-skills) |
| `find-skills` | 发现与安装更多技能（skills.sh 生态） | [vercel-labs/skills](https://github.com/vercel-labs/skills)（官方） |

## 自动配置 MCP 服务器

安装技能时，会一并自动配置**关联的 MCP 服务器**（定义在 `manifest.json` 的 `mcpServers` 段）：

| MCP 服务器 | URL | 关联技能 | 配置位置 |
|---|---|---|---|
| `nuxt-ui` | https://ui.nuxt.com/mcp | nuxt-ui | 项目级 → `.agents/mcp.json`；用户级 → `~/.zcode/cli/config.json` |
| `cloudflare` | https://mcp.cloudflare.com/mcp | cloudflare、durable-objects、wrangler、workers-best-practices | 同上 |

- **按 URL 去重**：目标中已有同 URL 的服务器（无论名字）会自动跳过，不会重复配置
- **用户级合并时先备份**原配置文件（`config.json.bak.<时间戳>`），并保留原有其他配置
- `./install.sh mcp` 查看当前配置状态；`--no-mcp` 跳过 MCP 配置
- MCP 服务器在会话启动时自动连接，**需新开会话生效**；需要 OAuth 的服务器首次连接时在客户端完成授权

## 两种使用方式

### 方式 A：告诉 AI（推荐）

**给 AI 的指令示例（复制即用）：**

| 场景 | 对 AI 说的话 |
|---|---|
| 新项目装全部（项目级） | 「用 https://github.com/NekoCasterMHB/MySkillKit 里的 skills 初始化这个项目，全部安装」 |
| 新项目选装几个 | 「克隆 https://github.com/NekoCasterMHB/MySkillKit，给这个项目装 design、nuxt-ui、supabase 这三个 skill」 |
| 装到全局（所有项目可用） | 「用 MySkillKit（https://github.com/NekoCasterMHB/MySkillKit）把 skills 装到用户级 ~/.agents/skills」 |
| 检查项目里的 skills 是否有更新 | 「用 MySkillKit 检查这个项目已安装的 skills 有没有更新」 |
| 更新项目里的 skills | 「用 MySkillKit 更新这个项目里的 skills（覆盖前备份旧版）」 |

AI 收到指令后会：克隆仓库 → 读 `AGENTS.md` 安装协议和 `manifest.json` 清单 → 与你确认要装哪些（或按你的指定）→ 从源头拉取最新版 → 校验 → **一并配置关联的 MCP 服务器** → 报告结果。

> 💡 记不住 URL 时，只说「用我的 MySkillKit 仓库」也能理解（ZCode 知道你的常用仓库），但给出 URL 最稳妥。装完/更新后**新开会话**生效。

### 方式 B：一键脚本

```bash
# 装到当前项目（项目级，随项目版本控制）
./install.sh

# 装到用户级（所有项目可用）
./install.sh --global

# 只装指定技能 / 列出技能 / 检查更新 / 强制更新
./install.sh design nuxt-ui
./install.sh list
./install.sh check
./install.sh update

# 远程一行命令（新机器）
git clone --depth 1 https://github.com/NekoCasterMHB/MySkillKit.git /tmp/MySkillKit \
  && bash /tmp/MySkillKit/install.sh --global
```

## 如何保证装到的不是旧版本

- **仓库无本体**：本仓库只有清单，没有任何技能副本，不存在"仓库里的旧版"
- **安装 = 拉取源头**：`git` 来源每次安装都从上游仓库拉取，装到的是上游最新提交
- **更新检测**：`./install.sh check` 用 `git ls-remote` 对比已装 commit 与上游最新 commit，列出可更新项
- **版本记录**：安装时写入 `.agents/.skillkit-installed.json`（技能 → 来源 → commit → 时间），更新与检查都基于它
- **覆盖前备份**：更新时旧版自动备份到 `.agents/skills/.backup/<name>-<时间戳>/`，可手动回滚

## 维护指南

```bash
# 加一个新技能（git 来源）
node scripts/update-manifest.mjs add <name> --source git --url <repo>.git --path <子目录> --ref main

# 加本机私有技能（local 来源，仅自己机器可用）
node scripts/update-manifest.mjs add <name> --source local --path ~/.agents/skills/<name>

# 刷新所有技能的最新 commit 与描述
node scripts/update-manifest.mjs refresh

# 校验清单
node scripts/validate.mjs
```

技能来源类型：

- **`git`** — 上游公开仓库，全机器可安装，永远最新（推荐）
- **`local`** — 指向本机 `~/.agents/skills/`，自己的机器安装永远是最新版；跨机器分发需先把技能发布到 GitHub 再改为 `git` 来源
- **`embedded`** — 找不到公开上游的技能才放进 `vendor/` 兜底（本体随仓库走）

## 注意事项

- 技能规范红线：目录名 = 技能名；`description` ≤1024 字符，否则技能无法被加载
- 同名遮蔽：用户级 `~/.agents/skills/` 优先于项目级 `.agents/skills/` 加载；若两边都有同名技能，以用户级为准
- 更新后需**新开会话**生效（技能在会话启动时加载）
- 本仓库是 git 仓库；`manifest.json`、`AGENTS.md`、`install.sh`、`scripts/` 之外的目录无需关心
