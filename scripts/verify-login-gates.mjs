#!/usr/bin/env node
// 登录闸门体检：确认「未登录就没有意义」的页面都装了 aboutToAppear 首行闸门，
// 且 api.ets 的 401 全局标记不会因**匿名**请求误触发。
//
// 为什么需要它：
//   1) 闸门是「入口页 + 目标页」两层。目标页那层用 replaceUrl 把自身从路由栈里替换掉，
//      用户取消登录返回时才会落到入口页（设置页/我的页），而不是停在目标页。
//      这层一旦被删（改代码、陈旧文件回写），症状是「跳登录页 → 返回 → 落在子页」。
//   2) 匿名 401 若打全局标记，Index 会 pushUrl 登录页压在当前内层页之上 —— 同样症状，
//      但根因在 services/api.ets，光看页面代码查不出来。
//
// 用法：node scripts/verify-login-gates.mjs   （非 0 退出 = 有缺口）
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = process.cwd();
const PAGES = join(ROOT, 'entry/src/main/ets/pages');
const API = join(ROOT, 'entry/src/main/ets/services/api.ets');

// 必须带闸门的页面（全部只服务「我自己的数据/权限」，未登录进来必然空壳或报错）
const GATED_PAGES = [
  'AccountBindingPage.ets',
  'BlocklistPage.ets',
  'BookmarkFolderDetailPage.ets',
  'BookmarkFolderPage.ets',
  'DraftBoxPage.ets',
  'EditProfilePage.ets',
  'InterestTagsPage.ets',
  'MyFollowView.ets',
  'NotificationSettingsPage.ets',
  'PhotoPublishPage.ets',
  'PrivacySettingsPage.ets',
  'ReportAdminPage.ets',
  'TextPublishPage.ets',
  'TrashBoxPage.ets',
  'VideoPublishPage.ets',
];

// 这些页面**不应**有闸门（公开可浏览 / 就是登录页本身）
const PUBLIC_PAGES = ['LoginView.ets', 'AboutPage.ets', 'PrivacyPage.ets', 'UserAgreementPage.ets'];

const errors = [];
const notes = [];

function sliceAboutToAppear(src, lookahead = 12) {
  const lines = src.split('\n');
  const i = lines.findIndex((l) => /aboutToAppear\(\)\s*:\s*void\s*\{/.test(l));
  if (i < 0) {
    return null;
  }
  return { body: lines.slice(i, i + lookahead).join('\n'), atLine: i + 1 };
}

for (const f of GATED_PAGES) {
  const p = join(PAGES, f);
  if (!existsSync(p)) {
    errors.push(`${f}: 文件不存在`);
    continue;
  }
  const src = readFileSync(p, 'utf8');
  const shell = sliceAboutToAppear(src);
  if (shell === null) {
    errors.push(`${f}: 找不到 aboutToAppear`);
    continue;
  }
  const hasGuardCond = shell.body.includes('getUserId() === 0');
  const hasReplace = shell.body.includes('replaceUrl') && shell.body.includes('pages/LoginPage');
  const hasReturn = /\breturn\b/.test(shell.body);
  if (!hasGuardCond) {
    errors.push(`${f}: aboutToAppear(L${shell.atLine}) 缺未登录判断 getUserId() === 0`);
  }
  if (!hasReplace) {
    errors.push(`${f}: aboutToAppear(L${shell.atLine}) 未用 replaceUrl 跳 pages/LoginPage（用 push 会让本页留在栈里）`);
  }
  if (!hasReturn) {
    errors.push(`${f}: aboutToAppear(L${shell.atLine}) 命中闸门后没有 return（会继续往下拉数据）`);
  }
}

for (const f of PUBLIC_PAGES) {
  const p = join(PAGES, f);
  if (!existsSync(p)) {
    continue;
  }
  const src = readFileSync(p, 'utf8');
  if (src.includes("replaceUrl({ url: 'pages/LoginPage' })")) {
    notes.push(`${f}: 公开页里出现了登录闸门，确认是否有意为之`);
  }
}

// api.ets：匿名 401 不许打全局标记
if (!existsSync(API)) {
  errors.push('services/api.ets: 文件不存在');
} else {
  const api = readFileSync(API, 'utf8');
  const fnIdx = api.indexOf('function markAuthExpired');
  if (fnIdx < 0) {
    errors.push('services/api.ets: 找不到 markAuthExpired（若已重命名，本脚本需同步更新）');
  } else {
    const body = api.slice(fnIdx, fnIdx + 900);
    if (!body.includes('hasLocalToken')) {
      errors.push('services/api.ets: markAuthExpired 未按本地是否有 token 分流 —— 匿名 401 会误触发全局登录引导（登录页凭空压在内层页之上）');
    }
    if (!/hasLocalToken\(\)[\s\S]{0,40}return/.test(body)) {
      errors.push('services/api.ets: markAuthExpired 里 hasLocalToken 判断后未见 return 短路，检查逻辑');
    }
  }
  if (!api.includes('function unauthorizedMessage')) {
    notes.push('services/api.ets: 未找到 unauthorizedMessage（401 文案未区分「会话过期」与「需登录」）');
  }
}

console.log('');
if (notes.length > 0) {
  console.log(`[提示] ${notes.length} 项：`);
  for (const n of notes) {
    console.log(`  · ${n}`);
  }
  console.log('');
}
if (errors.length === 0) {
  console.log(`[通过] ${GATED_PAGES.length} 个需登录页面都装了 replaceUrl 闸门；匿名 401 不会触发全局登录引导。`);
  process.exit(0);
}
console.log(`[失败] ${errors.length} 项：`);
for (const e of errors) {
  console.log(`  ✗ ${e}`);
}
process.exit(1);
