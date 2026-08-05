// design token: shadow. ArkUI 单节点仅支持一层 ShadowOptions，card 两层由 BaseCard 叠加。
export class ShadowTokens {
  static readonly none: ShadowOptions = {
    radius: 0,
    color: '#00000000',
    offsetY: 0,
  };

  static readonly cardContact: ShadowOptions = {
    radius: 2,
    color: '#0A000000',
    offsetY: 1,
  };

  static readonly cardAmbient: ShadowOptions = {
    radius: 20,
    color: '#0F000000',
    offsetY: 6,
  };

  static readonly floating: ShadowOptions = {
    radius: 30,
    color: '#1F000000',
    offsetY: 8,
  };
}
