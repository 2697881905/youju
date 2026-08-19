// 聊天媒体保存到系统图库：
// 1) 下载媒体（resolveDisplayImageUrl 后的直链）到应用沙箱临时文件
// 2) showAssetsCreationDialog 唤起系统保存确认弹窗（API 12+，无需图库写权限）
// 用户确认后媒体落入图库（图片/视频均支持）；取消返回空数组（静默处理）。
import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { resolveDisplayImageUrl } from '../services/api';

// 下载媒体到沙箱 save 目录，返回 file:// URI；失败抛错
async function downloadToSandbox(context: common.UIAbilityContext, url: string, ext: string): Promise<string> {
  const client: http.HttpRequest = http.createHttp();
  try {
    const resp: http.HttpResponse = await client.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: 15000,
      readTimeout: 60000,
    });
    if (resp.responseCode !== 200 || resp.result === undefined) {
      throw new Error('下载媒体失败 HTTP ' + String(resp.responseCode));
    }
    const buffer: ArrayBuffer = resp.result as ArrayBuffer;
    const dir: string = context.filesDir + '/save';
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
    const filePath: string = dir + '/' + util.generateRandomUUID() + '.' + ext;
    const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
    fileIo.writeSync(file.fd, buffer);
    fileIo.closeSync(file);
    return 'file://' + filePath;
  } finally {
    client.destroy();
  }
}

// 保存聊天媒体（type: 'image' | 'video'）到系统图库。
// 返回 true=已保存；false=用户在系统弹窗中取消；失败抛错（调用方 toast 兜底）。
export async function saveChatMediaToGallery(
  uiContext: UIContext,
  mediaUrl: string,
  type: string,
): Promise<boolean> {
  const context: common.UIAbilityContext = uiContext.getHostContext() as common.UIAbilityContext;
  const isVideo: boolean = type === 'video';
  const ext: string = isVideo ? 'mp4' : 'jpg';
  const fileUri: string = await downloadToSandbox(context, resolveDisplayImageUrl(mediaUrl), ext);
  const phHelper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
  const config: photoAccessHelper.PhotoCreationConfig = {
    // 系统按扩展名与类型创建资产；标题用时间戳便于用户在图库识别
    title: 'youju_' + Date.now(),
    fileNameExtension: ext,
    photoType: isVideo ? photoAccessHelper.PhotoType.VIDEO : photoAccessHelper.PhotoType.IMAGE,
  };
  const created: Array<string> = await phHelper.showAssetsCreationDialog([fileUri], [config]);
  // 返回已创建资产的 uri 列表：非空=已保存，空数组=用户取消
  return created.length > 0;
}
