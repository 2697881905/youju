// 分享卡片：离屏绘制一张竖版图文卡片（封面 + 标题 + 简介 + 作者 + 品牌 + 链接），
// 落沙箱后走系统分享面板（general.image）。小红书式图文分享，不带二维码（避免引入依赖）。
import { drawing, common2D } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { common, abilityAccessCtrl, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { buildPostShareUrl, downloadToSandbox } from './share';
import { BASE_URL } from '../services/api';
import { splitLines, makeColor, drawText } from './textPoster';

const CARD_WIDTH: number = 1080;
const CARD_HEIGHT: number = 1440;
const COVER_HEIGHT: number = 620;
const MAX_TITLE_LINES: number = 2;
const MAX_BODY_LINES: number = 3;
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
  let source: image.ImageSource | null = null;
  try {
    const uri: string = await downloadToSandbox(context, coverUrl);
    tmpPath = uri.startsWith('file://') ? uri.slice('file://'.length) : uri;
    source = image.createImageSource(uri);
    return source.createPixelMapSync();
  } catch (e) {
    return null;
  } finally {
    if (tmpPath.length > 0) {
      try {
        fileIo.unlinkSync(tmpPath);
      } catch (e) {
        console.warn('[shareCard] 封面临时文件清理失败:', e);
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
    srcWidth = srcH * targetRatio;
    srcX = Math.round((srcW - srcWidth) / 2);
  } else {
    srcHeight = srcW / targetRatio;
    srcY = Math.round((srcH - srcHeight) / 2);
  }
  return { left: srcX, top: srcY, right: srcX + srcWidth, bottom: srcY + srcHeight };
}

// 下载分享落地页二维码并**内存解码**为 PixelMap；失败返回 null（卡片降级无二维码）。
// 不走文件落盘：createImageSource 读 2KB 小文件会触发 FileSourceStream
// desiredSize(10000)>fileSize 异常；直接以 ArrayBuffer 建源即可绕开。
async function loadQrPixelMap(context: common.UIAbilityContext, postId: number): Promise<image.PixelMap | null> {
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
    console.warn('[shareCard] 二维码加载失败:', e);
    return null;
  } finally {
    client.destroy();
  }
}

async function createCardBytes(
  context: common.UIAbilityContext,
  postId: number,
  title: string,
  content: string,
  authorName: string,
  coverUrl: string,
): Promise<ArrayBuffer> {
  let pixelMap: image.PixelMap;
  try {
    pixelMap = image.createPixelMapSync({
      size: { width: CARD_WIDTH, height: CARD_HEIGHT },
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: true,
    });
  } catch (e) {
    throw new Error('stage1:createPixelMap ' + String((e as Error).message ?? e));
  }
  const canvas: drawing.Canvas = new drawing.Canvas(pixelMap);
  const brush: drawing.Brush = new drawing.Brush();
  try {
    // 白色卡片底
    brush.setColor(makeColor(255, 255, 255, 255));
    canvas.attachBrush(brush);
    canvas.drawRect(0, 0, CARD_WIDTH, CARD_HEIGHT);

    // 顶部封面区：有封面按 Cover 居中裁切；无封面用品牌蓝 + 白字「有据」
    try {
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
    } catch (e) {
      throw new Error('stage2:cover ' + String((e as Error).message ?? e));
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

    // 右下角二维码：扫一扫直达落地页（卡图 + 扫码 = 微信发图也能跳转）
    try {
      const qr: image.PixelMap | null = await loadQrPixelMap(context, postId);
      if (qr !== null) {
        const qrInfo: image.ImageInfo = qr.getImageInfoSync();
        const qrSize: number = 224;
        const qrX: number = CARD_WIDTH - 72 - qrSize;
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
      console.warn('[shareCard] stage4:qr ' + String((e as Error).message ?? e));
    }

    const packer: image.ImagePacker = image.createImagePacker();
    try {
      try {
        return await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 92 });
      } catch (e) {
        throw new Error('stage5:packToData ' + String((e as Error).message ?? e));
      }
    } finally {
      await packer.release();
    }
  } finally {
    try {
      await pixelMap.release();
    } catch (e) {
      // 画布释放失败忽略
      console.warn('[shareCard] pixelMap release: ' + String((e as Error).message ?? e));
    }
  }
}

// 系统分享面板预览子进程可能读取应用沙箱 filesDir 的媒体文件；历史残留的
// 小文件（二维码 png / 旧封面 jpg）会触发 FileSourceStream 异常导致面板崩溃。
// 分享面板弹出前清空 filesDir 里除当前卡片外的图片残留。
function cleanResidualFiles(context: common.UIAbilityContext, keepFile: string): void {
  try {
    const names: string[] = fileIo.listFileSync(context.filesDir);
    const keepBase: string = keepFile.slice(keepFile.lastIndexOf('/') + 1);
    for (const name of names) {
      if (name === keepBase) {
        continue;
      }
      if (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg')) {
        try {
          fileIo.unlinkSync(context.filesDir + '/' + name);
        } catch (e) {
          console.warn('[shareCard] 残留清理失败 ' + name + ' ' + String((e as Error).message ?? e));
        }
      }
    }
  } catch (e) {
    console.warn('[shareCard] listFileSync 不可用，跳过残留清理: ' + String((e as Error).message ?? e));
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
  console.info('[shareCard] 开始生成卡片');
  const bytes: ArrayBuffer = await createCardBytes(context, postId, title, content, authorName, coverUrl);
  console.info('[shareCard] 卡片编码完成, 字节数=' + bytes.byteLength);
  return bytes;
}

// 帖子分享卡片：生成卡片图 → 请求相册写权限 → createAsset 静默写入系统图库
// （抖音/小红书式）。不做 systemShare 面板、也不用 showAssetsCreationDialog：
// 本环境这两个系统弹窗扩展均告超时/崩溃（DMS session 失效、extension_lifecycle_timeout），
// 唯一可靠通道是受控权限 + createAsset 直写（首次仅一次系统授权弹窗）。
// 返回 true=已保存到相册；false=用户未授予权限。
export async function sharePostCardToSystem(
  uiContext: UIContext,
  postId: number,
  title: string,
  content: string,
  authorName: string,
  coverUrl: string,
): Promise<boolean> {
  const context: common.UIAbilityContext = uiContext.getHostContext() as common.UIAbilityContext;
  console.info('[shareCard] 开始生成卡片');
  const bytes: ArrayBuffer = await createCardBytes(context, postId, title, content, authorName, coverUrl);
  console.info('[shareCard] 卡片编码完成, 字节数=' + bytes.byteLength);

  // 相册写权限（受控权限：首次拉起系统授权框，之后静默）
  const atManager = abilityAccessCtrl.createAtManager();
  try {
    const req: PermissionRequestResult = await atManager.requestPermissionsFromUser(context,
      ['ohos.permission.WRITE_IMAGEVIDEO'] as Array<Permissions>);
    const granted: number = (req.authResults ?? [])[0] ?? -1;
    if (granted !== 0) {
      console.info('[shareCard] 用户未授予相册写权限');
      return false;
    }
  } catch (e) {
    console.error('[shareCard] 请求相册权限异常: ' + String((e as Error).message ?? e));
    return false;
  }

  // createAsset 创建图库资产 → 直接写入字节（无系统保存弹窗）
  try {
    const phHelper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
    const opts: photoAccessHelper.CreateOptions = { title: 'youju_' + Date.now() };
    const uri: string = await phHelper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg', opts);
    const file = fileIo.openSync(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, bytes);
    fileIo.closeSync(file);
    console.info('[shareCard] 卡片已保存到相册 uri=' + uri);
    return true;
  } catch (e) {
    console.error('[shareCard] 写入相册失败: ' + String((e as Error).message ?? e));
    throw new Error('保存到相册失败：' + String((e as Error).message ?? e));
  }
}
