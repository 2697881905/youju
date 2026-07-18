// 自定义业务错误类型，用于在 service 层抛出可被路由层精确捕获的异常。
// 相比 (err as any).reason = '...' 的动态挂载方式，class 方式具备类型安全，
// 路由层可用 instanceof 精确判断，IDE 也能提供更好的类型推导与跳转。

/**
 * 敏感词命中错误。
 * 在 postService.createPost / commentService.createComment 中，
 * 当内容触发敏感词检测时抛出，路由层捕获后返回 400 + 友好提示。
 */
export class SensitiveWordError extends Error {
  /** 错误原因标识，供路由层兜底判断（兼容历史动态挂载写法） */
  reason: string = 'sensitive_word';

  constructor(message: string = '内容含敏感词，请修改后重试') {
    super(message);
    this.name = 'SensitiveWordError';
    // 维护正确的原型链（TS 编译到 ES5 target 时 instanceof 可能失效，显式设置可修复）
    Object.setPrototypeOf(this, SensitiveWordError.prototype);
  }
}
