import { UIContext, ShowToastOptions } from '@kit.ArkUI';

// 统一 toast 入口：内部吞掉 showToast 可能抛出的异常，避免各调用点触发 arkts-may-throw。
export function safeShowToast(uiContext: UIContext, options: ShowToastOptions): void {
  try {
    uiContext.getPromptAction().showToast(options);
  } catch (e) {
    // toast 失败不应阻断主流程，静默兜底
  }
}
