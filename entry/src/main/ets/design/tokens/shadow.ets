// design token: shadow. ArkUI 单节点仅支持一层 ShadowOptions，card 两层由 BaseCard 叠加。
export class ShadowTokens {
  static readonly none: ShadowOptions = {
    radius: 0,
    color: '#00000000',
    offsetY: 0,
  };

  static readonly cardContact: ShadowOptions = {
    radius: 1,
    color: '#08000000',
    offsetY: 0,
  };

  static readonly cardAmbient: ShadowOptions = {
    radius: 10,
    color: '#12000000',
    offsetY: 3,
  };

  static readonly floating: ShadowOptions = {
    radius: 16,
    color: '#18000000',
    offsetY: 6,
  };

  // 媒体下方信息条：向上的柔光投影，让信息条看起来是压在封面之上的独立纸片。
  // radius 给足 12 且 offsetY 只 -4：即使某些版本对负 offsetY 处理保守（钳成 0），
  // 12 的模糊半径本身仍会向上溢出 12vp，"立体感"不会整段丢失 —— 这是刻意的降级设计。
  static readonly stripTop: ShadowOptions = {
    radius: 12,
    color: '#1A000000',
    offsetY: -4,
  };
}
