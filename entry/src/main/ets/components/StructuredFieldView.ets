import { StructuredFieldPair } from '../utils/structuredFields';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 结构化字段的展示层：由 StructuredFieldPair.kind 决定渲染形态。
//
// 改造前所有字段一律渲染成「label 宽 88 + value」的同一张两列表，
// 字段类型带来的信息（推荐指数是个分数、损失金额是笔钱、准备工具是清单、
// 步骤拆解是有序流程）全部被抹平 —— 结构化对读者完全不可见。
//
// 这里只做展示，不做业务判断；字段表与 kind 都来自 utils/structuredFields 的唯一定义处。

const CHIP_SEPARATORS: string[] = ['、', '，', ',', '/', '|', '；', ';'];

// 标签行拆分：连续分隔符与重复项都收敛掉（「螺丝刀、、万用表/螺丝刀」→ 两项）
export function splitChips(text: string): string[] {
  let parts: string[] = [text];
  for (const sep of CHIP_SEPARATORS) {
    const next: string[] = [];
    for (const part of parts) {
      for (const piece of part.split(sep)) {
        next.push(piece);
      }
    }
    parts = next;
  }
  const out: string[] = [];
  for (const part of parts) {
    const t: string = part.trim();
    if (t.length > 0 && out.indexOf(t) < 0) {
      out.push(t);
    }
  }
  return out;
}

// 去掉行首的「1.」「2、」「3)」这类序号，序号由渲染层统一生成
function stripStepPrefix(line: string): string {
  let i: number = 0;
  while (i < line.length && line.charAt(i) >= '0' && line.charAt(i) <= '9') {
    i++;
  }
  if (i === 0) {
    return line;
  }
  const sep: string = i < line.length ? line.charAt(i) : '';
  if (sep === '.' || sep === '、' || sep === ')' || sep === '）' || sep === ':' || sep === '：') {
    return line.substring(i + 1).trim();
  }
  return line;
}

// 步骤拆条：先按换行，再按分号；拆不出两条就返回空数组，由调用方回退成段落块。
// 纯展示层拆分，不改数据（steps 仍是字符串，避免存量迁移）。
export function splitSteps(text: string): string[] {
  const collect = (source: string[], separators: string[]): string[] => {
    let parts: string[] = source;
    for (const sep of separators) {
      const next: string[] = [];
      for (const part of parts) {
        for (const piece of part.split(sep)) {
          next.push(piece);
        }
      }
      parts = next;
    }
    return parts;
  };
  let raw: string[] = collect([text], ['\n']);
  if (raw.length < 2) {
    raw = collect([text], ['；', ';']);
  }
  const out: string[] = [];
  for (const line of raw) {
    const t: string = stripStepPrefix(line.trim());
    if (t.length > 0) {
      out.push(t);
    }
  }
  return out.length >= 2 ? out : [];
}

// 星级：0-5，四舍五入到整颗（小数精度由旁边的数值承担，不引入半星字形）
export function starText(value: string): string {
  const num: number = Number(value);
  if (!Number.isFinite(num)) {
    return '';
  }
  const filled: number = Math.max(0, Math.min(5, Math.round(num)));
  let out: string = '';
  for (let i = 0; i < 5; i++) {
    out += i < filled ? '★' : '☆';
  }
  return out;
}

// 左侧色条：用色而不只用字，让优缺点在扫读时第一眼可分（同时保留文字标签，不只靠颜色）
export function accentOf(key: string): ResourceColor {
  if (key === 'pros' || key === 'correctApproach') {
    return ColorTokens.success;
  }
  if (key === 'cons') {
    return ColorTokens.danger;
  }
  if (key === 'pitfallExperience') {
    return ColorTokens.warm;
  }
  return ColorTokens.brand;
}

// 结论卡上「提前展示」的字段：这些值从字段块里移除，避免同一屏出现两次
const HEADLINE_KEYS: string[] = ['rating', 'lossAmount'];

export function headlineKeys(): string[] {
  return HEADLINE_KEYS;
}

export function withoutHeadline(pairs: StructuredFieldPair[]): StructuredFieldPair[] {
  const out: StructuredFieldPair[] = [];
  for (const pair of pairs) {
    if (HEADLINE_KEYS.indexOf(pair.key) < 0) {
      out.push(pair);
    }
  }
  return out;
}

function findPair(pairs: StructuredFieldPair[], key: string): StructuredFieldPair | undefined {
  for (const pair of pairs) {
    if (pair.key === key) {
      return pair;
    }
  }
  return undefined;
}

// —— 结论卡：先结论后依据。只展示该体裁的「头条指标」+ 适合人群 ——
@Component
export struct StructuredConclusionCard {
  @Prop pairs: StructuredFieldPair[] = [];

  build() {
    if (findPair(this.pairs, 'rating') !== undefined || findPair(this.pairs, 'lossAmount') !== undefined ||
      findPair(this.pairs, 'targetAudience') !== undefined) {
      Column({ space: SpaceTokens.md }) {
        Row({ space: SpaceTokens.md }) {
          if (findPair(this.pairs, 'rating') !== undefined) {
            this.metric('推荐指数', findPair(this.pairs, 'rating')!.value, true);
          }
          if (findPair(this.pairs, 'lossAmount') !== undefined) {
            this.metric('损失金额', findPair(this.pairs, 'lossAmount')!.value, false);
          }
          Blank()
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)

        if (findPair(this.pairs, 'targetAudience') !== undefined) {
          this.chipLine('适合人群', splitChips(findPair(this.pairs, 'targetAudience')!.value))
        }
      }
      .width('100%')
      .padding(SpaceTokens.block)
      .backgroundColor(ColorTokens.brandTint)
      .borderRadius(RadiusTokens.md)
      .border({ width: LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private metric(label: string, value: string, withStars: boolean): void {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .letterSpacing(TypeTokens.overline.tracking)
        .fontColor(ColorTokens.secondary)
      Row({ space: SpaceTokens.inlineTight }) {
        Text(value)
          .fontSize(26).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.titleSerif.weight)
          .fontColor(ColorTokens.primary)
        if (withStars) {
          Text(starText(value))
            .fontSize(13).fontFamily(TypeTokens.fontFamily)
            .letterSpacing(1)
            .fontColor(ColorTokens.brand)
            .margin({ bottom: 3 })
        }
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private chipLine(label: string, chips: string[]): void {
    Column({ space: SpaceTokens.inline }) {
      Text(label)
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .letterSpacing(TypeTokens.overline.tracking)
        .fontColor(ColorTokens.secondary)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(chips, (chip: string) => {
          Text(chip)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brand)
            .backgroundColor(ColorTokens.elevated)
            .borderRadius(RadiusTokens.pill)
            .border({ width: LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
            .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
            .margin({ right: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
        }, (chip: string) => chip)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

// —— 字段块：按 kind 分形态渲染 ——
@Component
export struct StructuredFieldBlock {
  @Prop pairs: StructuredFieldPair[] = [];

  build() {
    if (this.pairs.length > 0) {
      Column({ space: SpaceTokens.block }) {
        ForEach(this.pairs, (pair: StructuredFieldPair) => {
          this.fieldRow(pair)
        }, (pair: StructuredFieldPair) => pair.key)
      }
      .width('100%')
      .padding(SpaceTokens.block)
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.md)
      .border({ width: LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private fieldRow(pair: StructuredFieldPair): void {
    if (pair.kind === 'rating') {
      this.ratingRow(pair)
    } else if (pair.kind === 'amount') {
      this.amountRow(pair)
    } else if (pair.kind === 'chips') {
      this.chipRow(pair)
    } else if (pair.kind === 'steps' && splitSteps(pair.value).length >= 2) {
      this.stepList(pair)
    } else {
      this.textBlock(pair)
    }
  }

  @Builder
  private label(label: string): void {
    Text(label)
      .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
      .letterSpacing(TypeTokens.overline.tracking)
      .fontColor(ColorTokens.secondary)
  }

  @Builder
  private ratingRow(pair: StructuredFieldPair): void {
    Column({ space: SpaceTokens.inlineTight }) {
      this.label(pair.label)
      Row({ space: SpaceTokens.inline }) {
        Text(starText(pair.value))
          .fontSize(16).fontFamily(TypeTokens.fontFamily)
          .letterSpacing(2)
          .fontColor(ColorTokens.brand)
        Text(pair.value)
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamilySerifBody)
          .fontWeight(600)
          .fontColor(ColorTokens.primary)
        Text('/ 5')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private amountRow(pair: StructuredFieldPair): void {
    Column({ space: SpaceTokens.inlineTight }) {
      this.label(pair.label)
      Text(pair.value)
        .fontSize(22).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.titleSerif.weight)
        .fontColor(ColorTokens.warm)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private chipRow(pair: StructuredFieldPair): void {
    Column({ space: SpaceTokens.inline }) {
      this.label(pair.label)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(splitChips(pair.value), (chip: string) => {
          Text(chip)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brand)
            .backgroundColor(ColorTokens.subtle)
            .borderRadius(RadiusTokens.pill)
            .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
            .margin({ right: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
        }, (chip: string) => chip)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private stepList(pair: StructuredFieldPair): void {
    Column({ space: SpaceTokens.inline }) {
      this.label(pair.label)
      Column({ space: SpaceTokens.sm }) {
        ForEach(splitSteps(pair.value), (step: string, index: number) => {
          Row({ space: SpaceTokens.sm }) {
            Text(String(index + 1))
              .width(20).height(20)
              .textAlign(TextAlign.Center)
              .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(600)
              .fontColor(ColorTokens.brand)
              .backgroundColor(ColorTokens.brandTint)
              .borderRadius(RadiusTokens.pill)
              .margin({ top: 2 })
            Text(step)
              .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamilySerifBody)
              .lineHeight(TypeTokens.body.lineHeight)
              .fontColor(ColorTokens.primary)
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (step: string) => step)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private textBlock(pair: StructuredFieldPair): void {
    Column({ space: SpaceTokens.inlineTight }) {
      this.label(pair.label)
      Text(pair.value)
        .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamilySerifBody)
        .lineHeight(TypeTokens.body.lineHeight)
        .fontColor(ColorTokens.primary)
        .width('100%')
        .textAlign(TextAlign.Start)
        // 左侧色条：扫读时第一眼能分出「优点 / 缺点 / 踩坑」，同时保留文字标签不只靠颜色
        .padding({ left: SpaceTokens.md })
        .border({ width: { left: 3 }, color: accentOf(pair.key), style: BorderStyle.Solid })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
