// 响应式网格工具：根据屏幕宽度计算卡片列数，并监听窗口尺寸变化（折叠屏/平板/旋转）
// 用途：让首页/个人主页/搜索/圈子的卡片网格在不同屏幕尺寸下列数自适应，避免溢出或布局错乱

import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

// 根据屏幕物理宽度（px）计算网格列数
//   手机竖屏 (<600vp)        → 2 列
//   折叠屏展开/平板竖屏       → 3 列
//   平板横屏/桌面 (>840vp)    → 4 列
function computeGridColumns(widthPx: number): number {
  const wvp: number = px2vp(widthPx);
  if (wvp >= 840) {
    return 4;
  }
  if (wvp >= 600) {
    return 3;
  }
  return 2;
}

// 生成 Grid 的 columnsTemplate 字符串，例如 3 列 → '1fr 1fr 1fr'
export function gridColumnTemplate(cols: number): string {
  let tpl: string = '';
  for (let i: number = 0; i < cols; i++) {
    if (i > 0) {
      tpl += ' ';
    }
    tpl += '1fr';
  }
  return tpl;
}

// 注册窗口尺寸监听：尺寸变化时通过 onChange 回传最新列数；返回注销函数，须在 aboutToDisappear 调用
// ArkTS V1 约束：回调用具名函数类型 (size: window.Size) => void，禁止内联对象字面量
export function observeGridColumns(ctx: common.Context, onChange: (cols: number) => void): () => void {
  let handler: ((size: window.Size) => void) | undefined = undefined;
  window.getLastWindow(ctx)
    .then((win: window.Window) => {
      const rect = win.getWindowProperties().windowRect;
      onChange(computeGridColumns(rect.width));
      handler = (size: window.Size): void => {
        onChange(computeGridColumns(size.width));
      };
      win.on('windowSizeChange', handler);
    })
    .catch(() => {
      onChange(2);
    });
  return (): void => {
    if (handler !== undefined) {
      window.getLastWindow(ctx)
        .then((win: window.Window) => {
          win.off('windowSizeChange', handler);
        })
        .catch(() => { /* 忽略注销失败 */ });
    }
  };
}
