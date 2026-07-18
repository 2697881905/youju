// 详情页传参：router.getParams() 在 API 24 已弃用且返回空，改用模块级单例。
// 同 EntryAbility 内页面栈共享该模块，跳转前存 id，详情页取 id。
let _detailPostId: string = '';

export function setDetailPostId(id: string): void {
  _detailPostId = id;
}

export function takeDetailPostId(): string {
  const id = _detailPostId;
  _detailPostId = '';
  return id;
}

// 跨 Tab 跳转信号：子组件调用此函数触发 Index 切换 Tab。
// 用递增序列号保证 @Watch 每次都能触发（@Watch 对同值不触发）。
// 注意：target 必须先写、signal 后写，确保 Index 的 @Watch 回调读到最新 target。
export function emitTabSwitch(target: number): void {
  AppStorage.setOrCreate('tabSwitchTarget', target);
  const seq: number = (AppStorage.get<number>('tabSwitchSignal') ?? 0) + 1;
  AppStorage.setOrCreate('tabSwitchSignal', seq);
}
