# MySkillKit — 個人 AI スキル集（ソース参照のみ版）

> AI にこのリポジトリの URL を渡すだけで、よく使うスキルを任意のプロジェクトに自動インストールできます。

> [中文](README.md) · [English](README.en.md) · **日本語**

このリポジトリは**ソース参照のみ**の個人スキルキットです：**スキル本体は保存せず**、`manifest.json` に各スキルの上流ソースだけを記録しています。インストール時はその都度、上流から**最新版**を直接取得するため、構造的に「古いバージョンが入ってしまう」ことはありません。

## 収録スキル（19 個）

| スキル | 用途 | 上流ソース |
|---|---|---|
| `design` | トータルデザイン：ロゴ / CIP / アイコン / バナー / ポスター / スライド | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) |
| `ui-styling` | shadcn/ui + Tailwind の UI スタイリングとアクセシビリティ | 同上 |
| `ui-ux-pro-max` | UI/UX デザインインテリジェンス（79 スタイル / 192 パレット / 74 フォントペア） | 同上 |
| `design-system` | 3 層デザイントークン（primitive→semantic→component）+ コンポーネント仕様 | 同上 |
| `banner-design` | マルチプラットフォームのバナー / 広告クリエイティブ制作 | 同上 |
| `brand` | ブランドボイス、ビジュアルアイデンティティ、メッセージフレームワーク | 同上 |
| `slides` | Chart.js を使った戦略的 HTML プレゼンテーション | 同上 |
| `nuxt-ui` | @nuxt/ui v4 で UI を構築 | [nuxt/ui](https://github.com/nuxt/ui)（公式） |
| `nuxt` | Nuxt フレームワークの中核（ルーティング / コンポーネント / SSR / データ取得） | [onmax/nuxt-skills](https://github.com/onmax/nuxt-skills)（公式） |
| `vue` | Vue の中核（Composition API / リアクティビティ / コンポーネント） | 同上 |
| `supabase` | Supabase 全プロダクト開発（DB/Auth/Edge/Storage…） | [supabase/agent-skills](https://github.com/supabase/agent-skills)（公式） |
| `cloudflare` | Cloudflare 全プラットフォーム開発（Workers/Pages/KV/D1/R2/AI/セキュリティ） | [cloudflare/skills](https://github.com/cloudflare/skills)（公式） |
| `durable-objects` | Cloudflare Durable Objects：ステートフル連携 / RPC / SQLite | 同上 |
| `wrangler` | Cloudflare Workers CLI のデプロイ / 開発 | 同上 |
| `workers-best-practices` | Cloudflare Workers の本番ベストプラクティスレビュー | 同上 |
| `web-design-engineer` | ブラウザ描画のビジュアル成果物（ページ / ダッシュボード / プロトタイプ） | [ConardLi/garden-skills](https://github.com/ConardLi/garden-skills) |
| `webapp-testing` | Web アプリのテスト手法と受け入れチェックリスト | [anthropics/skills](https://github.com/anthropics/skills)（公式） |
| `canvas-design` | HTML Canvas によるビジュアルアセット生成 | 同上 |
| `find-skills` | スキルの発見・インストール（skills.sh エコシステム） | [vercel-labs/skills](https://github.com/vercel-labs/skills)（公式） |

## MCP サーバーの自動設定

スキルのインストール時に、**関連する MCP サーバー**も自動設定されます（定義は `manifest.json` の `mcpServers` セクション）：

| MCP サーバー | URL | 関連スキル | 設定先 |
|---|---|---|---|
| `nuxt` | https://nuxt.com/mcp | nuxt、nuxt-ui | プロジェクト → `.agents/mcp.json`；ユーザー全体 → `~/.zcode/cli/config.json` |
| `nuxt-ui` | https://ui.nuxt.com/mcp | nuxt-ui | 同上 |
| `cloudflare` | https://mcp.cloudflare.com/mcp | cloudflare、durable-objects、wrangler、workers-best-practices | 同上 |

- **URL で重複排除**：設定先に同じ URL のサーバー（名前が違っても）があれば自動スキップ
- **ユーザー全体への書き込み時は元設定をバックアップ**（`config.json.bak.<タイムスタンプ>`）し、他の設定は保持
- `./install.sh mcp` で現在の設定状態を確認；`--no-mcp` で MCP 設定をスキップ
- MCP サーバーはセッション起動時に自動接続されるため、**セッションを開き直す必要があります**；OAuth が必要なサーバーは初回接続時にクライアントで認証

## 2 つの使い方

### 方法 A：AI に指示する（推奨）

**AI への指示例（コピペでそのまま使えます）：**

| シーン | AI への言葉 |
|---|---|
| 新プロジェクト初期化（デフォルトは対話式） | 「用 https://github.com/NekoCasterMHB/MySkillKit 里的 skills 初始化这个项目，装哪些技能、配哪些 MCP 都逐个问我」（※中国語のままでも可） |
| 全部入れると明示 | 「https://github.com/NekoCasterMHB/MySkillKit のスキルでこのプロジェクトを初期化して、全部入れて」 |
| いくつか選んで入れる | 「https://github.com/NekoCasterMHB/MySkillKit をクローンして、このプロジェクトに design、nuxt-ui、supabase の 3 つを入れて」 |
| ユーザー全体へ（全プロジェクトで使う） | 「MySkillKit（https://github.com/NekoCasterMHB/MySkillKit）のスキルをユーザー全体 ~/.agents/skills にインストールして」 |
| 更新の有無を確認 | 「MySkillKit で、このプロジェクトにインストール済みのスキルに更新がないか確認して」 |
| スキルを更新 | 「MySkillKit でこのプロジェクトのスキルを更新して（上書き前に旧バージョンをバックアップして）」 |

> デフォルトは**1 つずつ確認するモード**です：AI はスキルごと・MCP ごとに「入れますか？」と個別に確認し、すべて完了したらプロジェクトのスキル一覧と MCP 一覧を報告します。明示的に「全部入れて」と言ったときだけ一括実行します。

AI は指示を受けると：リポジトリをクローン → `AGENTS.md` のインストールプロトコルと `manifest.json` の一覧を読む → **どのスキルを入れ、どの MCP を設定するかを 1 つずつ確認（自動一括インストールはしない）** → 選択に従って上流から最新版を取得 → 検証 → 選択した MCP を設定 → **最後にプロジェクトのスキル一覧と MCP 一覧を報告**します。

> 💡 URL を覚えていなくても「私の MySkillKit リポジトリ」と伝えれば通じますが、URL を渡すのが確実です。インストール / 更新後は**セッションを開き直してください**。

### 方法 B：ワンコマンドスクリプト

```bash
# スキル名なしの場合は 1 つずつ確認（デフォルトは入れない）；名前を指定すれば直接インストール
./install.sh
./install.sh design nuxt-ui        # 指定スキルのみ
./install.sh -y                    # 全デフォルト：全スキル + 関連 MCP を設定

# ユーザー全体へ（全プロジェクトで利用可）
./install.sh --global

# 一覧表示 / MCP 状態確認 / 更新チェック / 強制更新
./install.sh list
./install.sh mcp
./install.sh check
./install.sh update

# リモートからの 1 行コマンド（新しいマシン）
git clone --depth 1 https://github.com/NekoCasterMHB/MySkillKit.git /tmp/MySkillKit \
  && bash /tmp/MySkillKit/install.sh --global
```

> `install.sh` は AI プロトコルと同様：スキルは**1 つずつ確認**（デフォルトは入れない）、MCP サーバーも**1 つずつ確認**（デフォルトは設定、拒否可）。非対話環境（パイプ / CI）ではデフォルトで何もインストールせず、MCP もスキップします。

## 古いバージョンをインストールしない仕組み

- **リポジトリに本体がない**：ここには一覧しかなく、スキルのコピーが存在しないため「リポジトリ内の古い版」が生まれません
- **インストール = 上流から取得**：`git` ソースは毎回上流リポジトリから取得するため、入るのは上流の最新コミット
- **更新検知**：`./install.sh check` が `git ls-remote` でインストール済みコミットと上流の最新コミットを比較し、更新可能な項目を表示
- **バージョン記録**：インストール時に `.agents/.skillkit-installed.json`（スキル → ソース → commit → 日時）を書き込み、更新・チェックはこれに基づく
- **上書き前のバックアップ**：更新時に旧版を `.agents/skills/.backup/<name>-<タイムスタンプ>/` へ自動退避、手動でロールバック可能

## メンテナンス

```bash
# 新しいスキルを追加（git ソース）
node scripts/update-manifest.mjs add <name> --source git --url <repo>.git --path <サブディレクトリ> --ref main

# ローカル専用スキルを追加（local ソース、自分のマシンのみ）
node scripts/update-manifest.mjs add <name> --source local --path ~/.agents/skills/<name>

# 全スキルの最新コミットと説明を更新
node scripts/update-manifest.mjs refresh

# 一覧の検証
node scripts/validate.mjs
```

スキルのソースタイプ：

- **`git`** — 公開上流リポジトリ。どのマシンでもインストール可能で、常に最新（推奨）
- **`local`** — 自マシンの `~/.agents/skills/` を参照。自分のマシンでは常に最新版；他マシンへ配布するにはスキルを GitHub に公開して `git` ソースに変更
- **`embedded`** — 公開ソースが見つからないスキルだけ `vendor/` に本体を置くフォールバック（本体はリポジトリと一緒に更新）

## 注意事項

- スキルの必須ルール：ディレクトリ名 = スキル名；`description` は 1024 文字以内（超えるとスキルが読み込まれません）
- 同名の優先順位：ユーザー全体 `~/.agents/skills/` がプロジェクトの `.agents/skills/` より優先されます。両方にある場合はユーザー全体側が使われます
- 更新後は**セッションを開き直して**反映（スキルはセッション起動時に読み込まれます）
- このリポジトリが git リポジトリ本体です。`manifest.json`、`AGENTS.md`、`install.sh`、`scripts/` 以外は気にする必要はありません
