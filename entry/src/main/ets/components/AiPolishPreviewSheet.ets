import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// AI 联合优化（标题 + 正文）的新旧对照预览：由发布页以全屏 bindContentCover 挂载。
// 只有作者点「应用优化」才回填输入框；取消 / 侧滑返回原稿不动。
// 对照排法：原稿 subtle 底 + 次要字，优化后 elevated 底 + 主文字 + ✦ 标记，全部走 design tokens 随主题翻。
@Component
export struct AiPolishPreviewSheet {
  @Prop oldTitle: string = '';
  @Prop @Watch('syncChecks') newTitle: string = '';
  @Prop oldContent: string = '';
  @Prop @Watch('syncChecks') newContent: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 分项采纳（2026-11-07 spec 1c）：作者可以只要标题或只要正文，
  // 消除「只想改标题却被迫接受正文重写」的摩擦。零 AI 调用，纯交互粒度改进。
  @State applyTitle: boolean = true;
  @State applyContent: boolean = true;
  onApply: (applyTitle: boolean, applyContent: boolean) => void = (): void => {};
  onClose: () => void = (): void => {};

  // 默认按新旧差异预勾选：哪部分真的变了就勾哪部分
  private syncChecks(): void {
    this.applyTitle = this.newTitle !== this.oldTitle;
    this.applyContent = this.newContent !== this.oldContent;
  }

  aboutToAppear(): void {
    this.syncChecks();
  }

  @Builder
  checkRow(label: string, on: boolean): void {
    Row({ space: SpaceTokens.xs }) {
      Row() {
        if (on) {
          Text('✓')
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.onBrand)
        }
      }
      .width(16)
      .height(16)
      .borderRadius(RadiusTokens.xs)
      .backgroundColor(on ? ColorTokens.brandSolid : Color.Transparent)
      .border({
        width: LayoutTokens.hairlineWidth,
        color: on ? ColorTokens.brandSolid : ColorTokens.separator,
        style: BorderStyle.Solid,
      })
      Text(label)
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  compareBlock(label: string, oldText: string, newText: string): void {
    Column({ space: SpaceTokens.sm }) {
      Text(label)
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.overline.weight)
        .lineHeight(TypeTokens.overline.lineHeight)
        .letterSpacing(TypeTokens.overline.tracking)
        .fontColor(ColorTokens.tertiary)
      // 原稿：作者自己写的，是判断优化好坏的基准
      Column({ space: SpaceTokens.xs }) {
        Text('原稿')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
        Text(oldText.trim().length === 0 ? '（无）' : oldText)
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .lineHeight(TypeTokens.body.lineHeight)
          .fontColor(ColorTokens.secondary)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(SpaceTokens.md)
      .backgroundColor(ColorTokens.subtle)
      .borderRadius(RadiusTokens.md)
      // 优化后：AI 只做轻度润色，应用前可整段审阅
      Column({ space: SpaceTokens.xs }) {
        Row({ space: SpaceTokens.xs }) {
          Text('✦')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brandPress)
          Text('优化后')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brandPress)
        }
        Text(newText)
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .lineHeight(TypeTokens.body.lineHeight)
          .fontColor(ColorTokens.primary)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(SpaceTokens.md)
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.md)
      .border({ width: LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    Column() {
      Row() {
        Text('AI 优化预览')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.primary)
        Blank()
        Text('取消')
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.brand)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.xs, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
          .onClick((): void => { this.onClose(); })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: SpaceTokens.lg }) {
          this.compareBlock('标题', this.oldTitle, this.newTitle)
          this.compareBlock('正文', this.oldContent, this.newContent)
        }
        .width('100%')
        .padding({ top: SpaceTokens.md, bottom: SpaceTokens.xl })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .width('100%')

      Row({ space: SpaceTokens.lg }) {
        Row() {
          this.checkRow('替换标题', this.applyTitle)
        }
        .onClick((): void => { this.applyTitle = !this.applyTitle; })
        Row() {
          this.checkRow('替换正文', this.applyContent)
        }
        .onClick((): void => { this.applyContent = !this.applyContent; })
        Blank()
      }
      .width('100%')

      Button('应用所选')
        .width('100%')
        .height(LayoutTokens.minTouchTarget)
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.onBrand)
        .backgroundColor(ColorTokens.brandSolid)
        .borderRadius(RadiusTokens.md)
        .opacity(this.applyTitle || this.applyContent ? 1 : 0.4)
        .enabled(this.applyTitle || this.applyContent)
        .onClick((): void => { this.onApply(this.applyTitle, this.applyContent); })
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.statusBarHeight,
      left: SpaceTokens.lg,
      right: SpaceTokens.lg,
      bottom: SpaceTokens.xl,
    })
    .backgroundColor(ColorTokens.canvas)
  }
}
