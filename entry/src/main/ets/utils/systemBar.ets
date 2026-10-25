// 系统栏内容色的"补设"通道：HDS 标题栏在挂载期与滚动特效回位（滚回顶部）时会回写
// 系统栏属性，把应用按自身主题显式设置的 statusBarContentColor/isStatusBarLightIcon
// 覆盖成按**系统**深浅渲染（系统深+应用浅的组合态下渲成白色，浅色画布上不可见——
// 真机实证 2026-10-25，两次复现）。SDK 无关停该联动的人口（只有整体隐藏的 hideStatusBar），
// 只能在每次被覆盖后补设。入口统一收敛在此：滚动宿主在"偏移回到 0"时调
// requestSystemBarRefresh()，400ms 去抖后由 EntryAbility 注册的刷新器补设一次
//（必须晚于 HDS 的回写帧，立即补设会被下一帧覆盖——同挂载期 3s 补设的教训）。
let refresher: (() => void) | null = null;
// 多段连发时刻：HDS 的回写发生在回弹沉降后、时刻不定（真机两次复现分别在 <0.6s 与 ~2.9s，
// 与单发 400ms 去抖构成竞速，有输有赢）。连发四发、最后一发 3s——与挂载期 3s 补设同刻，
// 任何 ≤3s 的回写都会被最后一发压住；HDS 回写只发生一次，连发不会互相打架。
const REFRESH_SHOTS_MS: number[] = [400, 1000, 1800, 3000];
let pendingTimers: number[] = [];

export function setSystemBarRefresher(fn: () => void): void {
  refresher = fn;
}

export function requestSystemBarRefresh(): void {
  for (const t of pendingTimers) {
    clearTimeout(t);
  }
  pendingTimers = [];
  for (const delay of REFRESH_SHOTS_MS) {
    const id: number = setTimeout((): void => {
      if (refresher !== null) {
        refresher();
      }
      pendingTimers = pendingTimers.filter((t: number): boolean => t !== id);
    }, delay) as number;
    pendingTimers.push(id);
  }
}
