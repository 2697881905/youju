// 纯文字帖子封面：在端侧绘制 JPEG 海报并复用既有对象存储上传链路。
// 原始正文仍会随帖子保存，海报只承担信息流的视觉封面，不能替代可搜索、可审核的文本。
import { drawing, common2D } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { Genre } from '../models/types';
import { getUploadSignature, resolveUploadPutUrl, UploadSignature } from '../services/api';

const POSTER_WIDTH: number = 1080;
const POSTER_HEIGHT: number = 1440;
const POSTER_MAX_BODY_LINES: number = 7;
const POSTER_UPLOAD_TIMEOUT: number = 15000;

export const TEXT_POSTER_ASPECT_RATIO: number = POSTER_WIDTH / POSTER_HEIGHT;

export type TextPosterStyle = 'paper' | 'midnight' | 'mint' | 'coral';

export interface TextPosterStyleOption {
  key: TextPosterStyle;
  label: string;
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
    key: 'paper', label: '纸感', background: '#E0EBF7', surface: '#F9FAF9', innerSurface: '#FFFFFF', accent: '#3067AE', text: '#1F2E46',
    backgroundRgb: [224, 235, 247], surfaceRgb: [249, 250, 249], innerSurfaceRgb: [255, 255, 255], accentRgb: [48, 103, 174], textRgb: [31, 46, 70],
  },
  {
    key: 'midnight', label: '夜色', background: '#1C2330', surface: '#283142', innerSurface: '#303B4D', accent: '#8FB7FF', text: '#F7F9FF',
    backgroundRgb: [28, 35, 48], surfaceRgb: [40, 49, 66], innerSurfaceRgb: [48, 59, 77], accentRgb: [143, 183, 255], textRgb: [247, 249, 255],
  },
  {
    key: 'mint', label: '薄荷', background: '#E0F0EB', surface: '#F3FBF8', innerSurface: '#FFFFFF', accent: '#368770', text: '#1F4A40',
    backgroundRgb: [224, 240, 235], surfaceRgb: [243, 251, 248], innerSurfaceRgb: [255, 255, 255], accentRgb: [54, 135, 112], textRgb: [31, 74, 64],
  },
  {
    key: 'coral', label: '珊瑚', background: '#FAE8E4', surface: '#FFF7F4', innerSurface: '#FFFFFF', accent: '#BE5B4D', text: '#592B27',
    backgroundRgb: [250, 232, 228], surfaceRgb: [255, 247, 244], innerSurfaceRgb: [255, 255, 255], accentRgb: [190, 91, 77], textRgb: [89, 43, 39],
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

function splitLines(text: string, font: drawing.Font, maxWidth: number, maxLines: number): string[] {
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

function makeColor(alpha: number, red: number, green: number, blue: number): common2D.Color {
  return { alpha: alpha, red: red, green: green, blue: blue };
}

function drawText(canvas: drawing.Canvas, brush: drawing.Brush, font: drawing.Font, value: string, x: number, y: number, color: common2D.Color): void {
  brush.setColor(color);
  canvas.attachBrush(brush);
  const blob: drawing.TextBlob = drawing.TextBlob.makeFromString(value, font, drawing.TextEncoding.TEXT_ENCODING_UTF8);
  canvas.drawTextBlob(blob, x, y);
}

function fillRoundRect(canvas: drawing.Canvas, brush: drawing.Brush, left: number, top: number, right: number, bottom: number, radius: number, color: common2D.Color): void {
  brush.setColor(color);
  canvas.attachBrush(brush);
  canvas.drawRoundRect(new drawing.RoundRect({ left, top, right, bottom }, radius, radius));
}

async function createPosterBytes(_title: string, content: string, _genre: Genre, styleKey?: string): Promise<ArrayBuffer> {
  const pixelMap: image.PixelMap = image.createPixelMapSync({
    size: { width: POSTER_WIDTH, height: POSTER_HEIGHT },
    pixelFormat: image.PixelMapFormat.RGBA_8888,
    editable: true,
  });
  const canvas: drawing.Canvas = new drawing.Canvas(pixelMap);
  const brush: drawing.Brush = new drawing.Brush();
  const style: TextPosterStyleOption = resolveTextPosterStyle(styleKey);
  const red: number = style.backgroundRgb[0];
  const green: number = style.backgroundRgb[1];
  const blue: number = style.backgroundRgb[2];
  const surfaceRed: number = style.surfaceRgb[0];
  const surfaceGreen: number = style.surfaceRgb[1];
  const surfaceBlue: number = style.surfaceRgb[2];
  const innerRed: number = style.innerSurfaceRgb[0];
  const innerGreen: number = style.innerSurfaceRgb[1];
  const innerBlue: number = style.innerSurfaceRgb[2];
  const accentRed: number = style.accentRgb[0];
  const accentGreen: number = style.accentRgb[1];
  const accentBlue: number = style.accentRgb[2];
  const textRed: number = style.textRgb[0];
  const textGreen: number = style.textRgb[1];
  const textBlue: number = style.textRgb[2];

  try {
    // 简约拟态底板：仅保留纸张层级、压边与凹槽，不叠加额外图形或文案。
    brush.setColor(makeColor(255, red, green, blue));
    canvas.attachBrush(brush);
    canvas.drawRect(0, 0, POSTER_WIDTH, POSTER_HEIGHT);

    // 纸张阴影、压边和内凹阅读区，保留克制的实体质感；纸面只承载正文内容。
    fillRoundRect(canvas, brush, 72, 88, 1028, POSTER_HEIGHT - 52, 46, makeColor(52, 35, 54, 72));
    fillRoundRect(canvas, brush, 56, 64, 1012, POSTER_HEIGHT - 76, 46, makeColor(255, surfaceRed, surfaceGreen, surfaceBlue));
    fillRoundRect(canvas, brush, 78, 86, 990, POSTER_HEIGHT - 98, 34, makeColor(255, innerRed, innerGreen, innerBlue));
    fillRoundRect(canvas, brush, 108, 118, 960, POSTER_HEIGHT - 128, 26, makeColor(24, accentRed, accentGreen, accentBlue));
    fillRoundRect(canvas, brush, 132, 154, 936, 166, 6, makeColor(112, accentRed, accentGreen, accentBlue));

    const normalizedContent: string = content.trim();
    const displayContent: string = normalizedContent.length > 0 ? normalizedContent : '写下你的观点，让更多人看见。';
    const bodyFont: drawing.Font = new drawing.Font();
    const bodySize: number = normalizedContent.length > 150 ? 74 : normalizedContent.length > 80 ? 94 : 118;
    bodyFont.setSize(bodySize);
    bodyFont.enableEmbolden(true);
    const bodyLines: string[] = splitLines(displayContent, bodyFont, 720, POSTER_MAX_BODY_LINES);
    const lineHeight: number = bodySize + 42;
    const textBlockHeight: number = bodyLines.length * lineHeight;
    let cursorY: number = (POSTER_HEIGHT - textBlockHeight) / 2 + bodySize;

    // 双引号独立放置在对角，不占用正文排版宽度。
    const quoteFont: drawing.Font = new drawing.Font();
    quoteFont.setSize(246);
    quoteFont.enableEmbolden(true);
    drawText(canvas, brush, quoteFont, '“', 140 + 7, 310 + 9, makeColor(28, 35, 54, 72));
    drawText(canvas, brush, quoteFont, '“', 140, 310, makeColor(138, accentRed, accentGreen, accentBlue));
    drawText(canvas, brush, quoteFont, '”', 760 + 7, POSTER_HEIGHT - 132 + 9, makeColor(28, 35, 54, 72));
    drawText(canvas, brush, quoteFont, '”', 760, POSTER_HEIGHT - 132, makeColor(138, accentRed, accentGreen, accentBlue));

    for (const line of bodyLines) {
      const lineWidth: number = bodyFont.measureText(line, drawing.TextEncoding.TEXT_ENCODING_UTF8);
      const textX: number = (POSTER_WIDTH - lineWidth) / 2;
      // 三层字形：纸面反光、柔和阴影和更大字号的正文，形成清晰的艺术字浮雕感。
      drawText(canvas, brush, bodyFont, line, textX - 2, cursorY - 2, makeColor(80, 255, 255, 255));
      drawText(canvas, brush, bodyFont, line, textX + 8, cursorY + 10, makeColor(62, 35, 54, 72));
      drawText(canvas, brush, bodyFont, line, textX, cursorY, makeColor(255, textRed, textGreen, textBlue));
      cursorY += lineHeight;
    }

    // 底部压纹只承担纸张材质，不添加标题或品牌。
    fillRoundRect(canvas, brush, 164, POSTER_HEIGHT - 176, 916, POSTER_HEIGHT - 166, 5, makeColor(70, accentRed, accentGreen, accentBlue));

    const packer: image.ImagePacker = image.createImagePacker();
    try {
      return await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 90 });
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

export async function uploadTextPoster(title: string, content: string, genre: Genre, styleKey?: string): Promise<string> {
  let bytes: ArrayBuffer;
  try {
    bytes = await createPosterBytes(title, content, genre, styleKey);
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
  return signature.viewUrl;
}
