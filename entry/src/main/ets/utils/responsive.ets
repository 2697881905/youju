// 响应式网格工具：把全局断点（utils/breakpointCenter.ets）映射为卡片列数。
// 断点源唯一：窗口尺寸监听全 app 只在 breakpointCenter 注册一处；本文件只做「断点 → 列数」
// 纯映射，消费方用 @StorageProp('currentBreakpoint') @Watch 消费，不再各自注册 windowSizeChange。
//
//   手机竖屏 sm (<600vp)             → 2 列
//   折叠屏展开/平板竖屏 md (600-839) → 3 列
//   平板横屏/桌面 lg (>=840)         → 4 列

// 断点 → 网格列数（档位与 breakpointCenter 一一对应）
export function gridColumnsForBreakpoint(bp: string): number {
  if (bp === 'lg') {
    return 4;
  }
  if (bp === 'md') {
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