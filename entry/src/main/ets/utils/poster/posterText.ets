// 文字海报 · 字体与排版（唯一排版算法：渲染与测量共用同一段代码）
//
// 为什么把折行单独写成 fetch-only 的纯函数：中文避头尾 + 自然短语断行很容易出错，
// 必须能在没有编译器的情况下用 Node 直接跑断言（见 scripts/ 之外的 /tmp 抽取测试）。
// 因此 wrapBody 只依赖 PosterChar[] 与数值，不碰 drawing 的任何 API。
import { drawing, common2D } from '@kit.ArkGraphics2D';
import {
  POSTER_ELLIPSIS, POSTER_LABEL_RESERVE, POSTER_PARA_GAP_RATIO, POSTER_TIERS,
  PosterAlign, PosterTier, TextPosterStyleOption, posterStyleCapacity, posterTextLength,
  resolveTextPosterStyle,
} from './posterTokens';

// 衬线字体 Typeface，由 Index.ets 在启动时注册
let serifTypeface: drawing.Typeface | null = null;
// 衬线正文字重（Regular）：海报正文用，避免被 Bold 字形 + 伪粗双重加粗
let serifBodyTypeface: drawing.Typeface | null = null;

export function setSerifTypeface(typeface: drawing.Typeface | null): void {
  serifTypeface = typeface;
}

export function setSerifBodyTypeface(typeface: drawing.Typeface | null): void {
  serifBodyTypeface = typeface;
}

// 供预览页判断绘制所依赖的衬线字体是否已注册（Index.ets 启动时注册）。
export function isSerifTypefaceReady(): boolean {
  return serifTypeface !== null;
}

/**
 * 字体角色 —— 全海报只用 2 个字族（金句卡最佳实践：第三个字族读起来"杂乱且业余"）：
 *  hero  宋体 Regular（金句/正文，字重差异与标题拉开层次）
 *  label 系统无衬线（小标签，用字族差把层级"变安静"，而不是只靠字号）
 *  foot  系统无衬线（落款，同 label）
 */
export type PosterFontRole = 'hero' | 'label' | 'foot';

export function createPosterFont(size: number, role: PosterFontRole): drawing.Font {
  const font: drawing.Font = new drawing.Font();
  font.setSize(size);
  // 正文与落款一律不伪粗：宋体 Regular 才有书页感，系统无衬线伪粗会糊
  font.enableEmbolden(false);
  if (role === 'hero') {
    const body: drawing.Typeface | null = serifBodyTypeface;
    if (body !== null) {
      font.setTypeface(body);
    } else if (serifTypeface !== null) {
      font.setTypeface(serifTypeface);
    }
  }
  return font;
}

export function makeColor(alpha: number, red: number, green: number, blue: number): common2D.Color {
  return { alpha: alpha, red: red, green: green, blue: blue };
}

export function drawText(canvas: drawing.Canvas, brush: drawing.Brush, font: drawing.Font, value: string, x: number, y: number, color: common2D.Color): void {
  if (value.length === 0) {
    return;
  }
  brush.setColor(color);
  canvas.attachBrush(brush);
  const blob: drawing.TextBlob = drawing.TextBlob.makeFromString(value, font, drawing.TextEncoding.TEXT_ENCODING_UTF8);
  canvas.drawTextBlob(blob, x, y);
}

/**
 * 带字距的文本绘制：drawing.Font 没有 letterSpacing API，只能逐字定位。
 * 返回实际绘制宽度（供需要精确布局的调用方使用）。
 */
export function drawSpacedText(canvas: drawing.Canvas, brush: drawing.Brush, font: drawing.Font, value: string, x: number, y: number, color: common2D.Color, tracking: number): number {
  let cursor: number = x;
  let i: number = 0;
  while (i < value.length) {
    const unit: PosterCodeUnit = readChar(value, i);
    drawText(canvas, brush, font, unit.ch, cursor, y, color);
    cursor += measureTextWidth(unit.ch, font) + tracking;
    i += unit.size;
  }
  return cursor - x;
}

// 逐「码点」读取：代理对（emoji 等）必须整体取出，否则会画出半个字形的乱码。
// 不用 String.codePointAt / fromCodePoint，避免引入额外 API 面。
interface PosterCodeUnit {
  ch: string;
  size: number;
}

function readChar(text: string, index: number): PosterCodeUnit {
  const first: number = text.charCodeAt(index);
  if (first >= 0xD800 && first <= 0xDBFF && index + 1 < text.length) {
    return { ch: text.substring(index, index + 2), size: 2 };
  }
  return { ch: text.charAt(index), size: 1 };
}

// ───────────────────────── 度量 ─────────────────────────

/**
 * 单串宽度。注意不能用 font.measureSingleCharacter —— 它是 @since 22，
 * 而本工程 compatibleSdk 是 6.0.0(20)，用了会编译不过。
 */
export function measureTextWidth(value: string, font: drawing.Font): number {
  if (value.length === 0) {
    return 0;
  }
  return font.measureText(value, drawing.TextEncoding.TEXT_ENCODING_UTF8);
}

export interface PosterChar {
  ch: string;
  width: number;
  /** ch === '\n' 表示强制换段：不绘制，只用来切段并打段尾标记 */
}

export interface PosterWrapResult {
  lines: string[];
  lineWidths: number[];
  lineEndsParagraph: boolean[];
  truncated: boolean;
}

// 禁行首：这些标点不能落在一行之首
export const POSTER_NO_LINE_START: string = '，。、；：？！）》」』】》〉…·%,.;:?!)]}”’';
// 禁行尾：前引类标点不能落在一行之末
export const POSTER_NO_LINE_END: string = '（《「『【〈([{“‘';
// 优选断点：在这些标点之后收行，让断句落在自然短语处（金句卡原则）
export const POSTER_BREAK_AFTER: string = '，。；：！？、,.!?;:';
// 自然短语断行的触发线：已用掉该比例以上行宽时，遇到断点标点就收行
const BREAK_AFTER_FILL: number = 0.72;

/**
 * 中文折行：避头尾（追い出し）+ 自然短语断行 + 空段保留 + 行数上限 + 省略号。
 *
 * @param chars     逐字宽度数组（'\n' 为强制换段哨兵，width 0）
 * @param maxWidth  可用行宽
 * @param maxLines  行数上限
 * @param ellipsisWidth '…' 的宽度；> 0 时在截断处补省略号，0 表示不补
 */
export function wrapBody(chars: PosterChar[], maxWidth: number, maxLines: number, ellipsisWidth: number): PosterWrapResult {
  const outChars: PosterChar[][] = [];
  const outPara: boolean[] = [];
  let line: PosterChar[] = [];
  let lineWidth: number = 0;
  let hitLimit: boolean = false;

  for (let i: number = 0; i < chars.length; i++) {
    const c: PosterChar = chars[i];

    if (c.ch === '\n') {
      outChars.push(line);
      outPara.push(true);
      line = [];
      lineWidth = 0;
      if (outChars.length >= maxLines) {
        hitLimit = true;
        break;
      }
      continue;
    }

    // 标点落在行首 → 把上一行末字一起「追出」到本行（标准追い出し）。
    // 不要写成「把标点吸进上一行」：那会让上一行超出 maxWidth 并顶破安全边距。
    if (line.length === 0 && POSTER_NO_LINE_START.indexOf(c.ch) >= 0
      && outChars.length > 0 && !outPara[outChars.length - 1]) {
      const prev: PosterChar[] = outChars[outChars.length - 1];
      if (prev.length > 1) {
        const moved: PosterChar = prev[prev.length - 1];
        prev.pop();
        line = [moved, c];
        lineWidth = moved.width + c.width;
      } else {
        line = [c];
        lineWidth = c.width;
      }
      continue;
    }

    if (line.length > 0 && lineWidth + c.width > maxWidth) {
      const lastCh: string = line[line.length - 1].ch;
      const needPushOut: boolean = (POSTER_NO_LINE_END.indexOf(lastCh) >= 0
        || POSTER_NO_LINE_START.indexOf(c.ch) >= 0) && line.length > 1;
      if (needPushOut) {
        const moved: PosterChar = line[line.length - 1];
        line.pop();
        outChars.push(line);
        outPara.push(false);
        line = [moved, c];
        lineWidth = moved.width + c.width;
      } else {
        outChars.push(line);
        outPara.push(false);
        line = [c];
        lineWidth = c.width;
      }
    } else {
      line.push(c);
      lineWidth += c.width;
    }

    // 自然短语断行：行宽已用掉 72% 以上，且当前字符是断点标点 → 在此收行
    if (line.length > 0 && POSTER_BREAK_AFTER.indexOf(c.ch) >= 0 && lineWidth >= maxWidth * BREAK_AFTER_FILL) {
      outChars.push(line);
      outPara.push(false);
      line = [];
      lineWidth = 0;
    }

    if (outChars.length >= maxLines) {
      hitLimit = true;
      break;
    }
  }

  // 收尾：末行未被 maxLines 截断时正常收进来
  if (line.length > 0) {
    if (outChars.length < maxLines) {
      outChars.push(line);
      outPara.push(false);
    } else {
      hitLimit = true;
    }
  }
  // 极短/空内容兜底：至少一行，避免下游除零或空数组
  if (outChars.length === 0) {
    outChars.push([]);
    outPara.push(true);
  }

  // 截断处补省略号：从末行尾部退字符，直到「内容 + …」放得下；
  // 退到整行空则去掉该行、改用上一行承载（不退化成「一坨字 + …」）
  if (hitLimit && ellipsisWidth > 0) {
    for (let guard: number = 0; guard < POSTER_TIERS.length + 4; guard++) {
      const last: PosterChar[] = outChars[outChars.length - 1];
      let width: number = 0;
      for (const pc of last) {
        width += pc.width;
      }
      while (last.length > 0 && width + ellipsisWidth > maxWidth) {
        const removed: PosterChar = last[last.length - 1];
        last.pop();
        width -= removed.width;
      }
      if (last.length > 0) {
        last.push({ ch: POSTER_ELLIPSIS, width: ellipsisWidth });
        break;
      }
      if (outChars.length > 1) {
        outChars.pop();
        outPara.pop();
      } else {
        break;
      }
    }
  }

  outPara[outPara.length - 1] = true;

  const lines: string[] = [];
  const lineWidths: number[] = [];
  for (const row of outChars) {
    let text: string = '';
    let width: number = 0;
    for (const pc of row) {
      text += pc.ch;
      width += pc.width;
    }
    lines.push(text);
    lineWidths.push(width);
  }
  return { lines: lines, lineWidths: lineWidths, lineEndsParagraph: outPara, truncated: hitLimit };
}

/**
 * 字符串 → 逐字宽度数组。
 * charLimit 是**必要的性能闸门**：正文上限 5000 字，若全量逐字度量就是 5000 次
 * measureText（主线程栅格化期间调用）。海报最多只需要 maxLines × 每行字数 个字。
 */
export function toPosterChars(text: string, font: drawing.Font, charLimit: number): PosterChar[] {
  const out: PosterChar[] = [];
  let i: number = 0;
  while (i < text.length && out.length < charLimit) {
    const unit: PosterCodeUnit = readChar(text, i);
    i += unit.size;
    if (unit.ch === '\r') {
      continue;
    }
    const width: number = unit.ch === '\n' ? 0 : measureTextWidth(unit.ch, font);
    out.push({ ch: unit.ch, width: width });
  }
  return out;
}

// ───────────────────────── 排版结果 ─────────────────────────

export interface PosterTypeset {
  hero: number;
  lineHeight: number;
  align: PosterAlign;
  lines: string[];
  lineWidths: number[];
  lineEndsParagraph: boolean[];
  truncated: boolean;
  /** 正文块总高（含段间距），供垂直居中 */
  blockHeight: number;
}

// 基线在行内的位置：宋体 cap 高度约 0.86 em（沿用设计样张的取值）
const BASELINE_RATIO: number = 0.86;

/**
 * 唯一的排版入口：内容 + 样式 → 档位 / 折行 / 块高。
 * 渲染（renderPosterPixelMap）与判定（doesTextFitInPoster）共用本函数，
 * 从根上消除「测量与绘制各写一套」导致的偏差。
 */
export function typesetPosterBody(content: string, styleKey: string): PosterTypeset {
  const style: TextPosterStyleOption = resolveTextPosterStyle(styleKey);
  const boxWidth: number = style.boxRight - style.boxLeft;
  const boxHeight: number = style.boxBottom - style.boxTop;
  const length: number = posterTextLength(content);

  // 选档：取「第一个装得下的档位」；都装不下就用最小档 + 截断（与设计样张一致）
  let tierIndex: number = POSTER_TIERS.length - 1;
  for (let i: number = 0; i < POSTER_TIERS.length; i++) {
    if (length <= posterStyleCapacity(style, POSTER_TIERS[i])) {
      tierIndex = i;
      break;
    }
  }
  const tier: PosterTier = POSTER_TIERS[tierIndex];
  const lineHeight: number = tier.hero * tier.lineRatio;
  const maxLines: number = Math.max(1, Math.floor(boxHeight / lineHeight));

  const font: drawing.Font = createPosterFont(tier.hero, 'hero');
  const perLine: number = Math.max(1, Math.floor(boxWidth / tier.hero));
  // 逐字度量只做到「够排满 maxLines 行」再多一点：正文上限 5000 字，全量逐字度量就是
  // 5000 次 measureText（且发生在主线程栅格化期间）。这里取 maxLines × 每行上限 + 8，
  // 既保证「内容超过容量时一定会撞到 maxLines」（从而正确置 truncated），
  // 又保证「内容没超容量时一个字符都不会被漏量」。
  const charLimit: number = maxLines * perLine + 8;
  const chars: PosterChar[] = toPosterChars(content, font, charLimit);
  const ellipsisWidth: number = measureTextWidth(POSTER_ELLIPSIS, font);
  const wrapped: PosterWrapResult = wrapBody(chars, boxWidth, maxLines, ellipsisWidth);

  const paraGap: number = lineHeight * POSTER_PARA_GAP_RATIO;
  let blockHeight: number = 0;
  for (let i: number = 0; i < wrapped.lines.length; i++) {
    blockHeight += lineHeight;
    if (i < wrapped.lineEndsParagraph.length && wrapped.lineEndsParagraph[i]) {
      blockHeight += paraGap;
    }
  }
  blockHeight -= paraGap;

  return {
    hero: tier.hero,
    lineHeight: lineHeight,
    align: tier.align,
    lines: wrapped.lines,
    lineWidths: wrapped.lineWidths,
    lineEndsParagraph: wrapped.lineEndsParagraph,
    truncated: wrapped.truncated,
    blockHeight: blockHeight,
  };
}

/** 首行基线（相对文字区顶端）：块在可用高度内垂直居中 + 上下夹紧 */
export function posterFirstBaseline(typeset: PosterTypeset, areaTop: number, areaHeight: number): number {
  const slack: number = areaHeight - typeset.blockHeight;
  const top: number = areaTop + (slack > 0 ? slack / 2 : 0);
  return top + typeset.hero * BASELINE_RATIO;
}

/** 居中档要预留小标签的高度 */
export function posterLabelReserve(typeset: PosterTypeset, hasLabel: boolean): number {
  return hasLabel && typeset.align === 'center' ? POSTER_LABEL_RESERVE : 0;
}

// ───────────────────────── 兼容导出（shareCard.ets 在用，签名不可破坏） ─────────────────────────

/**
 * 简易折行（分享卡在用）。语义与重构前一致：空内容给占位句；超出 maxLines 时
 * 末行补 …；只是内部换成了带避头尾的新算法，排版质量一同受益。
 */
export function splitLines(text: string, font: drawing.Font, maxWidth: number, maxLines: number): string[] {
  const normalized: string = text.replace(/\r/g, '').trim();
  if (normalized.length === 0) {
    return ['写下你的观点，让更多人看见。'];
  }
  const chars: PosterChar[] = toPosterChars(normalized, font, maxLines * Math.max(1, Math.floor(maxWidth / font.getSize())) + 8);
  const ellipsisWidth: number = measureTextWidth(POSTER_ELLIPSIS, font);
  return wrapBody(chars, maxWidth, maxLines, ellipsisWidth).lines;
}
