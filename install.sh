#!/usr/bin/env bash
#
# MySkillKit — 从来源清单一键安装 / 检查 / 更新 AI 技能
#
# 用法:
#   ./install.sh [skill ...]            安装指定技能到当前项目（默认全部）
#   ./install.sh --global [skill ...]   安装到用户级 ~/.agents/skills
#   ./install.sh list                   列出清单中的技能
#   ./install.sh check                  检查已安装技能是否有更新
#   ./install.sh update [skill ...]     强制从源头重新拉取（覆盖前自动备份）
#
# 选项:
#   --global, -g   目标为用户级 ~/.agents/skills（默认: 当前项目 .agents/skills）
#   --project      显式指定项目级目标
#   --force, -f    已存在且无安装记录时直接覆盖不询问
#   --yes, -y      所有询问使用默认值
#   -h, --help     帮助
#
# 说明:
#   本仓库不保存技能本体。安装 = 按 manifest.json 从源头拉取最新版，
#   因此从本仓库不可能装到旧版本。安装记录写入
#   <目标>/.agents/.skillkit-installed.json，check/update 基于它对比上游 commit。
#
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$KIT_DIR/manifest.json"
BACKUP_DIR_NAME=".backup"

# ---------- 参数解析 ----------
MODE=install        # install | update | check | list
TARGET_TYPE=project # project | global
FORCE=0
YES=0
SELECTED=()

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    list|check|update) MODE="$1"; shift ;;
    --global|-g) TARGET_TYPE=global; shift ;;
    --project) TARGET_TYPE=project; shift ;;
    --force|-f) FORCE=1; shift ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) usage ;;
    -*) echo "未知参数: $1"; usage ;;
    *) SELECTED+=("$1"); shift ;;
  esac
done

# ---------- 目标解析 ----------
if [[ "$TARGET_TYPE" == global ]]; then
  SKILLS_DIR="$HOME/.agents/skills"
  RECORD_FILE="$HOME/.agents/.skillkit-installed.json"
else
  SKILLS_DIR="$PWD/.agents/skills"
  RECORD_FILE="$PWD/.agents/.skillkit-installed.json"
fi

# ---------- 小工具 ----------
c_green=$'\033[32m'; c_yellow=$'\033[33m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_reset=$'\033[0m'
info()  { printf '%s\n' "ℹ  $*"; }
ok()    { printf '%s\n' "${c_green}✅ $*${c_reset}"; }
warn()  { printf '%s\n' "${c_yellow}⚠  $*${c_reset}"; }
err()   { printf '%s\n' "${c_red}✗ $*${c_reset}" >&2; }

confirm() { # 询问，-y 或 --force 时直接返回默认值
  local prompt="$1" default="${2:-n}"
  [[ "$YES" == 1 ]] && { [[ "$default" == y ]] && return 0 || return 1; }
  local ans
  read -r -p "${prompt} [${default}] " ans || return 1
  ans="${ans:-$default}"
  [[ "$ans" =~ ^[yY]$ ]]
}

  [[ -f "$MANIFEST" ]] || { err "缺少 $MANIFEST (确认在仓库内运行)"; exit 1; }

skill_names() { # → 每行一个技能名（结尾必须带换行，否则 while read 丢最后一行）
  node -e 'const m=require(process.argv[1]);process.stdout.write(m.skills.map(s=>s.name).join("\n")+"\n")' "$MANIFEST"
}

skill_entry() { # name → 该条目的 JSON
  node -e 'const m=require(process.argv[1]);const n=process.argv[2];const s=m.skills.find(x=>x.name===n);process.stdout.write(s?JSON.stringify(s):"")' "$MANIFEST" "$1"
}

ls_remote_commit() { # url ref → commit（分支优先，标签兜底）
  local out
  out="$(git ls-remote "$1" "refs/heads/$2" 2>/dev/null | head -1 || true)"
  if [[ -z "$out" ]]; then
    out="$(git ls-remote "$1" "refs/tags/$2" 2>/dev/null | head -1 || true)"
  fi
  [[ -n "$out" ]] && echo "${out%%$'\t'*}" || true
}

record_commit() { # name → 已记录 commit
  node -e 'const fs=require("fs");const f=process.argv[1],n=process.argv[2];const r=fs.existsSync(f)?JSON.parse(fs.readFileSync(f,"utf8")):{};process.stdout.write(r.skills?.[n]?.commit??"")' "$RECORD_FILE" "$1" 2>/dev/null || true
}

record_set() { # name source_json commit
  node -e '
    const fs=require("fs"),path=require("path");
    const [f,n,src,commit]=process.argv.slice(1);
    const r=fs.existsSync(f)?JSON.parse(fs.readFileSync(f,"utf8")):{skills:{}};
    r.skills??={}; r.skills[n]={source:JSON.parse(src),commit,installedAt:new Date().toISOString()};
    fs.mkdirSync(path.dirname(f),{recursive:true});
    fs.writeFileSync(f,JSON.stringify(r,null,2)+"\n");
  ' "$RECORD_FILE" "$1" "$2" "$3"
}

fetch_git_skill() { # url path ref dest → 输出 commit
  local url="$1" path="$2" ref="$3" dest="$4" tmp
  tmp="$(mktemp -d)"
  if git clone --depth 1 --filter=blob:none --sparse -b "$ref" "$url" "$tmp" >/dev/null 2>&1; then
    git -C "$tmp" sparse-checkout set "$path" >/dev/null 2>&1 || true
  else
    rm -rf "$tmp"; tmp="$(mktemp -d)"
    git clone --depth 1 -b "$ref" "$url" "$tmp" >/dev/null 2>&1 || { rm -rf "$tmp"; err "克隆失败: $url (ref: $ref)"; return 1; }
  fi
  if [[ ! -d "$tmp/$path" ]]; then
    rm -rf "$tmp"; err "来源中不存在 $url#$path (ref: $ref)"; return 1
  fi
  mkdir -p "$dest"
  cp -R "$tmp/$path/." "$dest/"
  local commit
  commit="$(git -C "$tmp" rev-parse HEAD)"
  rm -rf "$tmp"
  echo "$commit"
}

verify_skill() { # dest name → 简单 frontmatter 校验
  local md="$1/SKILL.md"
  if [[ ! -f "$md" ]]; then err "$1 缺少 SKILL.md"; return 1; fi
  local fm
  fm="$(awk 'BEGIN{c=0} /^---$/{c++; if(c==2) exit} c==1{print}' "$md")"
  echo "$fm" | grep -q "^name:[[:space:]]*$2$" || warn "$2: frontmatter name 与目录名不一致"
  local desc_len
  desc_len="$(echo "$fm" | awk '/^description:/{print length(substr($0,index($0,":")+2))}')"
  if [[ -z "$desc_len" ]]; then warn "$2: 缺少 description"
  elif (( desc_len > 1024 )); then warn "$2: description ${desc_len} 字符 > 1024（无法加载）"; fi
}

# ---------- 安装单个技能 ----------
install_one() { # name mode(install|update)
  local name="$1" mode="$2"
  local entry dest commit latest skip_reason=""
  entry="$(skill_entry "$name")"
  [[ -n "$entry" ]] || { err "清单中不存在技能 $name"; return 1; }
  local stype
  stype="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).source.type)' "$entry")"
  dest="$SKILLS_DIR/$name"

  case "$stype" in
    git)
      local url path ref
      url="$(node -e 'const s=JSON.parse(process.argv[1]).source;process.stdout.write(s.url)' "$entry")"
      path="$(node -e 'const s=JSON.parse(process.argv[1]).source;process.stdout.write(s.path)' "$entry")"
      ref="$(node -e 'const s=JSON.parse(process.argv[1]).source;process.stdout.write(s.ref)' "$entry")"
      latest="$(ls_remote_commit "$url" "$ref" || true)"
      if [[ -z "$latest" ]]; then warn "$name: 无法获取上游最新 commit，跳过"; return 0; fi

      local installed=""
      installed="$(record_commit "$name")"

      if [[ -d "$dest" ]]; then
        if [[ "$mode" == update || ( -n "$installed" && "$installed" != "$latest" ) ]]; then
          # 需要覆盖：备份旧版
          mkdir -p "$SKILLS_DIR/$BACKUP_DIR_NAME"
          local bak="$SKILLS_DIR/$BACKUP_DIR_NAME/${name}-$(date +%Y%m%d%H%M%S)"
          cp -R "$dest" "$bak"
          info "旧版已备份到 $bak"
        elif [[ -n "$installed" && "$installed" == "$latest" ]]; then
          skip_reason="已是最新 ($(echo "$latest" | cut -c1-7))"
        elif ! confirm "$name: 目标已存在但无 kit 安装记录，覆盖？" y && [[ "$FORCE" == 0 ]]; then
          skip_reason="已存在，跳过（用 --force 覆盖）"
        else
          : # 无记录但确认/强制覆盖
        fi
      fi

      if [[ -n "$skip_reason" ]]; then
        info "$name: $skip_reason"
        return 0
      fi

      if ! commit="$(fetch_git_skill "$url" "$path" "$ref" "$dest")"; then return 1; fi
      verify_skill "$dest" "$name"
      record_set "$name" "$(node -e 'process.stdout.write(JSON.stringify(JSON.parse(process.argv[1]).source))' "$entry")" "$commit"
      ok "$name → $dest ($(echo "$commit" | cut -c1-7))"
      ;;
    local)
      local src
      src="$(node -e 'const s=JSON.parse(process.argv[1]).source;process.stdout.write(s.path)' "$entry")"
      src="${src/#\~/$HOME}"
      if [[ ! -d "$src" ]]; then
        warn "$name: local 来源 $src 不存在（此技能仅限所有者机器）"
        return 0
      fi
      if [[ -d "$dest" && "$FORCE" == 0 ]] && ! confirm "$name: 目标已存在，覆盖？" y; then
        info "$name: 跳过"; return 0
      fi
      mkdir -p "$dest"
      cp -R "$src/." "$dest/"
      verify_skill "$dest" "$name"
      record_set "$name" "$(node -e 'process.stdout.write(JSON.stringify(JSON.parse(process.argv[1]).source))' "$entry")" "local"
      ok "$name → $dest (本机来源 $src)"
      ;;
    embedded)
      local vdir="$KIT_DIR/$(node -e 'const s=JSON.parse(process.argv[1]).source;process.stdout.write(s.path)' "$entry")"
      if [[ ! -d "$vdir" ]]; then warn "$name: vendor 目录缺失"; return 0; fi
      if [[ -d "$dest" && "$FORCE" == 0 ]] && ! confirm "$name: 目标已存在，覆盖？" y; then
        info "$name: 跳过"; return 0
      fi
      mkdir -p "$dest"
      cp -R "$vdir/." "$dest/"
      verify_skill "$dest" "$name"
      record_set "$name" "$(node -e 'process.stdout.write(JSON.stringify(JSON.parse(process.argv[1]).source))' "$entry")" "embedded"
      ok "$name → $dest (kit 内置)"
      ;;
  esac
}

# ---------- 子命令：list ----------
cmd_list() {
  printf '%-24s %-10s %s\n' "技能" "来源" "描述"
  printf '%s\n' "----------------------------------------------------------------"
  while IFS= read -r name; do
    local entry
    entry="$(skill_entry "$name")"
    local stype desc
    stype="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).source.type)' "$entry")"
    desc="$(node -e 'const d=JSON.parse(process.argv[1]).description||"";process.stdout.write(d.slice(0,60)+(d.length>60?"…":""))' "$entry")"
    printf '%-24s %-10s %s\n' "$name" "$stype" "$desc"
  done < <(skill_names)
}

# ---------- 子命令：check ----------
cmd_check() {
  if [[ ! -f "$RECORD_FILE" ]]; then
    info "没有 kit 安装记录 ($RECORD_FILE) -- 先运行 ./install.sh 安装"
    return 0
  fi
  printf '%-24s %s\n' "技能" "状态"
  printf '%s\n' "----------------------------------------------------------------"
  while IFS= read -r name; do
    local entry stype
    entry="$(skill_entry "$name")"
    stype="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).source.type)' "$entry")"
    local installed=""
    installed="$(record_commit "$name")"
    if [[ -z "$installed" ]]; then
      printf '%-24s %s\n' "$name" "${c_dim}未安装（本机 ${SKILLS_DIR/$HOME/~} 无记录）${c_reset}"
      continue
    fi
    case "$stype" in
      git)
        local url ref latest
        url="$(node -e 'const s=JSON.parse(process.argv[1]).source;process.stdout.write(s.url)' "$entry")"
        ref="$(node -e 'const s=JSON.parse(process.argv[1]).source;process.stdout.write(s.ref)' "$entry")"
        latest="$(ls_remote_commit "$url" "$ref" || true)"
        if [[ -z "$latest" ]]; then
          printf '%-24s %s\n' "$name" "${c_yellow}无法检查上游${c_reset}"
        elif [[ "$latest" == "$installed" ]]; then
          printf '%-24s %s\n' "$name" "${c_green}✅ 最新 ($(echo "$installed" | cut -c1-7))${c_reset}"
        else
          printf '%-24s %s\n' "$name" "${c_yellow}⬆ 可更新: $(echo "$installed" | cut -c1-7) → $(echo "$latest" | cut -c1-7) (./install.sh update $name)${c_reset}"
        fi
        ;;
      local)
        printf '%-24s %s\n' "$name" "${c_dim}🔒 本地来源，无需检查${c_reset}"
        ;;
      embedded)
        printf '%-24s %s\n' "$name" "${c_dim}📦 kit 内置，随仓库更新${c_reset}"
        ;;
    esac
  done < <(skill_names)
}

# ---------- 主流程 ----------
case "$MODE" in
  list)
    cmd_list
    exit 0
    ;;
  check)
    cmd_check
    exit 0
    ;;
esac

# 解析要安装的技能（bash 3.2 兼容，不用 mapfile）
ALL_SKILLS=()
while IFS= read -r _s; do ALL_SKILLS+=("$_s"); done < <(skill_names)
if [[ ${#SELECTED[@]} -eq 0 ]]; then
  TARGETS=("${ALL_SKILLS[@]}")
else
  TARGETS=()
  for s in "${SELECTED[@]}"; do
    if [[ " ${ALL_SKILLS[*]} " =~ " $s " ]]; then TARGETS+=("$s")
    else err "清单中不存在技能 $s (./install.sh list 查看)"; fi
  done
  [[ ${#TARGETS[@]} -eq 0 ]] && exit 1
fi

[[ "$TARGET_TYPE" == project ]] && mkdir -p "$PWD/.agents"
mkdir -p "$SKILLS_DIR"

echo "目标: $SKILLS_DIR"
if [[ "$TARGET_TYPE" == project ]]; then
  for t in "${TARGETS[@]}"; do
    if [[ -d "$HOME/.agents/skills/$t" ]]; then
      warn "$t: 用户级 ~/.agents/skills/$t 已存在，项目级副本将被用户级遮蔽"
    fi
  done
fi
echo ""

fail_count=0
for t in "${TARGETS[@]}"; do
  install_one "$t" "$MODE" || fail_count=$((fail_count + 1))
done

echo ""
if (( fail_count > 0 )); then
  err "$fail_count 个技能安装失败"
  exit 1
fi
ok "完成。技能在会话启动时加载，新开会话生效。"
