#!/usr/bin/env node
/**
 * 拦截「旧支线内容被回写进主检出」的提交。
 *
 * 背景（2026-09-27 事故）：本机 `WorkBuddy/Worktrees/<repo>/main-*` 下有多个由 agent
 * 会话创建的 git worktree，它们的分支停在旧提交上。某个环节把旧 worktree 里的整份
 * 文件写回主检出，静默回退了「首页分段栏 Swiper 分页 + 一镜到底接线」以及最新的
 * P1-3 分页竞态修复 —— 而 git status 只显示「几个文件被改」。
 *
 * 三道判据（任一命中即拦截）：
 *   A. staged 文件的内容 == 任一现存 worktree 里同名文件的内容   ← 精准命中本次事故形态
 *   B. staged 文件在 HEAD→index 之间是「净删除式大回退」          ← 通用兜底
 *   C. 取证：A/B 命中时用 git log --find-object 打印内容来自哪个提交
 *
 * 旁路：SKIP_STALE_CHECK=1 git commit ...
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const BYPASS = process.env.SKIP_STALE_CHECK === '1' || process.env.SKIP_STALE_CHECK === 'true';

// 判据 B 阈值：单文件净删除 150 行以上，且删除量 ≥ 新增量的 3 倍
const B_MIN_DELETIONS = 150;
const B_DEL_RATIO = 3;

function git(args, opts) {
  const o = Object.assign({ encoding: 'utf8' }, opts || {});
  return execFileSync('git', args, o).toString().trim();
}

function gitSafe(args, opts) {
  try {
    return git(args, opts);
  } catch (e) {
    return '';
  }
}

function listWorktrees(repoRoot) {
  const raw = gitSafe(['worktree', 'list', '--porcelain']);
  const out = [];
  let cur = null;
  for (const line of raw.split('\n')) {
    if (line.startsWith('worktree ')) {
      if (cur !== null) out.push(cur);
      cur = { path: line.slice('worktree '.length).trim(), branch: '', head: '' };
    } else if (line.startsWith('HEAD ') && cur !== null) {
      cur.head = line.slice('HEAD '.length).trim();
    } else if (line.startsWith('branch ') && cur !== null) {
      cur.branch = line.slice('branch '.length).trim().replace(/^refs\/heads\//, '');
    }
  }
  if (cur !== null) out.push(cur);
  // 排掉当前主检出（它自己不是「另一份旧检出」）
  const rootReal = fs.realpathSync(repoRoot);
  return out.filter((w) => fs.realpathSync(w.path) !== rootReal);
}

function main() {
  if (BYPASS) {
    console.error('[stale-overwrite] SKIP_STALE_CHECK 已设置，跳过检查');
    process.exit(0);
  }

  const repoRoot = git(['rev-parse', '--show-toplevel']);
  const staged = gitSafe(['diff', '--cached', '--name-only', '--diff-filter=ACMR'])
    .split('\n')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  if (staged.length === 0) process.exit(0);

  const worktrees = listWorktrees(repoRoot);
  const numstat = gitSafe(['diff', '--cached', '--numstat']);
  const statOf = new Map();
  for (const line of numstat.split('\n')) {
    const parts = line.split('\t');
    if (parts.length < 3) continue;
    const ins = parts[0] === '-' ? 0 : Number(parts[0]);
    const del = parts[1] === '-' ? 0 : Number(parts[1]);
    statOf.set(parts.slice(2).join('\t'), { ins, del });
  }

  const hitsA = [];
  const hitsB = [];

  for (const file of staged) {
    const stagedBlob = gitSafe(['rev-parse', ':' + file]);
    if (stagedBlob.length === 0) continue;

    // 判据 A：与任一其他 worktree 的同名文件逐字节相同
    for (const wt of worktrees) {
      const full = path.join(wt.path, file);
      if (!fs.existsSync(full)) continue;
      const wtBlob = gitSafe(['hash-object', full], { cwd: wt.path });
      if (wtBlob !== '' && wtBlob === stagedBlob) {
        hitsA.push({ file, wt, blob: stagedBlob });
        break;
      }
      const wtHeadBlob = gitSafe(['rev-parse', 'HEAD:' + file], { cwd: wt.path });
      if (wtHeadBlob !== '' && wtHeadBlob === stagedBlob) {
        hitsA.push({ file, wt, blob: stagedBlob });
        break;
      }
    }

    // 判据 B：净删除式大回退
    const st = statOf.get(file);
    if (st !== undefined && st.del >= B_MIN_DELETIONS && st.del >= B_DEL_RATIO * Math.max(st.ins, 1)) {
      hitsB.push({ file, ins: st.ins, del: st.del });
    }
  }

  if (hitsA.length === 0 && hitsB.length === 0) process.exit(0);

  const bar = '─'.repeat(72);
  console.error('');
  console.error(bar);
  console.error('⛔  疑似「旧支线内容回写主检出」，已阻止本次提交');
  console.error(bar);

  if (hitsA.length > 0) {
    console.error('');
    console.error('【判据 A】staged 内容与另一个 worktree 里的同名文件完全相同：');
    for (const h of hitsA) {
      console.error(`  · ${h.file}`);
      console.error(`      来源 worktree: ${h.wt.path}  (分支 ${h.wt.branch || '(detached)'} @ ${h.wt.head.slice(0, 8)})`);
    }
    console.error('');
    console.error('  这几乎不可能是有意为之 —— 主检出的新版文件被一份旧检出覆盖了。');
  }

  if (hitsB.length > 0) {
    console.error('');
    console.error(`【判据 B】单文件净删除 ≥ ${B_MIN_DELETIONS} 行且删除 ≥ 新增的 ${B_DEL_RATIO} 倍：`);
    for (const h of hitsB) {
      console.error(`  · ${h.file}   -${h.del} 行 / +${h.ins} 行`);
    }
    console.error('');
    console.error('  这类「大段删除」可能是旧版覆盖，也可能是有意的死代码清理。');
  }

  // 判据 C：取证，打印内容来自哪些提交
  const blobs = Array.from(new Set(hitsA.map((h) => h.blob).concat(
    hitsB.map((h) => gitSafe(['rev-parse', ':' + h.file])).filter((b) => b !== ''),
  )));
  if (blobs.length > 0) {
    console.error('');
    console.error('【取证】这些内容在历史里出现于（git log --find-object，可能耗时几秒）：');
    for (const b of blobs.slice(0, 8)) {
      const found = gitSafe(['log', '--all', '--oneline', '--find-object=' + b]).split('\n')
        .map((s) => s.trim()).filter((s) => s.length > 0).slice(0, 4);
      console.error(`  blob ${b.slice(0, 10)}:`);
      if (found.length === 0) {
        console.error('      (任何提交里都没有 → 是新内容，B 判据可放行)');
      } else {
        for (const f of found) console.error('      ' + f);
      }
    }
  }

  console.error('');
  console.error(bar);
  console.error('怎么处理：');
  console.error('  1) 若确认是被旧版覆盖 → 还原：git checkout HEAD -- <file>');
  console.error('  2) 若确认是有意的删除/重构   → 放行：SKIP_STALE_CHECK=1 git commit ...');
  console.error('  3) 清理僵尸 worktree        → node scripts/git-doctor.mjs --prune');
  console.error(bar);
  console.error('');
  process.exit(1);
}

main();
