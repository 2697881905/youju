#!/usr/bin/env node
/**
 * git worktree 体检 / 清理 / 对齐（本机多 agent 会话共享一个仓库时必跑）。
 *
 * 为什么需要：WorkBuddy 的 agent 会话会在 `~/WorkBuddy/Worktrees/<repo>/main-<hash>`
 * 下创建 git worktree，分支 `workbuddy/main-<hash>` 停在该会话启动时的 main 上。
 * 会话结束后这些 worktree 不清理 → 分支永久陈旧 → 一旦发生"回写"，主检出的新功能
 * 会被静默回退（2026-09-27 事故）。
 *
 * 用法：
 *   node scripts/git-doctor.mjs                 只体检，不改任何东西
 *   node scripts/git-doctor.mjs --sync          把「干净且无独有提交」的 worktree 快进到 main
 *   node scripts/git-doctor.mjs --prune         删除「干净且无独有提交」的 worktree + 其分支
 *   node scripts/git-doctor.mjs --snapshot      把主检出未提交改动打包成 refs/snapshots/<ts>
 *   node scripts/git-doctor.mjs --base develop  指定基线分支（默认 main）
 *   加 --dry-run 只看会做什么
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const argv = process.argv.slice(2);
const has = (f) => argv.includes(f);
const DRY = has('--dry-run');
const DO_SYNC = has('--sync');
const DO_PRUNE = has('--prune');
const DO_SNAPSHOT = has('--snapshot');
const baseIdx = argv.indexOf('--base');
const BASE = baseIdx >= 0 && argv[baseIdx + 1] ? argv[baseIdx + 1] : 'main';

function git(args, cwd) {
  return execFileSync('git', args, { encoding: 'utf8', cwd }).toString().trim();
}
function gitSafe(args, cwd) {
  try {
    return git(args, cwd);
  } catch (e) {
    return '';
  }
}

function listWorktrees(repoRoot) {
  const raw = gitSafe(['worktree', 'list', '--porcelain'], repoRoot);
  const out = [];
  let cur = null;
  for (const line of raw.split('\n')) {
    if (line.startsWith('worktree ')) {
      if (cur !== null) out.push(cur);
      cur = { path: line.slice('worktree '.length).trim(), branch: '', head: '', detached: false };
    } else if (line.startsWith('HEAD ') && cur !== null) {
      cur.head = line.slice('HEAD '.length).trim();
    } else if (line.startsWith('branch ') && cur !== null) {
      cur.branch = line.slice('branch '.length).trim().replace(/^refs\/heads\//, '');
    } else if (line.trim() === 'detached' && cur !== null) {
      cur.detached = true;
    }
  }
  if (cur !== null) out.push(cur);
  return out;
}

function pad(s, n) {
  const str = String(s);
  // 中文字符按 2 列估算，避免表格错位
  let w = 0;
  for (const ch of str) w += /[\u2E80-\uA4CF\uAC00-\uD7A3\uF900-\uFAFF\uFE30-\uFE4F\uFF00-\uFF60]/.test(ch) ? 2 : 1;
  return str + ' '.repeat(Math.max(0, n - w));
}

function main() {
  const repoRoot = git(['rev-parse', '--show-toplevel']);
  const all = listWorktrees(repoRoot);
  const rootReal = fs.realpathSync(repoRoot);
  const mainEntry = all.find((w) => fs.realpathSync(w.path) === rootReal);
  const others = all.filter((w) => fs.realpathSync(w.path) !== rootReal);

  console.log('');
  console.log('仓库      : ' + repoRoot);
  console.log('主检出    : ' + (mainEntry ? mainEntry.branch + ' @ ' + mainEntry.head.slice(0, 8) : '?'));
  console.log('基线分支  : ' + BASE);
  console.log('其它 worktree: ' + others.length + ' 个');
  console.log('');

  if (!mainEntry) {
    console.error('✗ 找不到主检出（当前目录不是 worktree？）');
    process.exit(1);
  }

  const rows = [];
  for (const w of others) {
    const behind = Number(gitSafe(['rev-list', '--count', 'HEAD..' + BASE], w.path) || '0');
    const ahead = Number(gitSafe(['rev-list', '--count', BASE + '..HEAD'], w.path) || '0');
    const dirtyRaw = gitSafe(['status', '--porcelain'], w.path);
    const dirty = dirtyRaw.split('\n').filter((s) => s.trim().length > 0).length;
    rows.push({ w, behind, ahead, dirty });
  }

  console.log(pad('worktree', 64) + pad('分支', 30) + pad('落后', 8) + pad('独有', 8) + '状态');
  console.log('─'.repeat(128));
  for (const r of rows) {
    const safe = r.ahead === 0 && r.dirty === 0;
    const flag = r.ahead > 0 ? '⚠ 有独有提交，勿删' : (r.dirty > 0 ? '⚠ 工作树脏，勿删/勿同步' : (r.behind > 0 ? '可清理 / 可快进' : '已最新'));
    console.log(
      pad(r.w.path.replace(process.env.HOME || '', '~'), 64)
      + pad(r.w.branch + (r.w.detached ? ' (detached)' : ''), 30)
      + pad(String(r.behind), 8)
      + pad(String(r.ahead), 8)
      + (safe ? '' : '') + flag,
    );
  }

  const stale = rows.filter((r) => r.ahead === 0 && r.dirty === 0 && r.behind > 0);
  console.log('');
  console.log(`结论：${rows.length} 个 worktree，其中 ${stale.length} 个「落后且干净」（陈旧检出）。`);
  if (stale.length > 0) {
    console.log('');
    console.log('陈旧检出就是功能被静默回退的源头。建议：');
    console.log('  node scripts/git-doctor.mjs --sync    把它们快进到最新（保留目录，消除旧内容）');
    console.log('  node scripts/git-doctor.mjs --prune   连目录一起删掉（推荐，省磁盘）');
  } else if (rows.length > 0) {
    console.log('（无陈旧检出。注意：只要还有第二个已检出的 worktree，就仍有「旧内容被复制回来」的可能。）');
  } else {
    console.log('（没有其它 worktree —— 已无「第二份检出覆盖主检出」的通路。）');
  }

  // 陈旧支线：已完全并入基线、但 tip 不是基线 —— 单独存在无害（分支本身不会覆盖文件），
  // 但只要有人把它 checkout 成 worktree，就会重新产生一个旧内容源。列出来供清理。
  // 用 for-each-ref 拿 symref，跳过 origin/HEAD 这类符号引用。
  const branchRaw = gitSafe(['for-each-ref', '--format=%(refname:short)\t%(symref)', 'refs/heads', 'refs/remotes'], repoRoot);
  const staleBranches = [];
  for (const line of branchRaw.split('\n')) {
    const parts = line.split('\t');
    const name = (parts[0] || '').trim();
    const symref = (parts[1] || '').trim();
    if (name.length === 0 || symref.length > 0) continue;
    if (name === BASE || name === 'origin/' + BASE) continue;
    if (name === mainEntry.branch) continue;
    const unique = gitSafe(['log', '--oneline', BASE + '..' + name], repoRoot);
    if (unique.length === 0) staleBranches.push(name);
  }
  if (staleBranches.length > 0) {
    console.log('');
    console.log('已完全并入 ' + BASE + ' 的陈旧支线（可删，删了能少一个"旧内容源"）：');
    for (const b of staleBranches) {
      const remote = b.startsWith('origin/');
      console.log('  · ' + b + '   ' + (remote ? 'git push origin --delete ' + b.slice('origin/'.length) : 'git branch -d ' + b));
    }
  }

  if (DO_SYNC) {
    console.log('');
    console.log('== --sync ==');
    for (const r of stale) {
      if (DRY) {
        console.log('  [dry-run] 快进 ' + r.w.path);
        continue;
      }
      const out = gitSafe(['merge', '--ff-only', BASE], r.w.path);
      console.log('  ' + (out.length > 0 ? '✓' : '✗') + ' ' + r.w.path + (out.length > 0 ? '' : ' （快进失败，可能需要手动处理）'));
    }
  }

  if (DO_PRUNE) {
    console.log('');
    console.log('== --prune ==');
    for (const r of stale) {
      if (DRY) {
        console.log('  [dry-run] 删除 ' + r.w.path + '  与分支 ' + r.w.branch);
        continue;
      }
      let ok = true;
      try {
        git(['worktree', 'remove', r.w.path], repoRoot);
      } catch (e) {
        // 常见原因：目录里只有被 ignore 的产物（oh_modules/.preview/build）→ 用 --force
        try {
          git(['worktree', 'remove', '--force', r.w.path], repoRoot);
        } catch (e2) {
          ok = false;
          console.log('  ✗ 删除失败 ' + r.w.path + ' —— ' + String(e2.message || e2).split('\n')[0]);
        }
      }
      if (ok) {
        const bd = gitSafe(['branch', '-d', r.w.branch], repoRoot);
        console.log('  ✓ 已删除 ' + r.w.path + '  分支 ' + r.w.branch + (bd.length > 0 ? ' （分支已删）' : ''));
      }
    }
    if (!DRY) {
      gitSafe(['worktree', 'prune'], repoRoot);
      console.log('  ✓ worktree prune 完成');
    }
  }

  if (DO_SNAPSHOT) {
    console.log('');
    console.log('== --snapshot ==');
    const dirtyMain = gitSafe(['status', '--porcelain'], rootReal);
    if (dirtyMain.length === 0) {
      console.log('  主检出无未提交改动，无需快照');
    } else {
      const sha = gitSafe(['stash', 'create'], rootReal);
      if (sha.length === 0) {
        console.log('  stash create 无输出（可能只有未跟踪文件），无需快照');
      } else {
        const ts = new Date().toISOString().replace(/[:.]/g, '-');
        const ref = 'refs/snapshots/' + ts;
        if (DRY) {
          console.log('  [dry-run] 会写 ' + ref + ' -> ' + sha);
        } else {
          git(['update-ref', ref, sha], rootReal);
          console.log('  ✓ 快照已存 ' + ref + '  (' + sha.slice(0, 8) + ')');
          console.log('    恢复全部：git stash apply ' + sha);
          console.log('    恢复单文件：git show ' + sha + ':path/to/file > path/to/file');
        }
      }
    }
  }

  console.log('');
}

main();
