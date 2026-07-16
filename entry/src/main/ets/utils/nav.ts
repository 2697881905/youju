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
