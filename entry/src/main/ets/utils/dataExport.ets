import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { util } from '@kit.ArkTS';
import { UserExportData } from '../models/types';

function ensureDirectory(directory: string): void {
  try {
    fileIo.accessSync(directory);
  } catch (e) {
    fileIo.mkdirSync(directory, true);
  }
}

function exportFileName(exportedAt: string): string {
  const safeTime: string = exportedAt.replace(/[:.]/g, '-');
  return 'youju-data-export-' + safeTime + '.json';
}

// 将后端已鉴权返回的数据写入缓存文件，并交给系统分享面板保存或发送。
export async function shareUserDataExport(uiContext: UIContext, data: UserExportData): Promise<void> {
  const context: common.UIAbilityContext = uiContext.getHostContext() as common.UIAbilityContext;
  const directory: string = context.cacheDir + '/exports';
  ensureDirectory(directory);
  const path: string = directory + '/' + exportFileName(data.exportedAt);
  const encoder: util.TextEncoder = new util.TextEncoder();
  const bytes: Uint8Array = encoder.encode(JSON.stringify(data, null, 2));
  const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
  try {
    fileIo.truncateSync(file.fd, 0);
    fileIo.writeSync(file.fd, bytes.buffer);
  } finally {
    fileIo.closeSync(file);
  }

  const record: systemShare.SharedRecord = {
    utd: 'general.file',
    uri: 'file://' + path,
    title: '有据个人数据导出',
    description: 'JSON 数据导出文件',
  };
  const controller: systemShare.ShareController = new systemShare.ShareController(new systemShare.SharedData(record));
  await controller.show(context, {
    selectionMode: systemShare.SelectionMode.SINGLE,
    previewMode: systemShare.SharePreviewMode.DEFAULT,
  });
}
