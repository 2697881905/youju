// 圈子星图共享布局常量。
// PLANET_BOX_WIDTH / CENTER_AVATAR_SIZE 同时被 CircleTab（外环安全边距计算）
// 与 CircleOrbitCanvas（行星标签盒 / 中心头像渲染）消费，必须取同一来源；
// 任一处各写一份曾导致"注释要求保持一致"却靠人工同步的维护风险。

export class GalaxyTokens {
  // 行星标签盒宽度：标签从 9px 提升到 11px 后放宽命中盒。
  // 过窄会在标签两侧留下无效空白，也会让外环半径的安全边距算错（375vp 边缘裁切）。
  static readonly planetBoxWidth: number = 72;
  // 中心头像尺寸。
  static readonly centerAvatarSize: number = 64;
  // 品牌蓝兜底（string 形态，供 landingAccent() 返回值与 Canvas @Prop 默认值使用）。
  // 与 ColorTokens.brand（ResourceColor）区分：此处需要字符串而非资源引用。
  static readonly brandAccentFallback: string = '#0066CC';
}

// 圈子页沉浸卡片（图例 / Dock）的断点限宽：展开屏满幅会留死白，按断点限宽后由外层居中。
// CircleStarGuide 与 CircleDigestDock 曾各写一份逐字相同的实现，统一为单一函数。
export function immersiveCardWidth(currentBreakpoint: string): Length {
  if (currentBreakpoint === 'lg') {
    return 600;
  }
  if (currentBreakpoint === 'md') {
    return 520;
  }
  return '100%';
}
