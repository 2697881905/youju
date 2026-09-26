/* 有据文字海报 v2 · 设计样张生成器（1080×1440 × 4 款）
 *
 * 设计宪法（C1–C7）：
 *  C1 字号最多 3 级：主视觉 / 小标签 / 落款
 *  C2 层级不倒挂：相邻两级差 ≥ 1.25 倍
 *  C3 负空间守卫：文字不越过画布 15% 边距（1080×15%=162 / 1440×15%=216）
 *  C4 配色克制度：≤ 3 色（底 / 墨 / 强调），强调色面积 < 3%
 *  C5 零/非物质：每款只允许 1 个材质记忆点，禁渐变、禁纹理、禁模糊阴影、禁旋转
 *  C6 缩略图守则：主视觉 ≥ 72px（信息流缩到 330px 宽后 ≥ 22px 可读）
 *  C7 细节不承重：抹掉所有细线/微标签后，块面关系与层级仍成立
 *
 * 运行：
 *   NODE_PATH=/Users/itxiaobai/.workbuddy/binaries/node/workspace/node_modules \
 *   /Users/itxiaobai/.workbuddy/binaries/node/versions/22.22.2/bin/node gen.js
 */
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const W = 1080, H = 1440;
const SAFE_X = Math.round(W * 0.15);   // 162
const SAFE_Y = Math.round(H * 0.15);   // 216

// 只用 2 个字族：宋体排正文/金句，无衬线排落款与微型标签
const SERIF = 'Songti SC, Noto Serif SC, serif';
const SANS = 'PingFang SC, Noto Sans SC, "Helvetica Neue", sans-serif';

const BRAND = '有据';
const FOOT_SIZE = 26;
const FOOT_OPACITY = 0.55;
const FOOT_BASELINE = H - SAFE_Y;      // 1224，恰好压在 15% 边距线上
const LABEL_SIZE = 34;                 // 小标签：34 / 26 = 1.31 ≥ 1.25（C2）

// ───────────────────────── 4 款样式规格 ─────────────────────────
// box = 正文区（绝对坐标），全部在 15% 边距之内（C3）
const STYLES = [
  {
    key: 'paper', label: '素纸', note: '书页 · 零装饰，纯靠留白与层级',
    bg: '#EFE9DC', ink: '#241D12', accent: '#241D12',
    box: { l: 200, r: 880, t: 300, b: 1120 },
    foot: { opacity: 0.55 },
  },
  {
    key: 'film', label: '胶片', note: '片尾字幕卡 · 唯一高对比深色锚点',
    bg: '#111214', ink: '#F2EDE3', accent: '#C8A96A',
    box: { l: 200, r: 896, t: 320, b: 1140 },
    foot: { opacity: 0.5 },
  },
  {
    key: 'kraft', label: '牛皮纸', note: '信纸 · 纸感由底色承载，不画纤维',
    bg: '#C7A379', ink: '#2A1C0C', accent: '#5A3C1C',
    box: { l: 184, r: 896, t: 316, b: 1120 },
    foot: { opacity: 0.55 },
  },
  {
    key: 'sticky', label: '便利贴', note: '现代笔记 callout · 去拟物化',
    bg: '#F2E2A8', ink: '#2A2410', accent: '#C9A94E',
    box: { l: 216, r: 896, t: 316, b: 1108 },
    foot: { opacity: 0.55 },
  },
];

// ───────────────────────── 字号阶梯 ─────────────────────────
// hero 全部 ≥ 72（C6）。capacity 为该档在 box 内能容纳的全角字数上限。
const TIERS = [
  { hero: 140, lh: 1.34, align: 'center' },
  { hero: 120, lh: 1.38, align: 'center' },
  { hero: 104, lh: 1.46, align: 'center' },
  { hero: 88, lh: 1.50, align: 'left' },
  { hero: 76, lh: 1.52, align: 'left' },
  // 唯一低于 C6 的一档：用于「能多装字」与「缩略图可读」之间的取舍演示
  { hero: 64, lh: 1.56, align: 'left', belowC6: true },
];

// ───────────────────────── 文本度量（中文字形近似） ─────────────────────────
// 宋体的 CJK 字形近似 1 em 宽；ASCII 与半角标点约 0.52 em。用于折行预算。
function charWidth(ch, size) {
  const code = ch.codePointAt(0);
  return code < 0x2E80 ? size * 0.52 : size;
}
function measure(s, size) {
  let w = 0;
  for (const ch of s) w += charWidth(ch, size);
  return w;
}
function textLength(s) {
  let n = 0;
  for (const _ of s) n += 1;
  return n;
}

// ───────────────────────── 中文避头尾折行 ─────────────────────────
// 禁行首（标点不能落在一行之首）
const NO_LINE_START = '，。、；：？！）》」』】》〉…·%,.;:?!)]}”’';
// 禁行尾（前引类标点不能落在一行之末）
const NO_LINE_END = '（《「『【〈([{“‘';
// 优选断点：在这些标点**之后**收行，让断句落在自然短语处
const BREAK_AFTER = '，。；：！？、,.!?;:';

/**
 * 折行。返回 [{ text, paraEnd }]
 * @param {string} content 原文
 * @param {number} size 字号
 * @param {number} maxWidth 可用宽度
 * @param {number} maxLines 行数上限
 */
function wrapText(content, size, maxWidth, maxLines) {
  const normalized = content.replace(/\r/g, '').trim();
  const paragraphs = normalized.length > 0 ? normalized.split('\n') : [''];
  const out = [];
  let truncated = false;

  for (let p = 0; p < paragraphs.length; p++) {
    const para = paragraphs[p];
    if (para.length === 0) {
      // 空段落保留为「空行」，靠 paraEnd 触发段间距（不丢弃）
      out.push({ text: '', paraEnd: true });
      continue;
    }
    let line = '';
    let lineWidth = 0;
    for (let i = 0; i < para.length; i++) {
      const ch = para[i];
      if (line.length === 0 && NO_LINE_START.indexOf(ch) >= 0 && out.length > 0
        && !out[out.length - 1].paraEnd) {
        // 标点落在行首 → 把上一行最后一个字一起「追出」到本行（标准追い出し），
        // 不用「把标点吸进上一行」的写法 —— 那会让该行超出 maxWidth 并顶破安全边距。
        const prev = out[out.length - 1];
        if (prev.text.length > 1) {
          const moved = prev.text.slice(-1);
          prev.text = prev.text.slice(0, -1);
          line = moved + ch;
        } else {
          line = ch; // 上一行只剩一个字：只能让标点起行，避免整行被推空
        }
        lineWidth = measure(line, size);
        continue;
      }
      const w = charWidth(ch, size);
      if (line.length > 0 && lineWidth + w > maxWidth) {
        // 禁则：本行末尾是前引类标点 → 把它推到下一行
        const lastCh = line[line.length - 1];
        if (NO_LINE_END.indexOf(lastCh) >= 0) {
          const moved = line.slice(-1);
          line = line.slice(0, -1);
          out.push({ text: line, paraEnd: false });
          line = moved + ch;
          lineWidth = measure(line, size);
        } else if (NO_LINE_START.indexOf(ch) >= 0) {
          // 标点不能起行：把本行最后一个字与标点一起追出到下一行，保证不超出 maxWidth
          const moved = line.slice(-1);
          const kept = line.slice(0, -1);
          if (kept.length > 0) out.push({ text: kept, paraEnd: false });
          line = moved + ch;
          lineWidth = measure(line, size);
        } else {
          out.push({ text: line, paraEnd: false });
          line = ch;
          lineWidth = w;
        }
      } else {
        line += ch;
        lineWidth += w;
      }
      // 自然短语断行：已用掉 72% 以上宽度且当前字符是断点标点 → 收行
      if (line.length > 0 && BREAK_AFTER.indexOf(ch) >= 0 && lineWidth >= maxWidth * 0.72) {
        out.push({ text: line, paraEnd: false });
        line = '';
        lineWidth = 0;
      }
      // 行数上限：先判满再决定是否继续吞字（不丢当前字符）
      if (out.length >= maxLines) {
        truncated = i < para.length - 1 || line.length > 0 || p < paragraphs.length - 1;
        break;
      }
    }
    if (out.length >= maxLines) break;
    if (line.length > 0) {
      const isLastPara = p === paragraphs.length - 1;
      out.push({ text: line, paraEnd: true });
      if (!isLastPara) truncated = true;
    } else if (out.length > 0) {
      out[out.length - 1].paraEnd = true;
    }
  }

  // 收敛：去掉尾部空行
  while (out.length > 0 && out[out.length - 1].text === '') out.pop();
  if (out.length === 0) out.push({ text: '', paraEnd: true });
  out[out.length - 1].paraEnd = true;
  return { lines: out, truncated };
}

/** 依「能装下最少档位」自适配字号档。装不下则用最小档 + 省略号。
 *  opts.strictC6 = true 时不使用低于 C6（72px）的档位，宁可截断。 */
function fitTier(content, box, opts) {
  const o = opts || {};
  const boxW = box.r - box.l;
  const boxH = box.b - box.t;
  const n = textLength(content);
  const usable = o.strictC6 ? TIERS.filter((t) => !t.belowC6) : TIERS;
  for (const tier of usable) {
    const lineH = tier.hero * tier.lh;
    const perLine = Math.max(1, Math.floor(boxW / tier.hero));
    const maxLines = Math.max(1, Math.floor(boxH / lineH));
    if (n <= perLine * maxLines) {
      return { tier, perLine, maxLines };
    }
  }
  const tier = usable[usable.length - 1];
  const lineH = tier.hero * tier.lh;
  return {
    tier,
    perLine: Math.max(1, Math.floor(boxW / tier.hero)),
    maxLines: Math.max(1, Math.floor(boxH / lineH)),
  };
}

// ───────────────────────── SVG 原子 ─────────────────────────
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function text(x, y, s, size, opts) {
  const o = opts || {};
  // font-family 内含双引号（如 "Helvetica Neue"）必须转义，否则 SVG 属性会截断 → XML 报错
  const fam = (o.fam || SERIF).replace(/"/g, '&quot;');
  const anchor = o.anchor || 'start';
  const attrs = [
    `x="${x}"`, `y="${y}"`,
    `font-family="${fam}"`, `font-size="${size}"`,
    `font-weight="${o.fw || 400}"`, `fill="${o.fill}"`,
    `text-anchor="${anchor}"`,
  ];
  if (o.opacity !== undefined) attrs.push(`fill-opacity="${o.opacity}"`);
  if (o.ls !== undefined) attrs.push(`letter-spacing="${o.ls}"`);
  return `<text ${attrs.join(' ')}>${esc(s)}</text>`;
}

function rect(x, y, w, h, fill, opts) {
  const o = opts || {};
  const attrs = [`x="${x}"`, `y="${y}"`, `width="${w}"`, `height="${h}"`, `fill="${fill}"`];
  if (o.rx) attrs.push(`rx="${o.rx}"`);
  if (o.opacity !== undefined) attrs.push(`fill-opacity="${o.opacity}"`);
  return `<rect ${attrs.join(' ')}/>`;
}

function line(x1, y1, x2, y2, stroke, w, opacity) {
  const attrs = [
    `x1="${x1}"`, `y1="${y1}"`, `x2="${x2}"`, `y2="${y2}"`,
    `stroke="${stroke}"`, `stroke-width="${w}"`, `shape-rendering="crispEdges"`,
  ];
  if (opacity !== undefined) attrs.push(`stroke-opacity="${opacity}"`);
  return `<line ${attrs.join(' ')}/>`;
}

// ───────────────────────── 每款的唯一记忆点（C5） ─────────────────────────
function detail(style, box, opts) {
  const o = opts || {};
  if (o.hideDetail) return ''; // C7 验收：抹掉细节后画面是否仍成立
  const { l, r, t, b } = box;
  switch (style.key) {
    case 'paper':
      // 记忆点：页脚一条极细双线
      return [
        line(l, 1176, r, 1176, style.ink, 1, 0.22),
        line(l, 1186, r, 1186, style.ink, 0.5, 0.12),
      ].join('');
    case 'film':
      // 记忆点：左侧一条 1px 暖金竖线（片头/片尾字幕卡语言）
      // 刻意不加「FILM · NO.01」这类片号微标签：写死的假编号，缩到 330px 只剩约 8px 纯糊
      return line(l - 24, t, l - 24, b, style.accent, 1, 0.7);
    case 'kraft':
      // 记忆点：正文区上下各一条 1px 实线（信纸抬头 / 落款线）。留出与标签的呼吸间距
      return [
        line(l, t - 56, r, t - 56, style.accent, 1, 0.38),
        line(l, b + 56, r, b + 56, style.accent, 1, 0.38),
      ].join('');
    case 'sticky':
      // 记忆点：一条 4px 左侧强调竖条
      return rect(l - 24, t, 4, b - t, style.accent);
    default:
      return '';
  }
}

// ───────────────────────── 单张海报 ─────────────────────────
/**
 * @param {object} style 样式规格
 * @param {object} post  { title, content }
 * @param {object} opts  { hideDetail, showTitle, quoteGlyph, labelOverride }
 */
function renderPoster(style, post, opts) {
  const o = opts || {};
  const { l, r, t, b } = style.box;
  const boxW = r - l;
  const boxH = b - t;

  const content = (post.content || '').trim() || '写下你的观点，让更多人看见。';
  const title = (post.title || '').trim();
  const { tier, maxLines } = fitTier(content, style.box, o);
  const lineH = tier.hero * tier.lh;
  const wrapped = wrapText(content, tier.hero, boxW, maxLines);
  let lines = wrapped.lines;
  if (wrapped.truncated && lines.length > 0) {
    let last = lines[lines.length - 1].text;
    while (last.length > 1 && measure(last + '…', tier.hero) > boxW) {
      last = last.slice(0, -1);
    }
    lines[lines.length - 1] = { text: last + '…', paraEnd: true };
  }

  const paraGap = lineH * 0.6;
  let blockH = 0;
  for (const ln of lines) blockH += lineH + (ln.paraEnd ? paraGap : 0);
  blockH -= paraGap;

  // 小标签：显式传 labelText 优先（空串=不画）；否则居中短句档用 title。
  // 长文档不画 title，避免出现第 4 级字号（C1）。
  const labelText = o.labelText !== undefined
    ? o.labelText
    : (o.showTitle !== false && title.length > 0 && tier.align === 'center' ? title : '');
  const drawLabel = labelText.length > 0;

  const blockAreaTop = t + (drawLabel ? LABEL_SIZE + 34 : 0);
  const blockAreaH = b - blockAreaTop;
  const blockTop = blockAreaTop + Math.max(0, (blockAreaH - blockH) / 2);
  const firstBaseline = blockTop + tier.hero * 0.86;
  const labelBaseline = t + 4;

  const parts = [];
  parts.push(rect(0, 0, W, H, style.bg));                       // solid 底，无渐变（C5）

  if (drawLabel) {
    parts.push(text(l + boxW / 2, labelBaseline, labelText, LABEL_SIZE, {
      fam: SANS, fill: style.ink, opacity: 0.5, anchor: 'middle',
    }));
  }

  // 引号：仅在显式要求时（默认不画 —— 巨型引号是旧版「不高级」的头号病根）
  if (o.quoteGlyph && lines.length > 0) {
    parts.push(text(l, firstBaseline - lineH * 0.82, '“', Math.min(120, tier.hero), {
      fw: 700, fill: style.ink, opacity: 0.2,
    }));
  }

  const insetTop = drawLabel ? LABEL_SIZE + 34 : 0;
  void insetTop;
  let y = firstBaseline;
  for (const ln of lines) {
    if (ln.text.length > 0) {
      if (tier.align === 'center') {
        parts.push(text(l + boxW / 2, y, ln.text, tier.hero, {
          anchor: 'middle', fill: style.ink, fw: 400,
        }));
      } else {
        parts.push(text(l, y, ln.text, tier.hero, { fill: style.ink, fw: 400 }));
      }
    }
    y += lineH + (ln.paraEnd ? paraGap : 0);
  }

  parts.push(detail(style, style.box, o));

  // 落款：页脚右下角，只有「有据」两字（唯一品牌锚点，固定位置固定尺寸）
  if (!o.hideDetail) {
    parts.push(text(r, FOOT_BASELINE, BRAND, FOOT_SIZE, {
      fam: SANS, fill: style.ink, opacity: style.foot.opacity, anchor: 'end', fw: 400,
    }));
  }

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`
    + `<rect width="${W}" height="${H}" fill="${style.bg}"/>`
    + parts.join('')
    + '</svg>';
}

// ───────────────────────── 样例文案 ─────────────────────────
const SAMPLES = {
  short: {
    title: '装修避坑',
    content: '插座位置要在水电阶段一次量准，比挑瓷砖重要十倍。',
  },
  long: {
    title: '装修避坑',
    content: '第一次装修最大的教训是：灯光方案必须在水电改造前定下来。'
      + '等吊顶封好再想加射灯，只能在石膏板上开槽，多花两千块，还留下一条补不平的缝。',
  },
};

// ───────────────────────── 输出 ─────────────────────────
const OUT = path.join(__dirname, 'export');

async function toPng(svg, filename, gray) {
  let img = sharp(Buffer.from(svg), { density: 72 });
  if (gray) img = img.grayscale();
  await img.png().toFile(path.join(OUT, filename));
  return path.join(OUT, filename);
}

function svgOf(style, sample, opts) {
  return renderPoster(style, sample, opts);
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const produced = [];

  for (const style of STYLES) {
    // 短句版（含小标签）
    produced.push(await toPng(svgOf(style, SAMPLES.short), `${style.label}-短句.png`));
    // 长文版：默认「严守 C6」（主视觉 ≥72px，超出部分截断加 …），与 ④ 里的不守版本对比
    produced.push(await toPng(svgOf(style, SAMPLES.long, { strictC6: true }), `${style.label}-长文.png`));
  }

  // 便利贴备选色：Apple 便签 6 色体系的低饱和版，供 Q4 拍板
  const STICKY_ALT = [
    { key: 'pink', label: '粉', bg: '#EBD9D6', ink: '#2A2118', accent: '#C08F88' },
    { key: 'blue', label: '蓝', bg: '#D6E2EA', ink: '#1F262B', accent: '#7E9DAF' },
    { key: 'green', label: '绿', bg: '#D8E4D4', ink: '#222616', accent: '#8AA37E' },
    { key: 'gray', label: '灰', bg: '#E2DED4', ink: '#2A2620', accent: '#A79E8C' },
  ];
  for (const alt of STICKY_ALT) {
    const s = Object.assign({}, STYLES[3], { bg: alt.bg, ink: alt.ink, accent: alt.accent });
    produced.push(await toPng(svgOf(s, SAMPLES.short), `便利贴备选-${alt.label}.png`));
  }

  // 素纸：标题处理的 3 个变体，供拍板
  const paper = STYLES[0];
  produced.push(await toPng(svgOf(paper, SAMPLES.short, { labelText: '' }),
    '素纸-短句B-无小标签.png'));
  produced.push(await toPng(svgOf(paper, SAMPLES.short, { quoteGlyph: true }),
    '素纸-短句C-带引号.png'));
  produced.push(await toPng(svgOf(paper, SAMPLES.long, { strictC6: true, labelText: SAMPLES.long.title }),
    '素纸-长文B-保留标题.png'));
  // 与上面默认的「守 C6」对比：不守限制，用 64px 把全文排满
  produced.push(await toPng(svgOf(paper, SAMPLES.long), '素纸-长文C-不守C6排满.png'));

  // ── 缩略图仲裁图 ──
  // 4 列 × 3 行：短句 / 长文 / 抹掉细节后的灰阶长文。底色用信息流卡片底 #FFFCF3，
  // 用来验证「白纸海报在暖白卡片上是否会失去边界」。
  const THUMB_W = 330;
  const THUMB_H = Math.round(THUMB_W * H / W); // 440
  const GAP = 24;
  const PAD = 32;
  const ROLL_W = PAD * 2 + THUMB_W * 4 + GAP * 3;
  const ROLL_H = PAD * 2 + THUMB_H * 3 + GAP * 2;

  const thumbs = [];
  for (let i = 0; i < STYLES.length; i++) {
    thumbs.push({ row: 0, col: i, svg: svgOf(STYLES[i], SAMPLES.short) });
    thumbs.push({ row: 1, col: i, svg: svgOf(STYLES[i], SAMPLES.long, { strictC6: true }) });
    thumbs.push({
      row: 2, col: i, gray: true,
      svg: svgOf(STYLES[i], SAMPLES.long, { strictC6: true, hideDetail: true }),
    });
  }
  const composites = [];
  for (const th of thumbs) {
    const buf = await (th.gray
      ? sharp(Buffer.from(th.svg), { density: 72 }).grayscale().resize(THUMB_W, THUMB_H).png().toBuffer()
      : sharp(Buffer.from(th.svg), { density: 72 }).resize(THUMB_W, THUMB_H).png().toBuffer());
    composites.push({
      input: buf,
      left: PAD + th.col * (THUMB_W + GAP),
      top: PAD + th.row * (THUMB_H + GAP),
    });
  }
  await sharp({
    create: { width: ROLL_W, height: ROLL_H, channels: 4, background: { r: 255, g: 252, b: 243, alpha: 1 } },
  }).composite(composites).png().toFile(path.join(OUT, '缩略图仲裁.png'));
  produced.push(path.join(OUT, '缩略图仲裁.png'));

  // 同时导出 SVG 便于微调。注意必须与上面 PNG 用**同一套选项**，
  // 否则 SVG 会停留在「不守 C6」的旧排版上，与 PNG 对不上（曾踩过）。
  for (const style of STYLES) {
    fs.writeFileSync(path.join(OUT, `${style.label}-短句.svg`), svgOf(style, SAMPLES.short));
    fs.writeFileSync(path.join(OUT, `${style.label}-长文.svg`), svgOf(style, SAMPLES.long, { strictC6: true }));
  }

  console.log('生成完成：');
  for (const p of produced) console.log('  ' + path.basename(p));
}

main().catch((e) => { console.error(e); process.exit(1); });
