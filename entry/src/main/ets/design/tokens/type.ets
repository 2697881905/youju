// design token: type. 字距保持 0，避免大字号下负字距造成裁切。
export class TypeStyleToken {
  size: number;
  weight: number;
  lineHeight: number;
  tracking: number;

  constructor(size: number, weight: number, lineHeight: number, tracking: number) {
    this.size = size;
    this.weight = weight;
    this.lineHeight = lineHeight;
    this.tracking = tracking;
  }
}

export class TypeTokens {
  // 应用内的唯一字体入口。资源令牌同时供未接入 TypeTokens 的旧页面使用。
  static readonly fontFamily: Resource = $r('app.string.font_family');
  static readonly display: TypeStyleToken = new TypeStyleToken(30, 700, 36, 0);
  static readonly title: TypeStyleToken = new TypeStyleToken(20, 650, 26, 0);
  static readonly headline: TypeStyleToken = new TypeStyleToken(17, 600, 22, 0);
  static readonly body: TypeStyleToken = new TypeStyleToken(15, 400, 23, 0);
  static readonly callout: TypeStyleToken = new TypeStyleToken(13, 400, 18, 0);
  static readonly caption: TypeStyleToken = new TypeStyleToken(12, 450, 16, 0);
  static readonly overline: TypeStyleToken = new TypeStyleToken(11, 600, 14, 0);
  static readonly navLabel: TypeStyleToken = new TypeStyleToken(10, 400, 14, 0);

  static readonly tabularFeature: string = 'tnum';
}
