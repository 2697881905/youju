/**
 * 每日一贴原型 · 交互冒烟测试
 *
 * 目的：用真实 Chromium 验证「自由拖动丢出」这条链路没有断。
 * 两条历史事故（都会表现为“浏览器里拖不动”）：
 *  1. 写变换循环取第 4 个 DOM 槽时 children[3] 为 undefined → 第一帧抛错 →
 *     rAF 链断裂 → 入场动画与手势判定全部失效；骨架只给 3 个槽是根因。
 *  2. pointerdown 落在 <img> 上，左键拖动触发 Chrome 原生图片拖拽 →
 *     浏览器发 pointercancel 接管手势 → 页面收不到 pointermove。
 * 因此核心断言是：全程零 pageerror，拖动产生双向位移，且三方向都能丢出。
 *
 * 运行：
 *   node design/daily-deck-prototype/smoke-test.mjs
 * 依赖：本机 Google Chrome + 受管工作区里的 puppeteer-core（不下载 Chromium）
 */
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const WORKSPACE = process.env.WB_NODE_WORKSPACE
  || '/Users/itxiaobai/.workbuddy/binaries/node/workspace';
const puppeteer = createRequire(path.join(WORKSPACE, 'package.json'))('puppeteer-core');
const DIR = path.dirname(fileURLToPath(import.meta.url));
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
// 截图写到系统临时目录，不进仓库（产物可随时重跑生成）
const SHOT_DIR = path.join(os.tmpdir(), 'youju-deck-smoke');
fs.mkdirSync(SHOT_DIR, { recursive: true });
const shot = (name) => path.join(SHOT_DIR, name);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const server = http.createServer((req, res) => {
  const rel = req.url === '/' ? 'index.html' : req.url.split('?')[0];
  if (rel === '/favicon.ico') { res.writeHead(204); res.end(); return; }  // 免得 404 干扰断言
  fs.readFile(path.join(DIR, rel), (err, buf) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(buf);
  });
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const url = `http://127.0.0.1:${server.address().port}/index.html`;

const browser = await puppeteer.launch({ executablePath: CHROME, headless: true, args: ['--no-sandbox'] });
const page = await browser.newPage();
await page.setViewport({ width: 430, height: 932, deviceScaleFactor: 2 });

const errors = [];
page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
page.on('console', (m) => {
  const t = m.text();
  if (m.type() === 'error' && !t.includes('favicon')) errors.push(`console.error: ${t}`);
});

// 顶卡 = 内联 zIndex 最大的一张（role 0 → 23；飞行的旧顶卡为 30，但其 DOM 会轮换成 role 3 → 20）。
// 注意不能按 children[0] 取：翻页会轮换 role→DOM 映射。
const readState = () => page.evaluate(() => {
  const deck = document.getElementById('deck');
  const top = Array.from(deck.children).reduce((a, b) =>
    (Number(b.style.zIndex) > Number(a.style.zIndex) ? b : a));
  const r = top.getBoundingClientRect();
  return {
    slots: deck.children.length,
    transform: top.style.transform,
    center: { x: r.x + r.width / 2, y: r.y + r.height / 2 },
    page: document.getElementById('pagCur').textContent.trim(),
    completionShown: document.getElementById('completion').classList.contains('show'),
  };
});

const parseXY = (t) => {
  const m = /translate3d\(\s*(-?[\d.]+)px,\s*(-?[\d.]+)px/.exec(t || '');
  return m ? { x: Number(m[1]), y: Number(m[2]) } : null;
};

async function drag(from, dx, dy, { steps = 10, stepMs = 16 } = {}) {
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  for (let i = 1; i <= steps; i++) {
    await page.mouse.move(from.x + (dx * i) / steps, from.y + (dy * i) / steps);
    await sleep(stepMs);
  }
}

const at = (o, key) => `${key}: ${o.transform} page=${o.page}`;

try {
  await page.goto(url, { waitUntil: 'load' });
  await sleep(1700);                        // 报头 + 入场仪式 + 数据桩

  const init = await readState();
  console.log('[init]', at(init, 'top'));
  if (init.completionShown) throw new Error('页面直接进入完成态（localStorage 残留），测试无效');
  if (init.slots !== 4) throw new Error(`卡槽数应为 4，实际 ${init.slots}`);

  // —— 用例 1：慢速小幅拖动 → 双向跟手，离手回弹归位，不翻页 ——
  // 45/28px 约合椭圆阈值的 46%，且 100px/s 的慢速投影很小，不该丢出
  await drag(init.center, 45, 28, { steps: 20, stepMs: 20 });
  const mid = await readState();
  const midXY = parseXY(mid.transform);
  console.log('[drag mid]', at(mid, 'top'));
  if (!midXY) throw new Error('拖动中顶卡没有 translate3d 变换：' + mid.transform);
  if (midXY.x < 20 || midXY.y < 10) {
    throw new Error(`跟手失败：两个方向都应有位移，实际 x=${midXY.x} y=${midXY.y}`);
  }
  await page.mouse.up();
  await sleep(900);
  const back = await readState();
  const backXY = parseXY(back.transform);
  console.log('[after release]', at(back, 'top'));
  if (backXY && (Math.abs(backXY.x) > 4 || Math.abs(backXY.y) > 4)) {
    throw new Error(`未过阈值应回弹归零，实际停在 x=${backXY.x} y=${backXY.y}`);
  }
  if (back.page !== init.page) throw new Error(`未过阈值却翻页了：${init.page} → ${back.page}`);

  // —— 用例 2：快速小幅「抖动」→ 位移低于拖动意图门槛，速度不得被放大成一次丢出 ——
  // 16/10px 远低于 18% 卡宽门槛，但 4 步 6ms 的松手速度很高；这正是之前“太容易丢出去”的场景
  await drag(init.center, 16, 10, { steps: 4, stepMs: 6 });
  await page.mouse.up();
  await sleep(900);
  const twitch = await readState();
  console.log('[after fast twitch]', at(twitch, 'top'));
  if (twitch.page !== init.page) {
    throw new Error(`快速抖动不该丢出，却翻页到 ${twitch.page}（惯性投影缺少位移门槛）`);
  }

  // —— 用例 3：右上斜向快速甩出 → 翻页 ——
  const c2 = (await readState()).center;
  await drag(c2, 130, -160, { steps: 5, stepMs: 10 });
  await page.mouse.up();
  await sleep(900);
  const diag = await readState();
  console.log('[after diagonal fling]', at(diag, 'top'));
  if (diag.page === init.page) throw new Error(`斜向甩出未翻页，仍在 ${diag.page}`);
  await page.screenshot({ path: shot('3-after-diagonal.png') });

  // —— 用例 4：竖直向下甩出 → 翻页（自由拖动的核心诉求，原实现不可能做到）——
  const c3 = (await readState()).center;
  await drag(c3, 4, 175, { steps: 5, stepMs: 10 });
  await page.mouse.up();
  await sleep(900);
  const down = await readState();
  console.log('[after downward fling]', at(down, 'top'));
  if (down.page === diag.page) throw new Error(`竖直向下甩出未翻页，仍在 ${down.page}`);

  // —— 用例 5：竖直向上甩出 → 翻页 ——
  const c4 = (await readState()).center;
  await drag(c4, -4, -175, { steps: 5, stepMs: 10 });
  await page.mouse.up();
  await sleep(900);
  const up = await readState();
  console.log('[after upward fling]', at(up, 'top'));
  if (up.page === down.page) throw new Error(`竖直向上甩出未翻页，仍在 ${up.page}`);
  await page.screenshot({ path: shot('5-after-upward.png') });

  if (errors.length) throw new Error('运行期有报错：\n' + errors.join('\n'));
  console.log('\n✅ 全部通过：零 pageerror；跟手、回弹、抖动不误丢、右斜/下/上三方向丢出均正常');
  console.log('   截图：' + SHOT_DIR);
} catch (err) {
  console.error('\n❌ 测试失败：', err.message);
  if (errors.length) console.error('捕获到的报错：\n' + errors.join('\n'));
  try { await page.screenshot({ path: shot('failure.png') }); } catch {}
  process.exitCode = 1;
} finally {
  await browser.close();
  server.close();
}
