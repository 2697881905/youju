// 文字海报 · 装配与唯一渲染入口
//
// 设计基调（改绘制前先读 posterTokens.ets 顶部的 C1–C7）：
//  「同一种克制排印语言下的 4 种纸」——全部 solid 底色，无渐变、无纹理、无模糊阴影、无旋转；
//  每款只有 1 个材质记忆点；字号只用 3 级（主视觉 / 小标签 / 落款）；字族只用 2 个。
//
// ⚠️ 对外契约不可破坏：
//   · renderPosterPixelMap 是唯一渲染入口，发布与预览共用（预览即发布产物）
//   · scale === 1 时保持恒等变换，绘制坐标一律按 1080×1440 逻辑值书写
//   · 函数内部不 release PixelMap，由调用方负责生命周期
import { drawing, common2D } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { Genre } from '../../models/types';
import { getUploadSignature, resolveUploadPutUrl, toStoredMediaRef, UploadSignature } from '../../services/api';
import {
  POSTER_CONSERVATIVE_STYLE, POSTER_FOOT_BASELINE, POSTER_FOOT_SIZE, POSTER_FOOT_TEXT,
  POSTER_HEIGHT, POSTER_LABEL_BASELINE_OFFSET, POSTER_LABEL_SIZE, POSTER_PARA_GAP_RATIO,
  POSTER_THUMB_SCALE, POSTER_WIDTH, TextPosterStyleOption, resolveTextPosterStyle,
} from './posterTokens';
import {
  PosterTypeset, createPosterFont, drawText, makeColor, measureTextWidth,
  posterFirstBaseline, posterLabelReserve, typesetPosterBody,
} from './posterText';

const POSTER_UPLOAD_TIMEOUT: number = 15000;
const POSTER_PLACEHOLDER: string = '写下你的观点，让更多人看见。';

// 记忆点相对参数（全部相对文字区，改 box 不用动这里）
const DETAIL_GAP_PAPER_TOP: number = 56;   // 素纸：页脚第一条细线距文字区底
const DETAIL_GAP_PAPER_BOTTOM: number = 66; // 素纸：页脚第二条细线（与上一条相距 10）
const DETAIL_INSET_FILM_LINE: number = 24;  // 胶片：左侧竖线在文字区左外侧 24
const DETAIL_GAP_KRAFT: number = 56;        // 牛皮纸：上下实线距文字区各 56
const DETAIL_INSET_STICKY_BAR: number = 24; // 便利贴：强调条在文字区左外侧 24
const DETAIL_WIDTH_STICKY_BAR: number = 4;

// ───────────────────────── 绘制原子 ─────────────────────────

function fillRect(canvas: drawing.Canvas, brush: drawing.Brush, left: number, top: number, right: number, bottom: number, color: common2D.Color): void {
  brush.setColor(color);
  canvas.attachBrush(brush);
  canvas.drawRect(left, top, right, bottom);
}

/**
 * 发丝线：1px 及以下时把线身垂直偏移 0.5px 做像素对齐。
 * 否则抗锯齿会把 1px 摊成上下两条 50% 透明度的淡线，观感是「没画上去」。
 */
function strokeLine(canvas: drawing.Canvas, pen: drawing.Pen, x0: number, y0: number, x1: number, y1: number, width: number, color: common2D.Color): void {
  let ax0: number = x0;
  let ay0: number = y0;
  let ax1: number = x1;
  let ay1: number = y1;
  if (width <= 1) {
    if (y0 === y1) {
      ay0 = y0 + 0.5;
      ay1 = y1 + 0.5;
    } else if (x0 === x1) {
      ax0 = x0 + 0.5;
      ax1 = x1 + 0.5;
    }
  }
  pen.setColor(color);
  pen.setStrokeWidth(width);
  pen.setAntiAlias(true);
  canvas.attachPen(pen);
  canvas.drawLine(ax0, ay0, ax1, ay1);
  canvas.detachPen();
}

// ───────────────────────── 每款唯一的材质记忆点（C5） ─────────────────────────

// 素纸：页脚一条极细双线（书页页脚）
function drawPaperDetail(canvas: drawing.Canvas, pen: drawing.Pen, style: TextPosterStyleOption): void {
  const ink: number[] = style.inkRgb;
  strokeLine(canvas, pen, style.boxLeft, style.boxBottom + DETAIL_GAP_PAPER_TOP,
    style.boxRight, style.boxBottom + DETAIL_GAP_PAPER_TOP, 1, makeColor(56, ink[0], ink[1], ink[2]));
  strokeLine(canvas, pen, style.boxLeft, style.boxBottom + DETAIL_GAP_PAPER_BOTTOM,
    style.boxRight, style.boxBottom + DETAIL_GAP_PAPER_BOTTOM, 0.5, makeColor(31, ink[0], ink[1], ink[2]));
}

// 胶片：左侧一条 1px 暖金竖线（片头/片尾字幕卡语言）。
// 刻意不画齿孔、也不加「FILM · NO.01」这类片号微标签 —— 那是写死的假编号，
// 缩到信息流 330px 宽后只剩约 8px 纯糊，且会让胶片成为唯二超过「每款只 1 个记忆点」的款。
function drawFilmDetail(canvas: drawing.Canvas, pen: drawing.Pen, style: TextPosterStyleOption): void {
  const accent: number[] = style.accentRgb;
  const lineX: number = style.boxLeft - DETAIL_INSET_FILM_LINE;
  strokeLine(canvas, pen, lineX, style.boxTop, lineX, style.boxBottom, 1, makeColor(179, accent[0], accent[1], accent[2]));
}

// 牛皮纸：文字区上下各一条 1px 实线（信纸抬头 / 落款线）
function drawKraftDetail(canvas: drawing.Canvas, pen: drawing.Pen, style: TextPosterStyleOption): void {
  const accent: number[] = style.accentRgb;
  const topY: number = style.boxTop - DETAIL_GAP_KRAFT;
  const bottomY: number = style.boxBottom + DETAIL_GAP_KRAFT;
  strokeLine(canvas, pen, style.boxLeft, topY, style.boxRight, topY, 1, makeColor(97, accent[0], accent[1], accent[2]));
  strokeLine(canvas, pen, style.boxLeft, bottomY, style.boxRight, bottomY, 1, makeColor(97, accent[0], accent[1], accent[2]));
}

// 便利贴：一条 4px 左侧强调竖条（现代笔记 callout，去拟物化）
function drawStickyDetail(canvas: drawing.Canvas, brush: drawing.Brush, style: TextPosterStyleOption): void {
  const accent: number[] = style.accentRgb;
  const barLeft: number = style.boxLeft - DETAIL_INSET_STICKY_BAR;
  fillRect(canvas, brush, barLeft, style.boxTop, barLeft + DETAIL_WIDTH_STICKY_BAR, style.boxBottom,
    makeColor(255, accent[0], accent[1], accent[2]));
}

function drawStyleDetail(canvas: drawing.Canvas, brush: drawing.Brush, pen: drawing.Pen, style: TextPosterStyleOption): void {
  switch (style.texture) {
    case 'film':
      drawFilmDetail(canvas, pen, style);
      break;
    case 'kraft':
      drawKraftDetail(canvas, pen, style);
      break;
    case 'sticky':
      drawStickyDetail(canvas, brush, style);
      break;
    default:
      drawPaperDetail(canvas, pen, style);
      break;
  }
}

// ───────────────────────── 唯一渲染入口 ─────────────────────────

/**
 * 海报唯一渲染源：发布（createPosterBytes）与发布预览（PublishPreviewPage）共用同一段绘制代码，
 * 从根上消除「预览与发布产物不一致」的问题 —— 预览看到的就是发布后得到的像素。
 *
 * 尺寸 = POSTER_WIDTH*scale × POSTER_HEIGHT*scale；绘制坐标一律按 1080×1440 逻辑值书写，
 * scale !== 1 时用 canvas.scale 统一缩放，缩放后与发布产物像素级同构。
 *
 * 注意：函数内部不 release PixelMap，由调用方负责生命周期。
 */
export function renderPosterPixelMap(title: string, content: string, styleKey?: string, scale: number = 1): image.PixelMap {
  const safeScale: number = scale > 0 ? scale : 1;
  const pixelMap: image.PixelMap = image.createPixelMapSync({
    size: { width: Math.round(POSTER_WIDTH * safeScale), height: Math.round(POSTER_HEIGHT * safeScale) },
    pixelFormat: image.PixelMapFormat.RGBA_8888,
    editable: true,
  });
  const canvas: drawing.Canvas = new drawing.Canvas(pixelMap);
  // scale === 1 时保持恒等变换，确保发布路径产物与设计样张像素同构。
  if (safeScale !== 1) {
    canvas.scale(safeScale, safeScale);
  }
  const brush: drawing.Brush = new drawing.Brush();
  const pen: drawing.Pen = new drawing.Pen();
  const style: TextPosterStyleOption = resolveTextPosterStyle(styleKey);
  const ink: number[] = style.inkRgb;

  // 1) 纯色底（C5：禁渐变 / 禁纹理）
  fillRect(canvas, brush, 0, 0, POSTER_WIDTH, POSTER_HEIGHT,
    makeColor(255, style.backgroundRgb[0], style.backgroundRgb[1], style.backgroundRgb[2]));

  // 2) 排版（渲染与判定共用 typesetPosterBody，杜绝两套度量漂移）
  const normalized: string = content.trim();
  const displayContent: string = normalized.length > 0 ? normalized : POSTER_PLACEHOLDER;
  const typeset: PosterTypeset = typesetPosterBody(displayContent, style.key);
  const displayTitle: string = title.trim();
  const hasLabel: boolean = displayTitle.length > 0 && typeset.align === 'center';

  const boxWidth: number = style.boxRight - style.boxLeft;
  const areaTop: number = style.boxTop + posterLabelReserve(typeset, hasLabel);
  const areaHeight: number = style.boxBottom - areaTop;
  const lineHeight: number = typeset.lineHeight;
  const paraGap: number = lineHeight * POSTER_PARA_GAP_RATIO;

  const labelFont: drawing.Font = createPosterFont(POSTER_LABEL_SIZE, 'label');
  const heroFont: drawing.Font = createPosterFont(typeset.hero, 'hero');
  const footFont: drawing.Font = createPosterFont(POSTER_FOOT_SIZE, 'foot');

  // 3) 小标签：用字族差（无衬线 vs 宋体）把层级变安静，而不是只靠字号（C2）
  if (hasLabel) {
    const labelWidth: number = measureTextWidth(displayTitle, labelFont);
    drawText(canvas, brush, labelFont, displayTitle,
      style.boxLeft + (boxWidth - labelWidth) / 2, style.boxTop + POSTER_LABEL_BASELINE_OFFSET,
      makeColor(128, ink[0], ink[1], ink[2]));
  }

  // 4) 主视觉：居中档水平居中，长文档档左对齐（body copy 左对齐）
  let cursorY: number = posterFirstBaseline(typeset, areaTop, areaHeight);
  for (let i: number = 0; i < typeset.lines.length; i++) {
    const line: string = typeset.lines[i];
    if (line.length > 0) {
      const textX: number = typeset.align === 'center'
        ? style.boxLeft + (boxWidth - typeset.lineWidths[i]) / 2
        : style.boxLeft;
      drawText(canvas, brush, heroFont, line, textX, cursorY, makeColor(255, ink[0], ink[1], ink[2]));
    }
    const isParagraphEnd: boolean = i < typeset.lineEndsParagraph.length && typeset.lineEndsParagraph[i];
    cursorY += isParagraphEnd ? lineHeight + paraGap : lineHeight;
  }

  // 5) 材质记忆点
  drawStyleDetail(canvas, brush, pen, style);

  // 6) 落款：页脚右下角，只有「有据」两字（唯一品牌锚点，固定位置固定尺寸）
  const footWidth: number = measureTextWidth(POSTER_FOOT_TEXT, footFont);
  const footAlpha: number = Math.round(255 * style.footOpacity);
  drawText(canvas, brush, footFont, POSTER_FOOT_TEXT, style.boxRight - footWidth, POSTER_FOOT_BASELINE,
    makeColor(footAlpha, ink[0], ink[1], ink[2]));

  return pixelMap;
}

// ───────────────────────── 缩略图 ─────────────────────────

/**
 * 样式选择器用的缩略图。与发布产物同源（同一个 renderPosterPixelMap），
 * 只是缩放倍率换成 POSTER_THUMB_SCALE —— 「选的时候看到什么，发出来就是什么」。
 * 调用方负责 release。
 */
export function renderPosterThumbnail(title: string, content: string, styleKey: string): image.PixelMap {
  return renderPosterPixelMap(title, content, styleKey, POSTER_THUMB_SCALE);
}

// ───────────────────────── 排版完整性判定 ─────────────────────────

/**
 * 判断正文能否在文字海报中完整显示（无截断）。
 *
 * 用最保守的样式（POSTER_CONSERVATIVE_STYLE：文字区最小的那款）作参照：
 * 各款 box 容量不同，而帖子记录里没有存样式，取最小容量只会让详情页「多显示一次正文」
 * （无害），绝不会把没排进去的内容藏起来。
 */
export function doesTextFitInPoster(content: string): boolean {
  const normalized: string = content.replace(/\r/g, '').trim();
  if (normalized.length === 0) {
    return true;
  }
  return !typesetPosterBody(normalized, POSTER_CONSERVATIVE_STYLE).truncated;
}

// ───────────────────────── 编码与上传（沿用既有链路，语义不变） ─────────────────────────

// 复用 renderPosterPixelMap 的绘制（scale=1），把 PixelMap 打包成 JPEG 字节供上传。
async function createPosterBytes(title: string, content: string, _genre: Genre, styleKey?: string): Promise<ArrayBuffer> {
  const pixelMap: image.PixelMap = renderPosterPixelMap(title, content, styleKey, 1);
  try {
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
  return toStoredMediaRef(signature);
}
