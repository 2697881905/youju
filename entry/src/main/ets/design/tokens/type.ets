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
  // 衬线（宋体感）入口：标题区文字用衬线压住"信服"，正文仍走无衬线。
  static readonly fontFamilySerif: Resource = $r('app.string.font_family_serif');
  // 衬线正文字重：标题用 Bold 字重文件，正文需 Regular（字重 400）才协调，
  // ArkUI 一个 familyName 只能绑一个字体文件，故正文单独注册一个 family。
  static readonly fontFamilySerifBody: Resource = $r('app.string.font_family_serif_body');
  static readonly display: TypeStyleToken = new TypeStyleToken(32, 700, 40, 0);
  static readonly displaySerif: TypeStyleToken = new TypeStyleToken(32, 700, 44, 0);
  static readonly title: TypeStyleToken = new TypeStyleToken(21, 650, 28, 0);
  static readonly titleSerif: TypeStyleToken = new TypeStyleToken(21, 700, 32, 0);
  static readonly headline: TypeStyleToken = new TypeStyleToken(18, 600, 24, 0);
  static readonly body: TypeStyleToken = new TypeStyleToken(16, 400, 24, 0);
  static readonly callout: TypeStyleToken = new TypeStyleToken(14, 400, 20, 0);
  static readonly caption: TypeStyleToken = new TypeStyleToken(12, 450, 16, 0);
  static readonly overline: TypeStyleToken = new TypeStyleToken(11, 600, 14, 0);
  static readonly navLabel: TypeStyleToken = new TypeStyleToken(10, 400, 14, 0);

  static readonly tabularFeature: string = 'tnum';
}
