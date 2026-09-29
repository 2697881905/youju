// 分享卡片：离屏绘制一张竖版图文卡片（封面 + 标题 + 简介 + 作者 + 品牌 + 二维码），
// 返回 JPEG 字节，供 App 内预览与分享使用。
// 注意：本文件不申请任何权限、不写系统相册；需要保存到相册请走 utils/mediaSave.ets 的免权限通道。
//
// 失败可见性：console.* 在部分机型（H7）不进 hilog，真机抓日志只能看到空。本模块所有
// 诊断输出统一走 hilog；绘制按 stage 推进，异常消息自带失败环节，日志可直接定位。
import { drawing, common2D } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { buildPostShareUrl, downloadToSandbox } from './share';
import { BASE_URL } from '../services/api';
import { splitLines, makeColor, drawText } from './poster/posterText';

const TAG: string = 'shareCard';
const LOG_DOMAIN: number = 0x0000;

const CARD_WIDTH: number = 1080;
const CARD_HEIGHT: number = 1440;
const COVER_HEIGHT: number = 620;
const MAX_TITLE_LINES: number = 2;
const MAX_BODY_LINES: number = 3;
const TEXT_WIDTH: number = 920;
const TEXT_LEFT: number = 72;
// 有据品牌色：纸感浅棕 #8A6548、深墨 #111827、灰 #6B7280（与 design/tokens 保持一致）
const ACCENT: number[] = [138, 101, 72];
const INK: number[] = [17, 24, 39];
const GRAY: number[] = [107, 114, 128];

// 下载封面并解码为 PixelMap；失败返回 null（卡片降级为无封面样式）。
// 取用后立即删除临时封面文件（避免残留小文件干扰系统分享面板预览）。
async function loadCoverPixelMap(context: common.UIAbilityContext, coverUrl: string): Promise<image.PixelMap | null> {
  if (coverUrl.length === 0) {
    return null;
  }
  let tmpPath: string = '';
  try {
    const uri: string = await downloadToSandbox(context, coverUrl);
    tmpPath = uri.startsWith('file://') ? uri.slice('file://'.length) : uri;
    // 经文件描述符建源：createImageSource(uri) 在部分 SDK 会返回 undefined（见 utils/image.ets 同结论）
    const file: fileIo.File = fileIo.openSync(tmpPath, fileIo.OpenMode.READ_ONLY);
    try {
      const source: image.ImageSource = image.createImageSource(file.fd);
      return source.createPixelMapSync();
    } finally {
      fileIo.closeSync(file);
    }
  } catch (e) {
    hilog.warn(LOG_DOMAIN, TAG, '封面加载失败，降级为无封面: %{public}s', String((e as Error).message ?? e));
    return null;
  } finally {
    if (tmpPath.length > 0) {
      try {
        fileIo.unlinkSync(tmpPath);
      } catch (e) {
        hilog.warn(LOG_DOMAIN, TAG, '封面临时文件清理失败: %{public}s', String((e as Error).message ?? e));
      }
    }
  }
}

function coverRectFor(pixelMap: image.PixelMap): common2D.Rect {
  const info: image.ImageInfo = pixelMap.getImageInfoSync();
  const srcW: number = info.size.width;
  const srcH: number = info.size.height;
  const targetRatio: number = CARD_WIDTH / COVER_HEIGHT;
  const srcRatio: number = srcW / srcH;
  let srcX: number = 0;
  let srcY: number = 0;
  let srcWidth: number = srcW;
  let srcHeight: number = srcH;
  if (srcRatio > targetRatio) {
    srcWidth = Math.floor(srcH * targetRatio);
    srcX = Math.round((srcW - srcWidth) / 2);
  } else {
    srcHeight = Math.floor(srcW / targetRatio);
    srcY = Math.round((srcH - srcHeight) / 2);
  }
  return { left: srcX, top: srcY, right: srcX + srcWidth, bottom: srcY + srcHeight };
}

// 顶部封面区：有封面按 Cover 居中裁切；cover 为 null（加载失败/无图）时用品牌色 + 白字「有据」。
// 封面只影响观感，调用方对其异常一律降级，不让整张卡片生成失败。
function drawCover(canvas: drawing.Canvas, brush: drawing.Brush, cover: image.PixelMap | null): void {
  if (cover !== null) {
    canvas.drawImageRectWithSrc(cover, coverRectFor(cover),
      { left: 0, top: 0, right: CARD_WIDTH, bottom: COVER_HEIGHT });
    return;
  }
  brush.setColor(makeColor(255, ACCENT[0], ACCENT[1], ACCENT[2]));
  canvas.attachBrush(brush);
  canvas.drawRect(0, 0, CARD_WIDTH, COVER_HEIGHT);
  const logoFont: drawing.Font = new drawing.Font();
  logoFont.setSize(120);
  logoFont.enableEmbolden(true);
  const logoText: string = '有据';
  const logoWidth: number = logoFont.measureText(logoText, drawing.TextEncoding.TEXT_ENCODING_UTF8);
  drawText(canvas, brush, logoFont, logoText, (CARD_WIDTH - logoWidth) / 2,
    COVER_HEIGHT / 2 + 42, makeColor(255, 255, 255, 255));
}

// 折行兜底：标题/正文的排版失败不该毁掉整卡，退化为单行原文（最多观感变差）。
function safeSplitLines(text: string, font: drawing.Font, maxWidth: number, maxLines: number): string[] {
  try {
    return splitLines(text, font, maxWidth, maxLines);
  } catch (e) {
    hilog.warn(LOG_DOMAIN, TAG, '折行失败，退化为单行: %{public}s', String((e as Error).message ?? e));
    const single: string = text.replace(/\r/g, '').trim();
    return [single.length > 0 ? single : '写下你的观点，让更多人看见。'];
  }
}

// 下载分享落地页二维码并**内存解码**为 PixelMap；失败返回 null（卡片降级无二维码）。
// 不走文件落盘：createImageSource 读 2KB 小文件会触发 FileSourceStream
// desiredSize(10000)>fileSize 异常；直接以 ArrayBuffer 建源即可绕开。
async function loadQrPixelMap(postId: number): Promise<image.PixelMap | null> {
  const client: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await client.request(
      BASE_URL + '/v1/share/qr/post/' + String(postId),
      {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 15000,
      },
    );
    if (resp.responseCode !== 200 || resp.result === undefined) {
      throw new Error('二维码下载 HTTP ' + String(resp.responseCode));
    }
    const source: image.ImageSource = image.createImageSource(resp.result as ArrayBuffer);
    return source.createPixelMapSync();
  } catch (e) {
    hilog.warn(LOG_DOMAIN, TAG, '二维码加载失败，降级为无码: %{public}s', String((e as Error).message ?? e));
    return null;
  } finally {
    client.destroy();
  }
}

// 底层绘制：任一环节抛错都会带上 stage 前缀，日志能直接指出失败环节。
async function createCardBytes(
  context: common.UIAbilityContext,
  postId: number,
  title: string,
  content: string,
  authorName: string,
  coverUrl: string,
): Promise<ArrayBuffer> {
  let stage: string = 'stage1:createPixelMap';
  let pixelMap: image.PixelMap | null = null;
  try {
    const created: image.PixelMap = image.createPixelMapSync({
      size: { width: CARD_WIDTH, height: CARD_HEIGHT },
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: true,
    });
    pixelMap = created;
    stage = 'stage2:newCanvas';
    const canvas: drawing.Canvas = new drawing.Canvas(created);
    const brush: drawing.Brush = new drawing.Brush();

    // 白色卡片底
    stage = 'stage3:background';
    brush.setColor(makeColor(255, 255, 255, 255));
    canvas.attachBrush(brush);
    canvas.drawRect(0, 0, CARD_WIDTH, CARD_HEIGHT);

    // 顶部封面区（加载/裁切失败一律降级为品牌色块）
    stage = 'stage4:cover';
    const cover: image.PixelMap | null = await loadCoverPixelMap(context, coverUrl);
    try {
      drawCover(canvas, brush, cover);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, TAG, '封面绘制失败，降级为无封面: %{public}s', String((e as Error).message ?? e));
      drawCover(canvas, brush, null);
    }
    if (cover !== null) {
      try {
        await cover.release();
      } catch (e) {
        hilog.warn(LOG_DOMAIN, TAG, '封面 PixelMap 释放失败: %{public}s', String((e as Error).message ?? e));
      }
    }

    // 标题（最多 2 行，粗体深墨）
    stage = 'stage5:title';
    const titleFont: drawing.Font = new drawing.Font();
    titleFont.setSize(64);
    titleFont.enableEmbolden(true);
    const titleLines: string[] = safeSplitLines(title, titleFont, TEXT_WIDTH, MAX_TITLE_LINES);
    const titleLineHeight: number = 64 + 18;
    let cursorY: number = COVER_HEIGHT + 96 + titleLineHeight;
    for (const line of titleLines) {
      drawText(canvas, brush, titleFont, line, TEXT_LEFT, cursorY, makeColor(255, INK[0], INK[1], INK[2]));
      cursorY += titleLineHeight;
    }

    // 正文简介（最多 3 行，灰色）
    stage = 'stage6:body';
    const bodyFont: drawing.Font = new drawing.Font();
    bodyFont.setSize(40);
    const bodyLines: string[] = safeSplitLines(content, bodyFont, TEXT_WIDTH, MAX_BODY_LINES);
    const bodyLineHeight: number = 40 + 20;
    cursorY += 30;
    for (const line of bodyLines) {
      drawText(canvas, brush, bodyFont, line, TEXT_LEFT, cursorY, makeColor(255, GRAY[0], GRAY[1], GRAY[2]));
      cursorY += bodyLineHeight;
    }

    // 底部作者 + 品牌
    stage = 'stage7:footer';
    const authorFont: drawing.Font = new drawing.Font();
    authorFont.setSize(40);
    authorFont.enableEmbolden(true);
    const authorText: string = authorName.length > 0 ? authorName : '有据用户';
    drawText(canvas, brush, authorFont, authorText, TEXT_LEFT, CARD_HEIGHT - 148,
      makeColor(255, INK[0], INK[1], INK[2]));
    const brandFont: drawing.Font = new drawing.Font();
    brandFont.setSize(36);
    const brandText: string = '有据 · 真实经验，有据可循';
    const brandWidth: number = brandFont.measureText(brandText, drawing.TextEncoding.TEXT_ENCODING_UTF8);
    drawText(canvas, brush, brandFont, brandText, CARD_WIDTH - TEXT_LEFT - brandWidth, CARD_HEIGHT - 148,
      makeColor(255, ACCENT[0], ACCENT[1], ACCENT[2]));

    // 底部链接
    const linkFont: drawing.Font = new drawing.Font();
    linkFont.setSize(32);
    drawText(canvas, brush, linkFont, buildPostShareUrl(postId), TEXT_LEFT, CARD_HEIGHT - 84,
      makeColor(255, GRAY[0], GRAY[1], GRAY[2]));

    // 右下角二维码：扫一扫直达落地页（卡图 + 扫码 = 微信发图也能跳转）
    stage = 'stage8:qr';
    try {
      const qr: image.PixelMap | null = await loadQrPixelMap(postId);
      if (qr !== null) {
        const qrInfo: image.ImageInfo = qr.getImageInfoSync();
        const qrSize: number = 224;
        const qrX: number = CARD_WIDTH - TEXT_LEFT - qrSize;
        const qrY: number = CARD_HEIGHT - 328;
        canvas.drawImageRectWithSrc(
          qr,
          { left: 0, top: 0, right: qrInfo.size.width, bottom: qrInfo.size.height },
          { left: qrX, top: qrY, right: qrX + qrSize, bottom: qrY + qrSize },
        );
        await qr.release();
      }
    } catch (e) {
      // 二维码绘制失败不影响整卡（降级为无码）
      hilog.warn(LOG_DOMAIN, TAG, 'stage8:qr %{public}s', String((e as Error).message ?? e));
    }

    // 编码：JPEG 失败回退 PNG（个别机型/格式组合下 JPEG 编码会失败，宁可图大也不失败）
    stage = 'stage9:encode';
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      try {
        return await packer.packToData(created, { format: 'image/jpeg', quality: 92 });
      } catch (e) {
        hilog.warn(LOG_DOMAIN, TAG, 'JPEG 编码失败，回退 PNG: %{public}s', String((e as Error).message ?? e));
        return await packer.packToData(created, { format: 'image/png', quality: 100 });
      }
    } finally {
      await packer.release();
    }
  } catch (e) {
    throw new Error(stage + ' ' + String((e as Error).message ?? e));
  } finally {
    if (pixelMap !== null) {
      try {
        await pixelMap.release();
      } catch (e) {
        // 画布释放失败忽略
        hilog.warn(LOG_DOMAIN, TAG, '画布释放失败: %{public}s', String((e as Error).message ?? e));
      }
    }
  }
}

// 生成分享卡图字节（离屏绘制→jpeg 编码）。供 App 内预览/自绘使用，
// 不触碰系统相册/分享弹窗（本设备系统扩展不可用，故分享走「预览+复制链接」路径）。
export async function generateShareCardBytes(
  uiContext: UIContext,
  postId: number,
  title: string,
  content: string,
  authorName: string,
  coverUrl: string,
): Promise<ArrayBuffer> {
  const context: common.UIAbilityContext = uiContext.getHostContext() as common.UIAbilityContext;
  hilog.info(LOG_DOMAIN, TAG, '开始生成卡片 postId=%{public}d 有封面=%{public}s', postId,
    coverUrl.length > 0 ? 'yes' : 'no');
  const bytes: ArrayBuffer = await createCardBytes(context, postId, title, content, authorName, coverUrl);
  hilog.info(LOG_DOMAIN, TAG, '卡片编码完成 字节数=%{public}d', bytes.byteLength);
  return bytes;
}
