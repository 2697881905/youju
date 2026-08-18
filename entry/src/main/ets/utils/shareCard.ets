// 分享卡片：离屏绘制一张竖版图文卡片（封面 + 标题 + 简介 + 作者 + 品牌 + 链接），
// 落沙箱后走系统分享面板（general.image）。小红书式图文分享，不带二维码（避免引入依赖）。
import { drawing, common2D } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { systemShare } from '@kit.ShareKit';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { buildPostShareUrl, downloadToSandbox } from './share';
import { splitLines, makeColor, drawText } from './textPoster';

const CARD_WIDTH: number = 1080;
const CARD_HEIGHT: number = 1440;
const COVER_HEIGHT: number = 620;
const MAX_TITLE_LINES: number = 2;
const MAX_BODY_LINES: number = 3;
// 有据品牌色：蓝 #1677FF、深墨 #111827、灰 #6B7280（与 design/tokens 保持一致）
const ACCENT: number[] = [22, 119, 255];
const INK: number[] = [17, 24, 39];
const GRAY: number[] = [107, 114, 128];

// 下载封面并解码为 PixelMap；失败返回 null（卡片降级为无封面样式）
async function loadCoverPixelMap(context: common.UIAbilityContext, coverUrl: string): Promise<image.PixelMap | null> {
  if (coverUrl.length === 0) {
    return null;
  }
  let source: image.ImageSource | null = null;
  try {
    const uri: string = await downloadToSandbox(context, coverUrl);
    source = image.createImageSource(uri);
    return source.createPixelMapSync();
  } catch (e) {
    return null;
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
    srcWidth = srcH * targetRatio;
    srcX = Math.round((srcW - srcWidth) / 2);
  } else {
    srcHeight = srcW / targetRatio;
    srcY = Math.round((srcH - srcHeight) / 2);
  }
  return { left: srcX, top: srcY, right: srcX + srcWidth, bottom: srcY + srcHeight };
}

async function createCardBytes(
  context: common.UIAbilityContext,
  postId: number,
  title: string,
  content: string,
  authorName: string,
  coverUrl: string,
): Promise<ArrayBuffer> {
  const pixelMap: image.PixelMap = image.createPixelMapSync({
    size: { width: CARD_WIDTH, height: CARD_HEIGHT },
    pixelFormat: image.PixelMapFormat.RGBA_8888,
    editable: true,
  });
  const canvas: drawing.Canvas = new drawing.Canvas(pixelMap);
  const brush: drawing.Brush = new drawing.Brush();
  try {
    // 白色卡片底
    brush.setColor(makeColor(255, 255, 255, 255));
    canvas.attachBrush(brush);
    canvas.drawRect(0, 0, CARD_WIDTH, CARD_HEIGHT);

    // 顶部封面区：有封面按 Cover 居中裁切；无封面用品牌蓝 + 白字「有据」
    const cover: image.PixelMap | null = await loadCoverPixelMap(context, coverUrl);
    if (cover !== null) {
      canvas.drawImageRectWithSrc(cover, coverRectFor(cover), { left: 0, top: 0, right: CARD_WIDTH, bottom: COVER_HEIGHT });
      await cover.release();
    } else {
      brush.setColor(makeColor(255, ACCENT[0], ACCENT[1], ACCENT[2]));
      canvas.attachBrush(brush);
      canvas.drawRect(0, 0, CARD_WIDTH, COVER_HEIGHT);
      const logoFont: drawing.Font = new drawing.Font();
      logoFont.setSize(120);
      logoFont.enableEmbolden(true);
      const logoText: string = '有据';
      const logoWidth: number = logoFont.measureText(logoText, drawing.TextEncoding.TEXT_ENCODING_UTF8);
      drawText(canvas, brush, logoFont, logoText, (CARD_WIDTH - logoWidth) / 2, COVER_HEIGHT / 2 + 42, makeColor(255, 255, 255, 255));
    }

    // 标题（最多 2 行，粗体深墨）
    const titleFont: drawing.Font = new drawing.Font();
    titleFont.setSize(64);
    titleFont.enableEmbolden(true);
    const titleLines: string[] = splitLines(title, titleFont, 920, MAX_TITLE_LINES);
    const titleLineHeight: number = 64 + 18;
    let cursorY: number = COVER_HEIGHT + 96 + titleLineHeight;
    for (const line of titleLines) {
      drawText(canvas, brush, titleFont, line, 72, cursorY, makeColor(255, INK[0], INK[1], INK[2]));
      cursorY += titleLineHeight;
    }

    // 正文简介（最多 3 行，灰色）
    const bodyFont: drawing.Font = new drawing.Font();
    bodyFont.setSize(40);
    const bodyLines: string[] = splitLines(content, bodyFont, 920, MAX_BODY_LINES);
    const bodyLineHeight: number = 40 + 20;
    cursorY += 30;
    for (const line of bodyLines) {
      drawText(canvas, brush, bodyFont, line, 72, cursorY, makeColor(255, GRAY[0], GRAY[1], GRAY[2]));
      cursorY += bodyLineHeight;
    }

    // 底部作者 + 品牌
    const authorFont: drawing.Font = new drawing.Font();
    authorFont.setSize(40);
    authorFont.enableEmbolden(true);
    const authorText: string = authorName.length > 0 ? authorName : '有据用户';
    drawText(canvas, brush, authorFont, authorText, 72, CARD_HEIGHT - 148, makeColor(255, INK[0], INK[1], INK[2]));
    const brandFont: drawing.Font = new drawing.Font();
    brandFont.setSize(36);
    const brandText: string = '有据 · 真实经验，有据可循';
    const brandWidth: number = brandFont.measureText(brandText, drawing.TextEncoding.TEXT_ENCODING_UTF8);
    drawText(canvas, brush, brandFont, brandText, CARD_WIDTH - 72 - brandWidth, CARD_HEIGHT - 148, makeColor(255, ACCENT[0], ACCENT[1], ACCENT[2]));

    // 底部链接
    const linkFont: drawing.Font = new drawing.Font();
    linkFont.setSize(32);
    drawText(canvas, brush, linkFont, buildPostShareUrl(postId), 72, CARD_HEIGHT - 84, makeColor(255, GRAY[0], GRAY[1], GRAY[2]));

    const packer: image.ImagePacker = image.createImagePacker();
    try {
      return await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 92 });
    } finally {
      await packer.release();
    }
  } finally {
    await pixelMap.release();
  }
}

// 帖子分享卡片：生成卡片图 → 写沙箱 → 系统分享面板（单图片记录，卡片内已含标题/作者/链接）
export async function sharePostCardToSystem(
  uiContext: UIContext,
  postId: number,
  title: string,
  content: string,
  authorName: string,
  coverUrl: string,
): Promise<void> {
  const context: common.UIAbilityContext = uiContext.getHostContext() as common.UIAbilityContext;
  console.info('[shareCard] 开始生成卡片');
  const bytes: ArrayBuffer = await createCardBytes(context, postId, title, content, authorName, coverUrl);
  console.info('[shareCard] 卡片编码完成, 字节数=' + bytes.byteLength);
  const dir: string = context.filesDir + '/share';
  // mkdirSync 在目录已存在时会抛 File exists，先探测再创建
  let dirExists: boolean = false;
  try {
    fileIo.accessSync(dir);
    dirExists = true;
  } catch (e) {
    dirExists = false;
  }
  if (!dirExists) {
    fileIo.mkdirSync(dir, true);
  }
  const filePath: string = dir + '/card-' + util.generateRandomUUID() + '.jpg';
  const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
  fileIo.writeSync(file.fd, bytes);
  fileIo.closeSync(file);
  console.info('[shareCard] 已写入沙箱: ' + filePath);
  const record: systemShare.SharedRecord = {
    utd: 'general.image',
    uri: 'file://' + filePath,
    title: title && title.length > 0 ? '有据 · ' + title : '有据帖子',
  };
  const data: systemShare.SharedData = new systemShare.SharedData(record);
  const controller: systemShare.ShareController = new systemShare.ShareController(data);
  try {
    await controller.show(context, {
      selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT,
    });
  } catch (e) {
    const message: string = (e as Error).message ?? String(e);
    console.error('[shareCard] show 分享面板失败: ' + message);
    throw new Error('系统分享面板打开失败：' + message);
  }
}
