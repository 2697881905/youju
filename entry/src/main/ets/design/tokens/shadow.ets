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

  // 玻璃小胶囊的落影（Dock 选中指示器）：比 floating 收紧一档 —— 52vp 高的件撑不起 16 半径
  // 6 下移的大影，参照图里胶囊下方是一条贴得很近的窄影，靠它把玻璃从 Dock 面上抬起来。
  static readonly pillFloat: ShadowOptions = {
    radius: 8,
    color: '#26000000',
    offsetY: 3,
  };
}
