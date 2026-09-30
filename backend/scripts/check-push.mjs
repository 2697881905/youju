#!/usr/bin/env node
// 华为推送自检：验证「凭据文件 → PS256 JWT → v3 试发」整链路是否通。
// 用法（在 backend/ 目录下）：node scripts/check-push.mjs
//
// 为什么需要它：推送的任何一环配错都表现为「通知照常落库、手机啥也没有」，日志里
// 只有一行降级提示，等到上线才发现已经晚了。这里把凭据、签名算法、项目 ID、
// 消息体结构逐项显式验证一次，任何一步不对都以非 0 退出。

import { readFileSync, existsSync } from 'fs';
import { sign, constants } from 'crypto';
import { resolve } from 'path';
import dotenv from 'dotenv';

dotenv.config();

const projectId = (process.env.HUAWEI_PUSH_PROJECT_ID ?? '').trim();
const saPath = process.env.HUAWEI_PUSH_SERVICE_ACCOUNT_PATH ?? './agc-service-account.json';
const apiUrl = (process.env.HUAWEI_PUSH_API_URL ?? 'https://push-api.cloud.huawei.com').trim();
const category = (process.env.HUAWEI_PUSH_CATEGORY ?? 'IM').trim();
const testMessage = (process.env.HUAWEI_PUSH_TEST_MESSAGE ?? 'true') === 'true';

let failed = false;
function fail(msg) {
  failed = true;
  console.error('  ✗ ' + msg);
}
function pass(msg) {
  console.log('  ✓ ' + msg);
}

console.log('== 华为推送自检 ==\n');

// --- 1. 配置完整性 ---
console.log('[1] 配置');
if (projectId === '') {
  fail('HUAWEI_PUSH_PROJECT_ID 未配置（AGC → 项目设置 → 项目 ID）');
} else {
  pass(`HUAWEI_PUSH_PROJECT_ID=${projectId}`);
}
console.log(`  凭据路径：${saPath}`);
if (!existsSync(saPath)) {
  fail(`凭据文件不存在：${resolve(saPath)}`);
  console.error('\n请把 AGC 下载的服务账号 JSON 放到该路径后重试。');
  process.exit(1);
}
pass('凭据文件存在');

// --- 2. 凭据四要素 ---
console.log('\n[2] 服务账号凭据');
let sa;
try {
  sa = JSON.parse(readFileSync(saPath, 'utf8'));
} catch (e) {
  fail('凭据文件不是合法 JSON：' + e.message);
  process.exit(1);
}
const fields = { project_id: 'project_id', key_id: 'key_id', private_key: 'private_key', sub_account: 'sub_account' };
let fieldsOk = true;
for (const key of Object.keys(fields)) {
  const v = sa[key];
  if (typeof v !== 'string' || v === '') {
    fail(`缺少字段 ${key}`);
    fieldsOk = false;
  }
}
if (!fieldsOk) {
  process.exit(1);
}
pass(`project_id=${sa.project_id}  sub_account=${sa.sub_account}  key_id=${sa.key_id}`);
if (projectId !== '' && projectId !== sa.project_id) {
  console.log(`  ⚠ env 的 PROJECT_ID(${projectId}) 与凭据文件里的(${sa.project_id})不一致 —— 以 env 为准去调 API，多半踩错项目`);
}
if (!sa.private_key.includes('BEGIN PRIVATE KEY')) {
  fail('private_key 不是 PKCS#8 PEM（应以 -----BEGIN PRIVATE KEY----- 开头）');
  process.exit(1);
}
pass('private_key 格式正确（PKCS#8）');

// --- 3. PS256 签名 ---
console.log('\n[3] PS256 JWT 生成');
function base64Url(bufOrStr) {
  const buf = typeof bufOrStr === 'string' ? Buffer.from(bufOrStr, 'utf8') : bufOrStr;
  return buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}
let jwt = '';
try {
  const iat = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ kid: sa.key_id, typ: 'JWT', alg: 'PS256' }));
  const payload = base64Url(
    JSON.stringify({
      aud: sa.token_uri || 'https://oauth-login.cloud.huawei.com/oauth2/v3/token',
      iss: sa.sub_account,
      exp: iat + 3600,
      iat,
    }),
  );
  const signingInput = `${header}.${payload}`;
  // ⚠️ 必须 PSS 填充（PS256），不是 PKCS#1 v1.5 —— 用错会在第 4 步拿到鉴权失败。
  const signature = sign('sha256', Buffer.from(signingInput, 'utf8'), {
    key: sa.private_key,
    padding: constants.RSA_PKCS1_PSS_PADDING,
    saltLength: constants.RSA_PSS_SALTLEN_DIGEST,
  });
  jwt = `${signingInput}.${base64Url(signature)}`;
  pass(`JWT 生成成功（${jwt.length} 字符，有效期 1 小时）`);
} catch (e) {
  fail('JWT 签名失败：' + e.message);
  process.exit(1);
}

// --- 4. v3 试发（validate_only，不会真的推到手机）---
console.log('\n[4] REST API v3 试发（validate_only，不下发真机）');
const body = {
  payload: {
    notification: {
      category,
      title: '有据自检',
      body: '这是一条不下发的校验消息',
      clickAction: { actionType: 0, data: { type: 'system' } },
    },
  },
  target: { token: ['self-check-placeholder-token'] },
  pushOptions: { ttl: 86400, testMessage },
};
let res;
let text;
try {
  res = await fetch(`${apiUrl}/v3/${projectId}/messages:send`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${jwt}`,
      'push-type': '0',
    },
    body: JSON.stringify(body),
  });
  text = await res.text();
} catch (e) {
  fail('请求失败：' + e.message);
  process.exit(1);
}

console.log(`  HTTP ${res.status}  ${text.slice(0, 300)}`);
if (res.status === 401 || res.status === 403) {
  fail('鉴权失败 —— 检查：服务账号是否为「开发者级」、是否被停用、project_id 与项目是否匹配');
} else if (res.status === 400) {
  const msg = safeParse(text);
  if (msg && (msg.subError === 50603 || String(msg.message ?? '').includes('token'))) {
    // 走到消息体校验层说明鉴权已经过了，只因为用的是占位 token
    pass('鉴权通过（占位 token 触发的消息体报错属预期）');
  } else {
    fail('消息体不合法：' + text.slice(0, 300));
  }
} else if (res.ok) {
  pass('试发校验通过（validate_only 未真实下发）');
} else {
  fail('未预期响应，请把上面内容贴出来排查');
}

console.log('\n== 自检' + (failed ? '未通过' : '通过') + ' ==');
process.exit(failed ? 1 : 0);

function safeParse(s) {
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
}
