#!/usr/bin/env node
/**
 * 文字海报排版回归（无编译器环境下的可执行验证）。
 *
 * 沙箱里跑不了 hvigor，所以把 posterText.ets 里的纯函数「折行算法」抠出来，
 * 用 Node 22 的类型剥离能力直接跑真实代码做断言 —— 测的是产品代码本身，
 * 不是另写一份测试用的复刻实现。
 *
 * 运行：
 *   node --experimental-strip-types scripts/verify-poster-layout.mjs
 *
 * 覆盖：
 *   1) 折行不越界（4 类文本 × 5 档字号 × 3 种文字区宽 × 4 种行数上限 = 480 组）
 *   2) 行首不出禁则标点（避头尾追い出し）
 *   3) 行尾不出前引号
 *   4) 截断时末行必带省略号，且不会退化成「只有一个省略号」
 *   5) 段尾标记数量与段结构一致（多段 / 空行保留）
 *   6) 各款文字区容量、15% 安全边距、层级比（C2：相邻级差 ≥ 1.25）
 *   7) 未知样式 key 回退到素纸
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const TEXT_ETS = path.join(ROOT, 'entry/src/main/ets/utils/poster/posterText.ets');
const TOKENS_ETS = path.join(ROOT, 'entry/src/main/ets/utils/poster/posterTokens.ets');

const ELL = '\u2026';
const SIZE_EPS = 0.01;

let fails = 0;
function check(ok, msg) {
  if (!ok) {
    fails += 1;
    console.log('  x ' + msg);
  }
}

// ── 1) 从 .ets 抠出「纯函数 + 它依赖的模块级常量」，写到临时 .ts ──
const src = fs.readFileSync(TEXT_ETS, 'utf8');
function pick(re, name) {
  const m = src.match(re);
  if (!m) {
    console.error('抽取失败（posterText.ets 结构变了？）: ' + name);
    process.exit(2);
  }
  return m[0];
}
const wrapTs = [
  'const POSTER_TIERS: number[] = [0, 0, 0, 0, 0];',
  'const POSTER_ELLIPSIS: string = "' + ELL + '";',
  pick(/export interface PosterChar \{[\s\S]*?\n\}/, 'PosterChar'),
  pick(/export interface PosterWrapResult \{[\s\S]*?\n\}/, 'PosterWrapResult'),
  pick(/export const POSTER_NO_LINE_START[^\n]*/, 'POSTER_NO_LINE_START'),
  pick(/export const POSTER_NO_LINE_END[^\n]*/, 'POSTER_NO_LINE_END'),
  pick(/export const POSTER_BREAK_AFTER[^\n]*/, 'POSTER_BREAK_AFTER'),
  pick(/const BREAK_AFTER_FILL[^\n]*/, 'BREAK_AFTER_FILL'),
  pick(/export function wrapBody\([\s\S]*?\n\}\n/, 'wrapBody'),
].join('\n\n');
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'poster-verify-'));
const wrapTsPath = path.join(tmpDir, 'posterWrap.ts');
const tokensTsPath = path.join(tmpDir, 'posterTokens.ts');
fs.writeFileSync(wrapTsPath, wrapTs);
fs.copyFileSync(TOKENS_ETS, tokensTsPath);

const wrapMod = await import(pathToFileURL(wrapTsPath).href);
// posterTokens.ets 只含类型与纯函数，可整文件直接跑
const T = await import(pathToFileURL(tokensTsPath).href);

// ── 2) 用「CJK = 1 em、ASCII = 0.52 em」的宽度模型喂给它 ──
function charW(ch, size) {
  return ch.codePointAt(0) >= 0x2e80 ? size : size * 0.52;
}
function toChars(text, size) {
  const out = [];
  for (const ch of text) {
    out.push({ ch: ch, width: ch === '\n' ? 0 : charW(ch, size) });
  }
  return out;
}

console.log('=== 折行算法断言 ===');
const CASES = [
  ['短句', '插座位置要在水电阶段一次量准，比挑瓷砖重要十倍。'],
  ['长文', '第一次装修最大的教训是：灯光方案必须在水电改造前定下来。等吊顶封好再想加射灯，只能在石膏板上开槽，多花两千块，还留下一条补不平的缝。'],
  ['标点密集', '先量尺寸，再定方案；不要先买材料。因为，返工很贵！'],
  ['多段', '第一段：先说结论。\n\n第二段：再说原因，原因有两点。\n第三段：最后是做法。'],
  ['纯ASCII', 'Use ImageFilter.createBlurImageFilter(26, 26, TileMode.CLAMP) to blur.'],
  ['超长', '装修'.repeat(400)],
  ['含emoji', '今天很开心🙂，装修终于收尾了🎉，感谢师傅！'],
  ['空', ''],
];
const SIZES = [140, 120, 104, 88, 76];
const WIDTHS = [680, 696, 712];
const LINE_LIMITS = [1, 2, 4, 7];
let combos = 0;

for (const c of CASES) {
  const name = c[0];
  for (const size of SIZES) {
    for (const maxWidth of WIDTHS) {
      for (const maxLines of LINE_LIMITS) {
        const r = wrapMod.wrapBody(toChars(c[1], size), maxWidth, maxLines, charW(ELL, size));
        const ctx = '[' + name + ' size=' + size + ' w=' + maxWidth + ' lines=' + maxLines + ']';
        combos += 1;

        check(r.lines.length <= maxLines, '超过 maxLines: ' + r.lines.length + ' ' + ctx);
        check(r.lines.length > 0, '零行 ' + ctx);
        check(r.lineWidths.length === r.lines.length, '行宽数组与行数不一致 ' + ctx);
        check(r.lineEndsParagraph.length === r.lines.length, '段尾数组与行数不一致 ' + ctx);

        for (let i = 0; i < r.lines.length; i++) {
          const line = r.lines[i];
          const w = r.lineWidths[i];
          if (w > maxWidth + SIZE_EPS && line.length > 1) {
            check(false, '第' + i + '行越界 w=' + w.toFixed(1) + ' > ' + maxWidth + ' : ' + JSON.stringify(line) + ' ' + ctx);
          }
          if (line.length === 0) {
            continue;
          }
          const head = line.charAt(0);
          if (i > 0 && wrapMod.POSTER_NO_LINE_START.indexOf(head) >= 0 && r.lines[i - 1].length > 1) {
            check(false, '第' + i + '行行首是禁则标点 ' + head + ' : ' + JSON.stringify(line) + ' ' + ctx);
          }
          const tail = line.charAt(line.length - 1);
          if (tail !== ELL && wrapMod.POSTER_NO_LINE_END.indexOf(tail) >= 0 && line.length > 1) {
            check(false, '第' + i + '行行尾是前引号 ' + tail + ' : ' + JSON.stringify(line) + ' ' + ctx);
          }
        }

        if (r.truncated) {
          const last = r.lines[r.lines.length - 1];
          check(last.slice(-1) === ELL, 'truncated 但末行没省略号: ' + JSON.stringify(last) + ' ' + ctx);
          check(!(last === ELL && r.lines.length > 1), '末行只剩省略号 ' + ctx);
        } else if (name !== '超长') {
          const last = r.lines[r.lines.length - 1];
          check(last.slice(-1) !== ELL, '未截断却带省略号: ' + JSON.stringify(last) + ' ' + ctx);
        }
      }
    }
  }
}
console.log('  ' + combos + ' 组组合' + (fails === 0 ? '，PASS' : '，见上方失败项'));

// 段结构：空行保留 + 每段末行有段尾标记
const multi = wrapMod.wrapBody(toChars(CASES[3][1], 104), 680, 7, charW(ELL, 104));
const paraEnds = multi.lineEndsParagraph.filter((v) => v).length;
check(paraEnds >= 3, '多段文本的段尾标记少于 3 个：' + paraEnds);
check(multi.lineEndsParagraph[multi.lineEndsParagraph.length - 1] === true, '末行必须是段尾');
check(multi.lines.some((l) => l === ''), '空段没有被保留');
console.log('  段结构：' + multi.lines.length + ' 行 / ' + paraEnds + ' 个段尾');

console.log('');
console.log('=== 设计令牌断言（C2 / C3 / 回退）===');
check(T.POSTER_TIERS.every((t) => t.hero >= 72), 'C6：存在低于 72px 的档位');
check(T.POSTER_LABEL_SIZE / T.POSTER_FOOT_SIZE >= 1.25, 'C2：小标签/落款 级差不足 1.25');
check(88 / T.POSTER_LABEL_SIZE >= 1.25, 'C2：最小主视觉/小标签 级差不足 1.25');
for (const s of T.TEXT_POSTER_STYLES) {
  check(s.boxLeft >= T.POSTER_SAFE_X && s.boxRight <= T.POSTER_WIDTH - T.POSTER_SAFE_X, s.label + ' 文字区左右越出 15% 边距');
  check(s.boxTop >= T.POSTER_SAFE_Y && s.boxBottom <= T.POSTER_HEIGHT - T.POSTER_SAFE_Y, s.label + ' 文字区上下越出 15% 边距');
  check(s.footOpacity >= 0.45, s.label + ' 落款透明度过低（对比度 < 3:1）');
}
check(T.resolveTextPosterStyle('nope').key === 'paper', '未知样式 key 未回退到素纸');
check(T.TEXT_POSTER_STYLES[0].key === 'paper', '首元素必须是默认款素纸（resolveTextPosterStyle 的回退目标）');
const caps = T.TEXT_POSTER_STYLES.map((s) => T.posterStyleCapacity(s, T.POSTER_TIERS[T.POSTER_TIERS.length - 1]));
console.log('  最小档容量（字）: ' + T.TEXT_POSTER_STYLES.map((s, i) => s.label + ' ' + caps[i]).join(' / '));
console.log('  保守判定参照款 = ' + T.POSTER_CONSERVATIVE_STYLE + '（容量 ' + T.posterStyleCapacity(T.resolveTextPosterStyle(T.POSTER_CONSERVATIVE_STYLE), T.POSTER_TIERS[T.POSTER_TIERS.length - 1]) + ' 字）');
check(Math.min(...caps) === T.posterStyleCapacity(T.resolveTextPosterStyle(T.POSTER_CONSERVATIVE_STYLE), T.POSTER_TIERS[T.POSTER_TIERS.length - 1]), 'POSTER_CONSERVATIVE_STYLE 不是容量最小的那款');

fs.rmSync(tmpDir, { recursive: true, force: true });

console.log('');
console.log(fails === 0 ? '全部通过。' : '失败 ' + fails + ' 项。');
process.exit(fails === 0 ? 0 : 1);
