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
}
