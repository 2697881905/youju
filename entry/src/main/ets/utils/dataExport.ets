import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { UserExportData } from '../models/types';

const LOG_DOMAIN: number = 0xFF10;
const LOG_TAG: string = 'YouJuExport';

function exportFileName(exportedAt: string): string {
  const safeTime: string = exportedAt.replace(/[:.]/g, '-');
  return 'youju-data-export-' + safeTime + '.json';
}

// 将后端已鉴权返回的数据写入缓存文件，并交给系统分享面板保存或发送。
// 各阶段失败抛出带阶段标记的错误（[导出-文件]/[导出-分享]），toast 可直接定位环节；
// 同时打 hilog（-remove-log 只删 console，hilog 保留）便于真机 hdc 排查。
// ⚠️ 文件直接写 cacheDir 根目录：真机实测 fileIo.mkdirSync(recursion) 创建
// cache/exports 子目录静默失效 → openSync ENOENT（「导出失败」真因，2026-09-12 真机实锤）。
// cacheDir 本身必定存在，不建子目录就没有创建环节。
export async function shareUserDataExport(uiContext: UIContext, data: UserExportData): Promise<void> {
  const context: common.UIAbilityContext = uiContext.getHostContext() as common.UIAbilityContext;
  let path: string = context.cacheDir + '/' + exportFileName(data.exportedAt);
  try {
    const encoder: util.TextEncoder = new util.TextEncoder();
    const bytes: Uint8Array = encoder.encode(JSON.stringify(data, null, 2));
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
    try {
      fileIo.truncateSync(file.fd, 0);
      fileIo.writeSync(file.fd, bytes.buffer);
    } finally {
      fileIo.closeSync(file);
    }
  } catch (e) {
    hilog.error(LOG_DOMAIN, LOG_TAG, 'file stage failed: %{public}s path=%{public}s',
      (e as Error).message, path);
    throw new Error('[导出-写文件] ' + (e as Error).message);
  }

  try {
    // 审核问题②修复：文件 URI 必须经 fileUri.getUriFromPath 生成（自带 file://<bundleName> authority）。
    // 手拼 'file://' + path 缺少 bundle authority，是非法 URI，系统分享面板会直接抛错导致「导出失败」。
    const shareableUri: string = fileUri.getUriFromPath(path);
    const record: systemShare.SharedRecord = {
      utd: 'general.file',
      uri: shareableUri,
      title: '有据个人数据导出',
      description: 'JSON 数据导出文件',
    };
    const controller: systemShare.ShareController = new systemShare.ShareController(new systemShare.SharedData(record));
    await controller.show(context, {
      selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT,
    });
  } catch (e) {
    hilog.error(LOG_DOMAIN, LOG_TAG, 'share stage failed: %{public}s uri=%{public}s',
      (e as Error).message, fileUri.getUriFromPath(path));
    throw new Error('[导出-分享面板] ' + (e as Error).message);
  }
}
