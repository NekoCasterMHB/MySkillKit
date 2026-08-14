#!/usr/bin/env node
/**
 * MySkillKit 清单校验脚本
 *
 * 用法:
 *   node scripts/validate.mjs            # 本地校验（不联网）
 *   node scripts/validate.mjs --network  # 额外验证 git 来源可达性（git ls-remote）
 *
 * 校验项:
 *   - manifest.json 结构与必填字段
 *   - 技能名 kebab-case 且不重复
 *   - git 来源: url/path/ref 齐全
 *   - local 来源: path 存在且含 SKILL.md（仅本机可查）
 *   - embedded 来源: vendor/<name>/SKILL.md 存在，frontmatter 合规
 *   - --network: 每个 git 来源 ls-remote 可达
 */
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const KIT_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const MANIFEST_PATH = join(KIT_ROOT, 'manifest.json');

const NAME_RE = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const MAX_DESC = 1024;
let errors = 0;

function err(msg) {
  errors++;
  console.error(`  ❌ ${msg}`);
}

function ok(msg) {
  console.log(`  ✅ ${msg}`);
}

/** 解析 SKILL.md frontmatter，返回 { name, description }（宽松解析） */
function parseFrontmatter(skillMd) {
  const content = readFileSync(skillMd, 'utf8');
  const m = content.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return { name: null, description: null };
  const fm = m[1];
  const name = fm.match(/^name:\s*(.+)$/m)?.[1]?.trim();
  const desc = fm.match(/^description:\s*(?:"([^"]*)"|'([^']*)'|(.+))$/m);
  return { name, description: (desc?.[1] ?? desc?.[2] ?? desc?.[3] ?? '').trim() };
}

// ---------- 主流程 ----------

console.log(`校验 ${MANIFEST_PATH}`);
if (!existsSync(MANIFEST_PATH)) {
  console.error('❌ manifest.json 不存在');
  process.exit(1);
}

const manifest = JSON.parse(readFileSync(MANIFEST_PATH, 'utf8'));

// 顶层字段
if (!manifest.name) err('缺少顶层 name');
else ok(`顶层 name: ${manifest.name}`);
if (!Array.isArray(manifest.skills) || manifest.skills.length === 0) err('skills 必须是非空数组');
else ok(`${manifest.skills.length} 个技能`);

// 技能条目
const seen = new Set();
for (const skill of manifest.skills) {
  const label = skill.name ?? '<未命名>';
  if (!skill.name || !NAME_RE.test(skill.name)) err(`${label}: name 必须是 kebab-case`);
  if (seen.has(skill.name)) err(`${skill.name}: 重名`);
  seen.add(skill.name);

  const { type } = skill.source ?? {};
  if (!['git', 'local', 'embedded'].includes(type)) {
    err(`${skill.name}: source.type 必须是 git / local / embedded`);
    continue;
  }

  if (type === 'git') {
    const { url, path, ref } = skill.source;
    if (!url) err(`${skill.name}: 缺少 source.url`);
    if (!path) err(`${skill.name}: 缺少 source.path`);
    if (!ref) err(`${skill.name}: 缺少 source.ref`);
    else ok(`${skill.name}: git ${url} → ${path} (${ref})`);
  } else if (type === 'local') {
    const p = skill.source.path;
    if (!p) {
      err(`${skill.name}: 缺少 source.path`);
      continue;
    }
    const md = join(p.replace(/^~/, process.env.HOME ?? '~'), 'SKILL.md');
    if (existsSync(md)) ok(`${skill.name}: local ${p}`);
    else err(`${skill.name}: local 路径不可见（${md} 不存在，其他机器属正常）`);
  } else {
    const dir = join(KIT_ROOT, skill.source.path ?? `vendor/${skill.name}`);
    const md = join(dir, 'SKILL.md');
    if (!existsSync(md)) {
      err(`${skill.name}: ${dir}/SKILL.md 不存在`);
      continue;
    }
    const { name: fmName, description } = parseFrontmatter(md);
    if (fmName !== skill.name) err(`${skill.name}: frontmatter name (${fmName}) 与条目名不一致`);
    else ok(`${skill.name}: frontmatter name 匹配`);
    if (!description) err(`${skill.name}: frontmatter 缺少 description`);
    else if (description.length > MAX_DESC) err(`${skill.name}: description ${description.length} 字符 > ${MAX_DESC}`);
    else ok(`${skill.name}: description ${description.length} 字符`);
  }
}

// mcpServers 校验
const mcp = manifest.mcpServers ?? {};
const mcpNames = Object.keys(mcp);
if (mcpNames.length === 0) {
  console.log('  ⏭  无 mcpServers 定义');
} else {
  ok(`${mcpNames.length} 个 MCP 服务器`);
  const urls = new Set();
  for (const [name, s] of Object.entries(mcp)) {
    if (!s.type || !['http', 'sse', 'stdio'].includes(s.type)) {
      err(`${name}: mcpServers.type 必须是 http / sse / stdio`);
      continue;
    }
    if (s.type === 'stdio') {
      if (!s.command || typeof s.command !== 'string') err(`${name}: stdio 需要 command (字符串)`);
      else ok(`${name}: stdio ${s.command}`);
    } else {
      if (!s.url) err(`${name}: 缺少 url`);
      else if (urls.has(s.url)) err(`${name}: URL 与另一个服务器重复 (${s.url})`);
      else {
        urls.add(s.url);
        ok(`${name}: ${s.type} ${s.url}`);
      }
    }
    if (s.skills) {
      for (const k of s.skills) {
        if (!manifest.skills.some((x) => x.name === k)) err(`${name}: skills 引用了不存在的技能 ${k}`);
      }
    }
  }
}

// 网络可达性
if (process.argv.includes('--network')) {
  console.log('\n检查 git 来源可达性（ls-remote）…');
  for (const skill of manifest.skills) {
    if (skill.source.type !== 'git') continue;
    const { url, ref } = skill.source;
    let reachable = false;
    for (const r of [`refs/heads/${ref}`, `refs/tags/${ref}`]) {
      try {
        execFileSync('git', ['ls-remote', url, r], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
        reachable = true;
        break;
      } catch { /* 尝试下一种 */ }
    }
    if (reachable) ok(`${skill.name}: ${url} 可达`);
    else err(`${skill.name}: ${url} (ref: ${ref}) 不可达`);
  }
}

console.log('');
if (errors > 0) {
  console.error(`❌ 校验失败：${errors} 个问题`);
  process.exit(1);
}
console.log('✅ 校验通过');
