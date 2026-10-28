#!/usr/bin/env node
// 有据 · AGC 官方口径活跃设备数取数脚本
// 用途：把「月活 400」这个 KPI 从我的 DB 代理值升级成华为官方报表读数。
//   Reports API 的 measures 里有 activeDevice(活跃设备数)/newDevice(新增设备数)/
//   sumDevice(累计设备数)/installedDeviceCnt(存量安装设备数)，见官方
//   「获取HarmonyOS应用或元服务报表的指标数据」文档。
// 鉴权：Service Account 方式（官方称将替代 API 客户端），复用 backend/agc-service-account.json
//   与 huaweiPush.ts 同款 PS256 JWT 签名流程，凭据不落命令行、不打印。
// 用法：node backend/scripts/agc-active-devices.mjs [起始日] [结束日]   默认最近 30 天
//   环境变量：AGC_APP_ID（默认 6917613566723435312）、AGC_CRED_PATH
// 口径提醒：AGC 报表口径与「鸿蒙激励计划2026」后台的有效月活**统计方式/周期/维度都不同**
//   （官方 FAQ 明示）。本脚本给的是趋势与量级参照，达标判定仍以激励计划后台为准。
import { readFileSync } from 'node:fs';
import { sign, constants as C } from 'node:crypto';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const CRED = process.env.AGC_CRED_PATH || resolve(HERE, '../backend/agc-service-account.json');
const APP_ID = process.env.AGC_APP_ID || '6917613566723435312';
const TOKEN_AUD = 'urn:ietf:params:oauth:grant-type:jwt-bearer';

function b64url(s) {
  return Buffer.from(s, 'utf8').toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function day(n) {
  const d = new Date(Date.now() - n * 86400000);
  return d.toISOString().slice(0, 10);
}

const startArg = process.argv[2] || day(30);
const endArg = process.argv[3] || day(1);
// 上周期（chain*）：与本期等长，用于环比
const spanDays = Math.max(1, Math.round((new Date(endArg) - new Date(startArg)) / 86400000) + 1);
const chainStart = day(30 + spanDays * 2);
const chainEnd = day(30 + spanDays);

const cred = JSON.parse(readFileSync(CRED, 'utf8'));
const now = Math.floor(Date.now() / 1000);
const header = b64url(JSON.stringify({ kid: cred.key_id, typ: 'JWT', alg: 'PS256' }));
const payload = b64url(JSON.stringify({ aud: cred.token_uri, iss: cred.sub_account, exp: now + 3600, iat: now }));
const signature = b64urlRaw(sign('sha256', `${header}.${payload}`, {
  key: cred.private_key,
  padding: C.RSA_PKCS1_PSS_PADDING,
  saltLength: C.RSA_PSS_SALTLEN_DIGEST,
}));

function b64urlRaw(buf) {
  return buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function main() {
  const assertion = `${header}.${payload}.${signature}`;
  let accessToken = '';
  let clientIdForHeader = '';
  let lastErr = '';

  // 路径 A（官方 Reports API 样例，实测最省事）：API 客户端方式
  //   在 AGC「项目设置 → API 管理 / 服务端API」创建 API 客户端，角色需含分析/报表读取，
  //   然后把生成的 ID 与密钥放进环境变量：AGC_CLIENT_ID / AGC_CLIENT_SECRET
  const cid = process.env.AGC_CLIENT_ID || '';
  const csecret = process.env.AGC_CLIENT_SECRET || '';
  if (cid !== '' && csecret !== '') {
    const tokenUrl = process.env.AGC_TOKEN_URL || 'https://connect-api.cloud.huawei.com/api/oauth2/v1/token';
    const r = await fetch(tokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ client_id: cid, client_secret: csecret, grant_type: 'client_credentials' }),
    });
    const j = await r.json().catch(() => ({}));
    if (j.access_token) {
      accessToken = j.access_token;
      clientIdForHeader = cid;
      console.log('[agc] token OK via API 客户端 (client_credentials)');
    } else {
      lastErr = `API 客户端 → HTTP ${r.status} ${JSON.stringify(j)}`;
      console.log('[agc] 失败：', lastErr);
    }
  }

  // 路径 B：Service Account JWT（当前仓库凭据是推送用的 oauth-login 端点，
  // 实测 connect-api 拒绝该断言；保留尝试，错误原样打印）
  if (accessToken === '') {
    const tokenUrls = [
      process.env.AGC_TOKEN_URL || 'https://connect-api.cloud.huawei.com/api/oauth2/v1/token',
      cred.token_uri,
    ];
    const attempts = [];
    for (const url of tokenUrls) {
      attempts.push({ url, enc: 'json', body: JSON.stringify({ grant_type: TOKEN_AUD, assertion }), ct: 'application/json' });
      attempts.push({ url, enc: 'form', body: new URLSearchParams({ grant_type: TOKEN_AUD, assertion }), ct: 'application/x-www-form-urlencoded' });
    }
    for (const a of attempts) {
      const tokenResp = await fetch(a.url, { method: 'POST', headers: { 'Content-Type': a.ct }, body: a.body });
      const tokenJson = await tokenResp.json().catch(() => ({}));
      if (tokenJson.access_token) { accessToken = tokenJson.access_token; console.log('[agc] token OK via', a.url.replace(/^https:\/\//, ''), a.enc); break; }
      lastErr = `${a.url.replace(/^https:\/\//, '')} ${a.enc} → HTTP ${tokenResp.status} ${JSON.stringify(tokenJson)}`;
      console.log('[agc] 失败：', lastErr);
    }
  }

  if (accessToken === '') {
    console.error('[agc] 取 token 全部失败，最后一条：', lastErr);
    console.error('[agc] 下一步（一次性）：AGC「项目设置 → API 管理」创建 API 客户端（角色含分析/报表读取），');
    console.error('      然后 AGC_CLIENT_ID=xxx AGC_CLIENT_SECRET=yyy node scripts/agc-active-devices.mjs');
    process.exit(2);
  }
  clientIdForHeader = clientIdForHeader || String(cred.project_id);
  const reportUrl = `https://connect-api.cloud.huawei.com/api/report/harmony-report/v1/harmony/analyticsReport/${APP_ID}`;
  const body = {
    measures: ['activeDevice', 'newDevice', 'sumDevice', 'installedDeviceCnt'],
    startTime: `${startArg}T00:00:00`,
    endTime: `${endArg}T23:59:59`,
    frequency: 'day',
    chainStartTime: `${chainStart}T00:00:00`,
    chainEndTime: `${chainEnd}T23:59:59`,
    order: 'day',
  };
  const resp = await fetch(reportUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${accessToken}`,
      client_id: clientIdForHeader,
    },
    body: JSON.stringify(body),
  });
  const text = await resp.text();
  if (!resp.ok) {
    console.error('[agc] 报表接口失败 HTTP', resp.status, text.slice(0, 600));
    console.error('[agc] 请求体：', JSON.stringify(body));
    process.exit(3);
  }
  let data;
  try { data = JSON.parse(text); } catch { console.log(text.slice(0, 2000)); return; }
  console.log(`AGC 官方报表 · appId=${APP_ID} · ${startArg} ~ ${endArg}`);
  console.log(JSON.stringify(data, null, 2).slice(0, 4000));
}

main().catch((e) => { console.error('[agc] 异常：', String((e && e.message) || e)); process.exit(1); });
