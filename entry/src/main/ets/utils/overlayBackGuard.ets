// 页内全屏覆盖层的「返回手势守卫」。
//
// 问题（2026-09-27 用户反馈）：首页 → 帖子详情 → 点图打开图片查看器 → 返回手势
// 直接回到了首页，而不是先关掉查看器回到详情页。
//
// 根因：详情页的图片查看器 / 分享卡预览 / 数据面板，以及私信页的图片 / 视频查看器，
// 都是**页内 if 分支渲染的图层**（zIndex 压过页面内容），不由路由或 Navigation 托管，
// 所以系统返回手势不会先关它们，而是直接 pop 掉整页。
// 更早的代码把拦截写在共享视图组件上（`ChatView.onBackPress`），但 ArkUI 的
// `onBackPress` **只对 @Entry 组件生效** —— 而双壳架构下 DetailPage / ChatPage 是 @Entry、
// PostDetailDestination / ChatDestination 是 NavDestination，共享视图本身两者都不是，
// 那段逻辑从来没被调用过（属于「写了但不生效」的死代码）。
//
// 解法：把「某个覆盖层是否打开 + 怎么关掉」登记成守卫，由**两套壳各自的返回拦截**
// （@Entry 的 onBackPress / NavDestination 的 onBackPressed）统一消费一次。
//
// 约定：
//   · 登记是**幂等**的 —— 持有页在 aboutToAppear 登记一次、aboutToDisappear 注销，
//     不要在每次开关覆盖层时反复登记（少一个「忘了登记」的失败面）。
//   · 回调闭包持有页面实例，必须成对注销，否则会拖住已销毁的页面。
//   · 同一时刻只有一个前台页，但仍按「后登记优先」遍历：栈里下层页面的覆盖层不可能
//     是可见的（它被上层页盖住了），所以取最后一个打开中的即可。

type OverlayProbe = () => boolean;
type OverlayCloser = () => void;

interface OverlayBackGuard {
  id: string;
  isOpen: OverlayProbe;
  close: OverlayCloser;
}

// 守卫登记表（模块级单例，跨双壳共享）
const guards: OverlayBackGuard[] = [];

// 守卫 id 的单一出处，避免各处手写字符串拼错
export const OVERLAY_GUARD_POST_DETAIL: string = 'postDetailView';
export const OVERLAY_GUARD_CHAT: string = 'chatView';

export function registerOverlayBackGuard(id: string, isOpen: OverlayProbe, close: OverlayCloser): void {
  unregisterOverlayBackGuard(id);
  guards.push({ id: id, isOpen: isOpen, close: close });
}

export function unregisterOverlayBackGuard(id: string): void {
  for (let i: number = guards.length - 1; i >= 0; i--) {
    if (guards[i].id === id) {
      guards.splice(i, 1);
    }
  }
}

/**
 * 返回拦截：若某个登记中的覆盖层正打开，关掉它并返回 true
 * （调用方看到 true 就不要再 pop 页面）；没有覆盖层打开时返回 false，让默认返回照常执行。
 */
export function consumeOverlayBack(): boolean {
  for (let i: number = guards.length - 1; i >= 0; i--) {
    const guard: OverlayBackGuard = guards[i];
    if (guard.isOpen()) {
      guard.close();
      return true;
    }
  }
  return false;
}
