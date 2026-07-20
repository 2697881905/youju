// 响应式断点系统：根据窗口宽度返回适配参数
// 用于 Grid 列数、字体缩放、间距调整等

// 断点定义
const BREAKPOINT_SM = 600;   // vp: 手机竖屏
const BREAKPOINT_MD = 840;   // vp: 手机横屏 / 平板竖屏
const BREAKPOINT_LG = 1024;  // vp: 平板横屏 / 桌面

export enum Breakpoint {
  SM = 'sm',
  MD = 'md',
  LG = 'lg',
}

// 根据窗口宽度获取当前断点
export function getBreakpoint(width: number): Breakpoint {
  if (width < BREAKPOINT_SM) {
    return Breakpoint.SM;
  }
  if (width < BREAKPOINT_MD) {
    return Breakpoint.MD;
  }
  return Breakpoint.LG;
}

// 根据断点获取 Grid 列数
export function getGridColumns(bp: Breakpoint): number {
  switch (bp) {
    case Breakpoint.SM:
      return 2;
    case Breakpoint.MD:
      return 3;
    case Breakpoint.LG:
      return 4;
    default:
      return 2;
  }
}

// 根据断点获取 Grid 列模板字符串
export function getGridTemplate(bp: Breakpoint): string {
  const cols: number = getGridColumns(bp);
  return '1fr '.repeat(cols).trim();
}
