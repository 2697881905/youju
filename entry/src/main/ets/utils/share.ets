// 分享工具：链接构建 / 剪贴板 / 系统分享面板（Share Kit）。
// 生产分享落地页挂在主站根域 youju.chat（post/{id}、user/{id} 静态页由 nginx 提供）。
import pasteboard from '@ohos.pasteboard';
import { systemShare } from '@kit.ShareKit';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

// 分享落地页主站根域（非 API 子域）。分享出去给好友点击即打开对应帖子/主页落地页。
const SHARE_BASE: string = 'https://youju.chat';

export const EXTERNAL_SHARE_ENABLED: boolean = true;

// 站内「分享到私信」始终可用（不依赖外部分享落地页/系统分享面板），由分享面板单独展示。
export const DM_SHARE_ENABLED: boolean = true;

// 帖子分享链接：占位域名 + /post/{id}
export function buildPostShareUrl(postId: number): string {
  return SHARE_BASE + '/post/' + String(postId);
}

// 个人主页分享链接：占位域名 + /user/{id}
export function buildProfileShareUrl(userId: number): string {
  return SHARE_BASE + '/user/' + String(userId);
}

// 分享文案（标题 + 链接），用于系统分享面板接入后使用
export function buildShareText(title: string, postId: number): string {
  const t: string = title && title.length > 0 ? title : '有据帖子';
  return t + ' ' + buildPostShareUrl(postId);
}

export function buildProfileShareText(nickname: string, userId: number): string {
  const name: string = nickname && nickname.length > 0 ? nickname : '有据用户';
  return '来有据看看 ' + name + ' 的个人主页 ' + buildProfileShareUrl(userId);
}

// 复制文本到系统剪贴板；失败抛出，由调用方 toast 兜底
export function copyToClipboard(text: string): void {
  const pb = pasteboard.getSystemPasteboard();
  pb.setData(pasteboard.createPlainTextData(text));
}

// 下载网络图到应用沙箱（系统分享图片记录要求 file:// 沙箱 URI），返回 file:// URI；失败抛错
export async function downloadToSandbox(context: common.UIAbilityContext, url: string): Promise<string> {
  const client: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await client.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: 15000,
      readTimeout: 15000,
    });
    if (resp.responseCode !== 200 || resp.result === undefined) {
      throw new Error('下载封面失败 HTTP ' + String(resp.responseCode));
    }
    const buffer: ArrayBuffer = resp.result as ArrayBuffer;
    // 直接写 filesDir 根目录（不建子目录：某些 API 上子目录 accessSync 可通过但
    // openSync 却报 ENOENT，写法上子目录不可靠）
    const dir: string = context.filesDir;
    const ext: string = url.indexOf('.png') >= 0 ? 'png' : 'jpg';
    const filePath: string = dir + '/' + util.generateRandomUUID() + '.' + ext;
    let file: fileIo.File | undefined;
    try {
      file = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    } catch (e) {
      console.error('[share] openSync失败 path=' + filePath + ' msg=' + String((e as Error).message ?? e));
      throw new Error('openSync ' + filePath + ' ' + String((e as Error).message ?? e));
    }
    fileIo.writeSync(file.fd, buffer);
    fileIo.closeSync(file);
    return 'file://' + filePath;
  } finally {
    client.destroy();
  }
}

// 帖子系统分享：仅发送独占一行的链接（buildPostShareUrl）。
// 微信判定「消息体 = 单个链接」才会自动抓取落地页 OG 并渲染成
// 标题+摘要+封面的富卡片（抖音/小红书式）。若混入标题文字则退化为
// 普通文本（只显示「标题 链接」）。标题展示交给微信抓取的 og:title。
export async function sharePostToSystem(uiContext: UIContext, postId: number, title: string, coverUrl: string): Promise<void> {
  const context: common.UIAbilityContext = uiContext.getHostContext() as common.UIAbilityContext;
  const textRecord: systemShare.SharedRecord = {
    utd: 'general.text',
    content: buildPostShareUrl(postId),
    title: title && title.length > 0 ? title : '有据帖子',
    description: '来自有据',
  };
  const data: systemShare.SharedData = new systemShare.SharedData(textRecord);
  const controller: systemShare.ShareController = new systemShare.ShareController(data);
  await controller.show(context, {
    selectionMode: systemShare.SelectionMode.SINGLE,
    previewMode: systemShare.SharePreviewMode.DEFAULT,
  });
}

// 个人主页系统分享：仅发送独占一行的链接（buildProfileShareUrl），
// 微信抓取 user/{id} 落地页 OG 渲染个人主页卡片。
export async function shareProfileToSystem(uiContext: UIContext, nickname: string, userId: number): Promise<void> {
  const context: common.UIAbilityContext = uiContext.getHostContext() as common.UIAbilityContext;
  const textRecord: systemShare.SharedRecord = {
    utd: 'general.text',
    content: buildProfileShareUrl(userId),
    title: '有据 · ' + (nickname && nickname.length > 0 ? nickname : '个人主页'),
    description: '来自有据',
  };
  const data: systemShare.SharedData = new systemShare.SharedData(textRecord);
  const controller: systemShare.ShareController = new systemShare.ShareController(data);
  await controller.show(context, {
    selectionMode: systemShare.SelectionMode.SINGLE,
    previewMode: systemShare.SharePreviewMode.DEFAULT,
  });
}
