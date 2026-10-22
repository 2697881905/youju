// design token: icon. 图标资源统一以 24vp 画布、2vp 视觉描边制作。
export class IconTokens {
  static readonly canvas: number = 24;
  static readonly stroke: number = 2;
  static readonly compact: number = 16;
  static readonly small: number = 20;
  static readonly standard: number = 24;
  // 底部页签图标：对齐官方 App 实测 24×24（智慧生活 TabBar 单项 60×48 内图标 24）。
  // 原值 26 是比官方大一档的自选值，无外部依据，故收敛到与 standard 同值。
  static readonly tabBar: number = 24;
  static readonly avatarCompact: number = 24;
  static readonly avatarProfile: number = 68;
  static readonly empty: number = 44;
  static readonly shortcutTile: number = 56;
}
