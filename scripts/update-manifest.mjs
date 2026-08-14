#!/usr/bin/env node
/**
 * MySkillKit 清单维护脚本
 *
 * 用法:
 *   node scripts/update-manifest.mjs refresh                        # 刷新所有 git 技能的最新 commit（ls-remote，快）
 *   node scripts/update-manifest.mjs refresh --fetch-descriptions  # 同时重新拉取各技能 SKILL.md 描述（慢，会稀疏克隆）
 *   node scripts/update-manifest.mjs add <name> --source git --url <repo>.git --path <子目录> --ref main
 *   node scripts/update-manifest.mjs add <name> --source local --path <本机路径>
 *   node scripts/update-manifest.mjs add <name> --source embedded
 *
 * 说明:
 *   - manifest.json 只记录来源与版本信息，不保存技能本体
 *   - git 来源的 commit 由 `git ls-remote` 获取（快）或克隆后获取（精确）
 */
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const KIT_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const MANIFEST_PATH = join(KIT_ROOT, 'manifest.json');

// ---------- 小工具 ----------

function run(cmd, args, opts = {}) {
  return execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], ...opts }).trim();
}

function fail(msg) {
  console.error(`\n❌ ${msg}`);
  process.exit(1);
}

function readManifest() {
  if (!existsSync(MANIFEST_PATH)) return { name: 'MySkillKit', description: '', version: '1.0.0', skills: [] };
  const m = JSON.parse(readFileSync(MANIFEST_PATH, 'utf8'));
  m.skills ??= [];
  return m;
}

function writeManifest(m) {
  m.skills.sort((a, b) => a.name.localeCompare(b.name));
  m.generatedAt = new Date().toISOString();
  writeFileSync(MANIFEST_PATH, JSON.stringify(m, null, 2) + '\n', 'utf8');
  console.log(`✅ manifest.json 已更新（${m.skills.length} 个技能）`);
}

/**
 * 从 git 仓库稀疏检出单个技能目录，执行 fn(dir, commit) 后自动清理临时克隆。
 * 优先 --filter=blob:none --sparse（大仓库快），失败回退普通浅克隆。
 */
function withSparseSkill(source, fn) {
  const { url, path, ref } = source;
  const tmpDirs = [];
  try {
    let repoDir = null;
    let cloneErr = null;
    const tmp = mkdtempSync(join(tmpdir(), 'msk-'));
    tmpDirs.push(tmp);
    try {
      run('git', ['clone', '--depth', '1', '--filter=blob:none', '--sparse', '-b', ref, url, tmp]);
      repoDir = tmp;
    } catch (e) {
      cloneErr = e;
      // 回退：不支持 filter/sparse 的 git 版本用普通浅克隆
      const tmp2 = mkdtempSync(join(tmpdir(), 'msk-'));
      tmpDirs.push(tmp2);
      try {
        run('git', ['clone', '--depth', '1', '-b', ref, url, tmp2]);
        repoDir = tmp2;
      } catch {
        fail(`无法克隆 ${url}（ref: ${ref}）: ${e.message.split('\n')[0]}`);
      }
    }
    if (repoDir) {
      try {
        run('git', ['-C', repoDir, 'sparse-checkout', 'set', path]);
      } catch {
        /* 普通克隆时若子目录不存在会在下面暴露 */
      }
    }
    const dir = join(repoDir, path);
    if (!existsSync(dir)) fail(`来源中不存在 ${url}#${path}（ref: ${ref}）`);
    const commit = run('git', ['-C', repoDir, 'rev-parse', 'HEAD']);
    return fn(dir, commit);
  } finally {
    for (const d of tmpDirs) rmSync(d, { recursive: true, force: true });
  }
}

/** 从 SKILL.md 提取 frontmatter description（支持单行引号/非引号） */
function readDescription(skillDir) {
  const skillMd = join(skillDir, 'SKILL.md');
  if (!existsSync(skillMd)) fail(`缺少 ${skillMd}`);
  const content = readFileSync(skillMd, 'utf8');
  const m = content.match(/^description:\s*(?:"([^"]*)"|'([^']*)'|(.+))$/m);
  return (m?.[1] ?? m?.[2] ?? m?.[3] ?? '').trim();
}

/** git ls-remote 取某 ref 的最新 commit（分支优先，标签兜底） */
function remoteCommit(url, ref) {
  for (const r of [`refs/heads/${ref}`, `refs/tags/${ref}`]) {
    try {
      const out = run('git', ['ls-remote', url, r]);
      const line = out.split('\n')[0];
      if (line) return line.split(/\t/)[0];
    } catch { /* 尝试下一种 */ }
  }
  return null;
}

// ---------- 子命令 ----------

function cmdRefresh(args) {
  const manifest = readManifest();
  const fetchDescriptions = args.includes('--fetch-descriptions');
  let changed = 0;

  for (const skill of manifest.skills) {
    if (skill.source.type !== 'git') {
      console.log(`⏭  ${skill.name}: ${skill.source.type} 来源，无需刷新`);
      continue;
    }
    const { url, ref } = skill.source;
    if (fetchDescriptions) {
      const { desc, commit } = withSparseSkill(skill.source, (dir, commit) => ({
        desc: readDescription(dir),
        commit,
      }));
      if (skill.description !== desc || skill.version?.commit !== commit) changed++;
      skill.description = desc;
      skill.version = { commit, checkedAt: new Date().toISOString() };
      console.log(`🔄 ${skill.name}: ${commit.slice(0, 7)} 描述已刷新`);
    } else {
      const commit = remoteCommit(url, ref);
      if (!commit) {
        console.warn(`⚠️  ${skill.name}: ls-remote 失败，跳过`);
        continue;
      }
      if (skill.version?.commit !== commit) changed++;
      skill.version = { commit, checkedAt: new Date().toISOString() };
      console.log(`🔄 ${skill.name}: ${commit.slice(0, 7)} (${ref})`);
    }
  }
  if (changed > 0 || fetchDescriptions) writeManifest(manifest);
  else console.log('✅ 无变化');
}

function cmdAdd(args) {
  const name = args[0];
  if (!name || !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name)) {
    fail('用法: add <name> --source git|local|embedded [--url <url>] [--path <path>] [--ref <ref>]');
  }
  const get = (k) => {
    const i = args.indexOf(`--${k}`);
    return i >= 0 ? args[i + 1] : null;
  };
  const sourceType = get('source');
  if (!['git', 'local', 'embedded'].includes(sourceType)) fail('--source 必须是 git / local / embedded');

  const manifest = readManifest();
  if (manifest.skills.some((s) => s.name === name)) fail(`技能 ${name} 已存在`);

  const entry = { name, description: '', source: { type: sourceType } };

  if (sourceType === 'git') {
    const url = get('url');
    const path = get('path');
    const ref = get('ref') ?? 'main';
    if (!url || !path) fail('git 来源需要 --url 与 --path');
    entry.source = { type: 'git', url, path, ref };
    withSparseSkill(entry.source, (dir, commit) => {
      entry.description = readDescription(dir);
      entry.version = { commit, checkedAt: new Date().toISOString() };
    });
    console.log(`➕ ${name}: ${entry.version.commit.slice(0, 7)} 来自 ${url}#${path}`);
  } else if (sourceType === 'local') {
    const path = get('path');
    if (!path) fail('local 来源需要 --path');
    entry.source = { type: 'local', path };
    entry.description = readDescription(path);
    console.log(`➕ ${name}: 本机来源 ${path}`);
  } else {
    const vendorDir = join(KIT_ROOT, 'vendor', name);
    if (!existsSync(join(vendorDir, 'SKILL.md'))) fail(`vendor/${name}/SKILL.md 不存在`);
    entry.source = { type: 'embedded', path: `vendor/${name}` };
    entry.description = readDescription(vendorDir);
    console.log(`➕ ${name}: 兜底本体 vendor/${name}`);
  }

  manifest.skills.push(entry);
  writeManifest(manifest);
}

// ---------- 入口 ----------

const [cmd, ...rest] = process.argv.slice(2);
switch (cmd) {
  case 'add':
    cmdAdd(rest);
    break;
  case 'refresh':
  case undefined:
    cmdRefresh(rest);
    break;
  default:
    fail(`未知命令 ${cmd}（支持: add / refresh）`);
}
