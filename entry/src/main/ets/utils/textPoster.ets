// 纯文字帖子封面：在端侧绘制 JPEG 海报并复用既有对象存储上传链路。
// 原始正文仍会随帖子保存，海报只承担信息流的视觉封面，不能替代可搜索、可审核的文本。
import { drawing, common2D } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { Genre } from '../models/types';
import { getUploadSignature, resolveUploadPutUrl, toStoredMediaRef, UploadSignature } from '../services/api';

const POSTER_WIDTH: number = 1080;
const POSTER_HEIGHT: number = 1440;
const POSTER_MAX_BODY_LINES: number = 7;
const POSTER_UPLOAD_TIMEOUT: number = 15000;

// 衬线字体 Typeface，由 Index.ets 在启动时设置
let serifTypeface: drawing.Typeface | null = null;

export function setSerifTypeface(typeface: drawing.Typeface | null): void {
  serifTypeface = typeface;
}

function loadSerifTypeface(): drawing.Typeface | null {
  return serifTypeface;
}

export const TEXT_POSTER_ASPECT_RATIO: number = POSTER_WIDTH / POSTER_HEIGHT;

export type TextPosterStyle = 'film' | 'kraft' | 'sticky' | 'paper';
export type TextPosterTexture = 'film' | 'kraft' | 'sticky' | 'paper';

export interface TextPosterStyleOption {
  key: TextPosterStyle;
  label: string;
  texture: TextPosterTexture;
  background: string;
  surface: string;
  innerSurface: string;
  accent: string;
  text: string;
  backgroundRgb: number[];
  surfaceRgb: number[];
  innerSurfaceRgb: number[];
  accentRgb: number[];
  textRgb: number[];
}

export const TEXT_POSTER_STYLES: TextPosterStyleOption[] = [
  {
    key: 'film', label: '胶片', texture: 'film', background: '#2A3038', surface: '#E6D5B8', innerSurface: '#F4E7CF', accent: '#8B0000', text: '#000000',
    backgroundRgb: [42, 48, 56], surfaceRgb: [230, 213, 184], innerSurfaceRgb: [244, 231, 207], accentRgb: [139, 0, 0], textRgb: [0, 0, 0],
  },
  {
    key: 'kraft', label: '牛皮纸', texture: 'kraft', background: '#B88F61', surface: '#D0A873', innerSurface: '#E5C18F', accent: '#3A1A00', text: '#000000',
    backgroundRgb: [184, 143, 97], surfaceRgb: [208, 168, 115], innerSurfaceRgb: [229, 193, 143], accentRgb: [58, 26, 0], textRgb: [0, 0, 0],
  },
  {
    key: 'sticky', label: '便利贴', texture: 'sticky', background: '#D9E6DD', surface: '#FFE169', innerSurface: '#FFEE8F', accent: '#B22222', text: '#000000',
    backgroundRgb: [217, 230, 221], surfaceRgb: [255, 225, 105], innerSurfaceRgb: [255, 238, 143], accentRgb: [178, 34, 34], textRgb: [0, 0, 0],
  },
  {
    key: 'paper', label: '素纸', texture: 'paper', background: '#E8E2D7', surface: '#FAF7EF', innerSurface: '#FFFDF6', accent: '#0D2F5F', text: '#000000',
    backgroundRgb: [232, 226, 215], surfaceRgb: [250, 247, 239], innerSurfaceRgb: [255, 253, 246], accentRgb: [13, 47, 95], textRgb: [0, 0, 0],
  },
];

export function resolveTextPosterStyle(value?: string): TextPosterStyleOption {
  for (const style of TEXT_POSTER_STYLES) {
    if (style.key === value) {
      return style;
    }
  }
  return TEXT_POSTER_STYLES[0];
}

export function splitLines(text: string, font: drawing.Font, maxWidth: number, maxLines: number): string[] {
  const normalized: string = text.replace(/\r/g, '').trim();
  if (normalized.length === 0) {
    return ['写下你的观点，让更多人看见。'];
  }

  const lines: string[] = [];
  const paragraphs: string[] = normalized.split('\n');
  for (const paragraph of paragraphs) {
    let line: string = '';
    for (let i = 0; i < paragraph.length; i++) {
      const candidate: string = line + paragraph[i];
      if (line.length > 0 && font.measureText(candidate, drawing.TextEncoding.TEXT_ENCODING_UTF8) > maxWidth) {
        lines.push(line);
        line = paragraph[i];
        if (lines.length >= maxLines) {
          break;
        }
      } else {
        line = candidate;
      }
    }
    if (lines.length >= maxLines) {
      break;
    }
    if (line.length > 0) {
      lines.push(line);
    }
    if (lines.length >= maxLines) {
      break;
    }
  }

  if (lines.length >= maxLines && normalized.length > lines.join('').length) {
    const lastIndex: number = lines.length - 1;
    let last: string = lines[lastIndex];
    while (last.length > 1 && font.measureText(last + '…', drawing.TextEncoding.TEXT_ENCODING_UTF8) > maxWidth) {
      last = last.substring(0, last.length - 1);
    }
    lines[lastIndex] = last + '…';
  }
  return lines;
}

export interface PosterTextItem {
  text: string;
  x: number;
  y: number;
  size: number;
  weight: number;
  color: string;
}

// 供发布页用"已注册的 UI 宋体 Text + 截图"生成文字覆盖层：布局与画布文字保持同一套算法。
export function layoutPosterText(title: string, content: string, style: TextPosterStyleOption): PosterTextItem[] {
  const items: PosterTextItem[] = [];
  const normalizedContent: string = content.trim();
  const displayContent: string = normalizedContent.length > 0 ? normalizedContent : '写下你的观点，让更多人看见。';
  const bodySize: number = normalizedContent.length > 150 ? 74 : normalizedContent.length > 80 ? 94 : 118;
  const bodyFont: drawing.Font = new drawing.Font();
  bodyFont.setSize(bodySize);
  bodyFont.enableEmbolden(true);
  const bodyLines: string[] = splitLines(displayContent, bodyFont, 720, POSTER_MAX_BODY_LINES);
  const lineHeight: number = bodySize + 42;
  let cursorY: number = (POSTER_HEIGHT - bodyLines.length * lineHeight) / 2 + bodySize;
  for (const line of bodyLines) {
    const w: number = bodyFont.measureText(line, drawing.TextEncoding.TEXT_ENCODING_UTF8);
    items.push({ text: line, x: (POSTER_WIDTH - w) / 2, y: cursorY - bodySize, size: bodySize, weight: 700, color: style.text });
    cursorY += lineHeight;
  }
  const titleFont: drawing.Font = new drawing.Font();
  titleFont.setSize(34);
  titleFont.enableEmbolden(true);
  const displayTitle: string = title.trim().length > 0 ? title.trim() : '有据 · 文字帖';
  const titleLines: string[] = splitLines(displayTitle, titleFont, 720, 1);
  const tw: number = titleFont.measureText(titleLines[0], drawing.TextEncoding.TEXT_ENCODING_UTF8);
  items.push({ text: titleLines[0], x: (POSTER_WIDTH - tw) / 2, y: 226 - 34, size: 34, weight: 700, color: style.text });
  items.push({ text: '“', x: 140, y: 96, size: 246, weight: 700, color: style.accent });
  items.push({ text: '”', x: 760, y: POSTER_HEIGHT - 132 - 246, size: 246, weight: 700, color: style.accent });
  return items;
}

export function makeColor(alpha: number, red: number, green: number, blue: number): common2D.Color {
  return { alpha: alpha, red: red, green: green, blue: blue };
}

export function drawText(canvas: drawing.Canvas, brush: drawing.Brush, font: drawing.Font, value: string, x: number, y: number, color: common2D.Color): void {
  brush.setColor(color);
  canvas.attachBrush(brush);
  const blob: drawing.TextBlob = drawing.TextBlob.makeFromString(value, font, drawing.TextEncoding.TEXT_ENCODING_UTF8);
  canvas.drawTextBlob(blob, x, y);
}

export function fillRoundRect(canvas: drawing.Canvas, brush: drawing.Brush, left: number, top: number, right: number, bottom: number, radius: number, color: common2D.Color): void {
  brush.setColor(color);
  canvas.attachBrush(brush);
  canvas.drawRoundRect(new drawing.RoundRect({ left, top, right, bottom }, radius, radius));
}

function drawLine(canvas: drawing.Canvas, pen: drawing.Pen, x0: number, y0: number, x1: number, y1: number, width: number, color: common2D.Color): void {
  pen.setColor(color);
  pen.setStrokeWidth(width);
  pen.setAntiAlias(true);
  canvas.attachPen(pen);
  canvas.drawLine(x0, y0, x1, y1);
  canvas.detachPen();
}

function drawCircle(canvas: drawing.Canvas, brush: drawing.Brush, x: number, y: number, radius: number, color: common2D.Color): void {
  brush.setColor(color);
  canvas.attachBrush(brush);
  canvas.drawCircle(x, y, radius);
}

function drawTriangle(canvas: drawing.Canvas, brush: drawing.Brush, x0: number, y0: number, x1: number, y1: number, x2: number, y2: number, color: common2D.Color): void {
  const path: drawing.Path = new drawing.Path();
  path.moveTo(x0, y0);
  path.lineTo(x1, y1);
  path.lineTo(x2, y2);
  path.close();
  brush.setColor(color);
  canvas.attachBrush(brush);
  canvas.drawPath(path);
}

function drawGrain(canvas: drawing.Canvas, brush: drawing.Brush, left: number, top: number, width: number, height: number, count: number, color: common2D.Color): void {
  for (let i = 0; i < count; i++) {
    const x: number = left + ((i * 53 + i * i * 7) % width);
    const y: number = top + ((i * 97 + i * i * 3) % height);
    drawCircle(canvas, brush, x, y, 1 + (i % 3), color);
  }
}

function drawFilmSurface(canvas: drawing.Canvas, brush: drawing.Brush, pen: drawing.Pen, style: TextPosterStyleOption): void {
  const accent: common2D.Color = makeColor(255, style.accentRgb[0], style.accentRgb[1], style.accentRgb[2]);
  fillRoundRect(canvas, brush, 72, 88, 1028, POSTER_HEIGHT - 52, 34, makeColor(80, 0, 0, 0));
  fillRoundRect(canvas, brush, 56, 64, 1012, POSTER_HEIGHT - 76, 28, makeColor(255, style.surfaceRgb[0], style.surfaceRgb[1], style.surfaceRgb[2]));
  fillRoundRect(canvas, brush, 118, 102, 950, POSTER_HEIGHT - 114, 18, makeColor(255, style.innerSurfaceRgb[0], style.innerSurfaceRgb[1], style.innerSurfaceRgb[2]));
  fillRoundRect(canvas, brush, 56, 64, 116, POSTER_HEIGHT - 76, 14, makeColor(220, 34, 39, 43));
  fillRoundRect(canvas, brush, 952, 64, 1012, POSTER_HEIGHT - 76, 14, makeColor(220, 34, 39, 43));
  for (let y = 116; y < POSTER_HEIGHT - 100; y += 112) {
    drawCircle(canvas, brush, 86, y, 13, makeColor(230, 16, 20, 24));
    drawCircle(canvas, brush, 982, y, 13, makeColor(230, 16, 20, 24));
  }
  drawGrain(canvas, brush, 124, 182, 820, 1020, 140, makeColor(18, 86, 56, 45));
  drawLine(canvas, pen, 146, 150, 922, 150, 10, makeColor(190, accent.red, accent.green, accent.blue));
  drawLine(canvas, pen, 146, POSTER_HEIGHT - 142, 922, POSTER_HEIGHT - 142, 10, makeColor(190, accent.red, accent.green, accent.blue));
}

function drawKraftSurface(canvas: drawing.Canvas, brush: drawing.Brush, pen: drawing.Pen, style: TextPosterStyleOption): void {
  const accent: common2D.Color = makeColor(255, style.accentRgb[0], style.accentRgb[1], style.accentRgb[2]);
  fillRoundRect(canvas, brush, 72, 88, 1028, POSTER_HEIGHT - 52, 30, makeColor(80, 44, 28, 18));
  fillRoundRect(canvas, brush, 56, 64, 1012, POSTER_HEIGHT - 76, 30, makeColor(255, style.surfaceRgb[0], style.surfaceRgb[1], style.surfaceRgb[2]));
  fillRoundRect(canvas, brush, 92, 100, 976, POSTER_HEIGHT - 112, 18, makeColor(255, style.innerSurfaceRgb[0], style.innerSurfaceRgb[1], style.innerSurfaceRgb[2]));
  for (let i = 0; i < 16; i++) {
    const y: number = 126 + i * 78;
    drawLine(canvas, pen, 112 + (i % 3) * 19, y, 940 - (i % 4) * 17, y + ((i % 2) === 0 ? 4 : -3), 3, makeColor(28, 113, 75, 39));
  }
  drawGrain(canvas, brush, 112, 122, 840, 1070, 180, makeColor(22, 95, 62, 34));
  for (let x = 128; x < 940; x += 42) {
    drawLine(canvas, pen, x, 140, x + 22, 140, 4, makeColor(180, accent.red, accent.green, accent.blue));
    drawLine(canvas, pen, x, POSTER_HEIGHT - 150, x + 22, POSTER_HEIGHT - 150, 4, makeColor(180, accent.red, accent.green, accent.blue));
  }
}

function drawStickySurface(canvas: drawing.Canvas, brush: drawing.Brush, style: TextPosterStyleOption): void {
  fillRoundRect(canvas, brush, 98, 142, 1018, POSTER_HEIGHT - 28, 20, makeColor(82, 63, 25, 58));
  fillRoundRect(canvas, brush, 74, 112, 994, POSTER_HEIGHT - 58, 10, makeColor(255, style.surfaceRgb[0], style.surfaceRgb[1], style.surfaceRgb[2]));
  fillRoundRect(canvas, brush, 108, 146, 960, POSTER_HEIGHT - 94, 4, makeColor(255, style.innerSurfaceRgb[0], style.innerSurfaceRgb[1], style.innerSurfaceRgb[2]));
  fillRoundRect(canvas, brush, 382, 92, 700, 148, 3, makeColor(110, 255, 255, 255));
  drawTriangle(canvas, brush, 880, POSTER_HEIGHT - 94, 960, POSTER_HEIGHT - 94, 960, POSTER_HEIGHT - 174, makeColor(105, 210, 174, 82));
  drawGrain(canvas, brush, 122, 172, 818, 1040, 90, makeColor(20, 142, 103, 32));
  drawLine(canvas, new drawing.Pen(), 150, POSTER_HEIGHT - 168, 900, POSTER_HEIGHT - 168, 5, makeColor(120, style.accentRgb[0], style.accentRgb[1], style.accentRgb[2]));
}

function drawPaperSurface(canvas: drawing.Canvas, brush: drawing.Brush, style: TextPosterStyleOption): void {
  fillRoundRect(canvas, brush, 72, 88, 1028, POSTER_HEIGHT - 52, 46, makeColor(52, 35, 54, 72));
  fillRoundRect(canvas, brush, 56, 64, 1012, POSTER_HEIGHT - 76, 46, makeColor(255, style.surfaceRgb[0], style.surfaceRgb[1], style.surfaceRgb[2]));
  fillRoundRect(canvas, brush, 78, 86, 990, POSTER_HEIGHT - 98, 34, makeColor(255, style.innerSurfaceRgb[0], style.innerSurfaceRgb[1], style.innerSurfaceRgb[2]));
  fillRoundRect(canvas, brush, 108, 118, 960, POSTER_HEIGHT - 128, 26, makeColor(24, style.accentRgb[0], style.accentRgb[1], style.accentRgb[2]));
  fillRoundRect(canvas, brush, 132, 154, 936, 166, 6, makeColor(112, style.accentRgb[0], style.accentRgb[1], style.accentRgb[2]));
  drawGrain(canvas, brush, 126, 178, 816, 1010, 74, makeColor(16, 90, 100, 24));
}

function drawPosterSurface(canvas: drawing.Canvas, brush: drawing.Brush, pen: drawing.Pen, style: TextPosterStyleOption): void {
  brush.setColor(makeColor(255, style.backgroundRgb[0], style.backgroundRgb[1], style.backgroundRgb[2]));
  canvas.attachBrush(brush);
  canvas.drawRect(0, 0, POSTER_WIDTH, POSTER_HEIGHT);
  switch (style.texture) {
    case 'film': drawFilmSurface(canvas, brush, pen, style); break;
    case 'kraft': drawKraftSurface(canvas, brush, pen, style); break;
    case 'sticky': drawStickySurface(canvas, brush, style); break;
    default: drawPaperSurface(canvas, brush, style); break;
  }
}

// 在 overlay（实心背景+文字）之上重绘纸纹、边框、打孔和装饰元素，使文字清晰且保留质感。
function drawTextureOnTop(canvas: drawing.Canvas, brush: drawing.Brush, pen: drawing.Pen, style: TextPosterStyleOption): void {
  const accent: common2D.Color = makeColor(255, style.accentRgb[0], style.accentRgb[1], style.accentRgb[2]);
  switch (style.texture) {
    case 'film': {
      // 外框：给 overlay 添加深色边框和打孔
      fillRoundRect(canvas, brush, 56, 64, 1012, POSTER_HEIGHT - 76, 28, makeColor(30, style.surfaceRgb[0], style.surfaceRgb[1], style.surfaceRgb[2]));
      fillRoundRect(canvas, brush, 56, 64, 116, POSTER_HEIGHT - 76, 14, makeColor(220, 34, 39, 43));
      fillRoundRect(canvas, brush, 952, 64, 1012, POSTER_HEIGHT - 76, 14, makeColor(220, 34, 39, 43));
      for (let y = 116; y < POSTER_HEIGHT - 100; y += 112) {
        drawCircle(canvas, brush, 86, y, 13, makeColor(230, 16, 20, 24));
        drawCircle(canvas, brush, 982, y, 13, makeColor(230, 16, 20, 24));
      }
      drawGrain(canvas, brush, 124, 182, 820, 1020, 140, makeColor(18, 86, 56, 45));
      drawLine(canvas, pen, 146, 150, 922, 150, 10, makeColor(190, accent.red, accent.green, accent.blue));
      drawLine(canvas, pen, 146, POSTER_HEIGHT - 142, 922, POSTER_HEIGHT - 142, 10, makeColor(190, accent.red, accent.green, accent.blue));
      break;
    }
    case 'kraft': {
      fillRoundRect(canvas, brush, 56, 64, 1012, POSTER_HEIGHT - 76, 30, makeColor(35, style.surfaceRgb[0], style.surfaceRgb[1], style.surfaceRgb[2]));
      for (let i = 0; i < 16; i++) {
        const y: number = 126 + i * 78;
        drawLine(canvas, pen, 112 + (i % 3) * 19, y, 940 - (i % 4) * 17, y + ((i % 2) === 0 ? 4 : -3), 3, makeColor(28, 113, 75, 39));
      }
      drawGrain(canvas, brush, 112, 122, 840, 1070, 180, makeColor(22, 95, 62, 34));
      for (let x = 128; x < 940; x += 42) {
        drawLine(canvas, pen, x, 140, x + 22, 140, 4, makeColor(180, accent.red, accent.green, accent.blue));
        drawLine(canvas, pen, x, POSTER_HEIGHT - 150, x + 22, POSTER_HEIGHT - 150, 4, makeColor(180, accent.red, accent.green, accent.blue));
      }
      break;
    }
    case 'sticky': {
      fillRoundRect(canvas, brush, 74, 112, 994, POSTER_HEIGHT - 58, 10, makeColor(30, style.surfaceRgb[0], style.surfaceRgb[1], style.surfaceRgb[2]));
      drawGrain(canvas, brush, 122, 172, 818, 1040, 90, makeColor(20, 142, 103, 32));
      drawLine(canvas, pen, 150, POSTER_HEIGHT - 168, 900, POSTER_HEIGHT - 168, 5, makeColor(120, accent.red, accent.green, accent.blue));
      break;
    }
    default: {
      fillRoundRect(canvas, brush, 56, 64, 1012, POSTER_HEIGHT - 76, 46, makeColor(25, style.surfaceRgb[0], style.surfaceRgb[1], style.surfaceRgb[2]));
      fillRoundRect(canvas, brush, 108, 118, 960, POSTER_HEIGHT - 128, 26, makeColor(24, style.accentRgb[0], style.accentRgb[1], style.accentRgb[2]));
      fillRoundRect(canvas, brush, 132, 154, 936, 166, 6, makeColor(112, style.accentRgb[0], style.accentRgb[1], style.accentRgb[2]));
      drawGrain(canvas, brush, 126, 178, 816, 1010, 74, makeColor(16, 90, 100, 24));
      break;
    }
  }
}

async function createPosterBytes(title: string, content: string, _genre: Genre, styleKey?: string, overlay?: image.PixelMap): Promise<ArrayBuffer> {
  const pixelMap: image.PixelMap = image.createPixelMapSync({
    size: { width: POSTER_WIDTH, height: POSTER_HEIGHT },
    pixelFormat: image.PixelMapFormat.RGBA_8888,
    editable: true,
  });
  const canvas: drawing.Canvas = new drawing.Canvas(pixelMap);
  const brush: drawing.Brush = new drawing.Brush();
  const pen: drawing.Pen = new drawing.Pen();
  const style: TextPosterStyleOption = resolveTextPosterStyle(styleKey);
  const accentRed: number = style.accentRgb[0];
  const accentGreen: number = style.accentRgb[1];
  const accentBlue: number = style.accentRgb[2];
  const textRed: number = style.textRgb[0];
  const textGreen: number = style.textRgb[1];
  const textBlue: number = style.textRgb[2];

  // 加载衬线字体，让 canvas 绘制的文字也使用宋体
  const serifTypeface: drawing.Typeface | null = loadSerifTypeface();

  try {
    drawPosterSurface(canvas, brush, pen, style);

    // 强制使用 canvas 直接绘制文字，跳过 componentSnapshot 以避免颜色失真
    const _unused = overlay; void _unused;
    if (false) {
      // 以下代码被跳过，因为 componentSnapshot 会导致文字颜色失真
      const dst: common2D.Rect = { left: 0, top: 0, right: POSTER_WIDTH, bottom: POSTER_HEIGHT };
      canvas.drawImageRect(overlay, dst);
      // 在 overlay 之上重绘边框、打孔、纸纹等装饰元素
      drawTextureOnTop(canvas, brush, pen, style);
    } else {
      const normalizedContent: string = content.trim();
      const displayContent: string = normalizedContent.length > 0 ? normalizedContent : '写下你的观点，让更多人看见。';
      const bodyFont: drawing.Font = new drawing.Font();
      const bodySize: number = normalizedContent.length > 150 ? 74 : normalizedContent.length > 80 ? 94 : 118;
      bodyFont.setSize(bodySize);
      bodyFont.enableEmbolden(true);
      if (serifTypeface !== null) {
        bodyFont.setTypeface(serifTypeface);
      }
      const bodyLines: string[] = splitLines(displayContent, bodyFont, 720, POSTER_MAX_BODY_LINES);
      const lineHeight: number = bodySize + 42;
      const textBlockHeight: number = bodyLines.length * lineHeight;
      let cursorY: number = (POSTER_HEIGHT - textBlockHeight) / 2 + bodySize;

      const titleFont: drawing.Font = new drawing.Font();
      titleFont.setSize(34);
      titleFont.enableEmbolden(true);
      if (serifTypeface !== null) {
        titleFont.setTypeface(serifTypeface);
      }
      const displayTitle: string = title.trim().length > 0 ? title.trim() : '有据 · 文字帖';
      const titleLines: string[] = splitLines(displayTitle, titleFont, 720, 1);
      const titleWidth: number = titleFont.measureText(titleLines[0], drawing.TextEncoding.TEXT_ENCODING_UTF8);
      drawText(canvas, brush, titleFont, titleLines[0], (POSTER_WIDTH - titleWidth) / 2, 226, makeColor(255, textRed, textGreen, textBlue));

      // 双引号独立放置在对角，不占用正文排版宽度。
      const quoteFont: drawing.Font = new drawing.Font();
      quoteFont.setSize(246);
      quoteFont.enableEmbolden(true);
      if (serifTypeface !== null) {
        quoteFont.setTypeface(serifTypeface);
      }
      drawText(canvas, brush, quoteFont, '"', 140 + 7, 310 + 9, makeColor(28, 35, 54, 72));
      drawText(canvas, brush, quoteFont, '“', 140, 310, makeColor(210, accentRed, accentGreen, accentBlue));
      drawText(canvas, brush, quoteFont, '”', 760 + 7, POSTER_HEIGHT - 132 + 9, makeColor(28, 35, 54, 72));
      drawText(canvas, brush, quoteFont, '”', 760, POSTER_HEIGHT - 132, makeColor(210, accentRed, accentGreen, accentBlue));

      // 正文：深黑纯文字 + 极淡投影，确保清晰可读
      for (const line of bodyLines) {
        const lineWidth: number = bodyFont.measureText(line, drawing.TextEncoding.TEXT_ENCODING_UTF8);
        const textX: number = (POSTER_WIDTH - lineWidth) / 2;
        // 第1层：右下偏移淡阴影（仅增加立体感，不影响清晰度）
        drawText(canvas, brush, bodyFont, line, textX + 4, cursorY + 6, makeColor(35, 40, 25, 25));
        // 第2层：主文字（纯黑）
        drawText(canvas, brush, bodyFont, line, textX, cursorY, makeColor(255, textRed, textGreen, textBlue));
        cursorY += lineHeight;
      }
    }

    // 底部细线保持正文收束，不添加标题或品牌。
    fillRoundRect(canvas, brush, 164, POSTER_HEIGHT - 176, 916, POSTER_HEIGHT - 166, 5, makeColor(70, accentRed, accentGreen, accentBlue));

    const packer: image.ImagePacker = image.createImagePacker();
    try {
      return await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 95 });
    } finally {
      await packer.release();
    }
  } finally {
    await pixelMap.release();
  }
}

function putBinary(url: string, data: ArrayBuffer, contentType: string): Promise<void> {
  return new Promise<void>((resolve: () => void, reject: (err: Error) => void): void => {
    const req = http.createHttp();
    let settled: boolean = false;
    let timer: number = 0;
    const finish = (error?: Error): void => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timer);
      req.destroy();
      if (error === undefined) {
        resolve();
      } else {
        reject(error);
      }
    };
    timer = setTimeout((): void => {
      finish(new Error('文字海报上传超时'));
    }, POSTER_UPLOAD_TIMEOUT) as number;
    try {
      req.request(url, {
        method: http.RequestMethod.PUT,
        header: { 'Content-Type': contentType },
        extraData: data,
        connectTimeout: POSTER_UPLOAD_TIMEOUT,
        readTimeout: POSTER_UPLOAD_TIMEOUT,
      }, (err: Error | null, resp: http.HttpResponse): void => {
        if (err !== null) {
          finish(err);
        } else if (resp.responseCode >= 200 && resp.responseCode < 300) {
          finish();
        } else {
          finish(new Error('文字海报上传失败 HTTP ' + resp.responseCode + '（请检查网络或对象存储配置）'));
        }
      });
    } catch (e) {
      finish(e as Error);
    }
  });
}

/**
 * 判断正文能否在文字海报中完整显示（不超过 POSTER_MAX_BODY_LINES 行、无截断省略号）。
 * 复用与 createPosterBytes 完全相同的字号选择策略和 splitLines 排版算法，
 * 供详情页决定是否在海报下方冗余展示正文纯文本。
 */
export function doesTextFitInPoster(content: string): boolean {
  const normalized: string = content.replace(/\r/g, '').trim();
  if (normalized.length === 0) {
    return true;
  }
  const bodySize: number = normalized.length > 150 ? 74 : normalized.length > 80 ? 94 : 118;
  const bodyFont: drawing.Font = new drawing.Font();
  bodyFont.setSize(bodySize);
  bodyFont.enableEmbolden(true);
  const lines: string[] = splitLines(normalized, bodyFont, 720, POSTER_MAX_BODY_LINES);
  // splitLines 在行数溢出时会在末行追加 '…' 并丢弃后续内容；
  // 如果拼回所有行的字符数 < 原始正文字符数，说明有内容被截断。
  return lines.join('').length >= normalized.length;
}

export async function uploadTextPoster(title: string, content: string, genre: Genre, styleKey?: string, overlay?: image.PixelMap): Promise<string> {
  let bytes: ArrayBuffer;
  try {
    bytes = await createPosterBytes(title, content, genre, styleKey, overlay);
  } catch (e) {
    throw new Error('文字海报绘制失败：' + ((e as Error).message ?? '未知错误'));
  }
  let signature: UploadSignature;
  try {
    signature = await getUploadSignature('image/jpeg', 'posts');
  } catch (e) {
    throw new Error('文字海报签名失败：' + ((e as Error).message ?? '未知错误'));
  }
  try {
    await putBinary(resolveUploadPutUrl(signature), bytes, signature.contentType);
  } catch (e) {
    throw new Error('文字海报上传失败：' + ((e as Error).message ?? '未知错误'));
  }
  return toStoredMediaRef(signature);
}
