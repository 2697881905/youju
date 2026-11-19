// 发布页顶栏（创作纸版）：返回 · 模式标题 + 细进度条与下一步提示 · 单一「发布」主钮。
// 改版要点：顶栏只保留一个清晰主操作；「清空」是低频破坏性动作，下沉到「发布设置」托盘，
// 不再与「发布」并排同高，避免误触。标题随模式（发布图文/长文/视频）给出身份。
// 栏底铺纯色 canvas（非磨砂）：发布页是创作纸不是信息流，内容会从栏下滚过，
// 半透明材质会在标题区切出一条与页面底色不一致的灰带，故用实色遮挡。
import { BackButton } from '../design/components/BackButton';
import { DesignButton } from '../design/components/DesignButton';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 顶栏内容高度：44 触控目标 + 上下各 2vp 呼吸，页面顶部署高度占位与此对齐。
const BAR_CONTENT_HEIGHT: number = LayoutTokens.minTouchTarget + SpaceTokens.xs;

@Component
export struct PublishTopBar {
  @Prop modeLabel: string = '发布内容';
  @Prop progressValue: number = 0;
  @Prop progressTotal: number = 3;
  @Prop hint: string = '';
  @Prop previewDisabled: boolean = false;
  onPreview: () => void = (): void => {};
  onBack: () => void = (): void => {};

  private isReady(): boolean {
    return this.progressValue >= this.progressTotal;
  }

  build() {
    Row({ space: SpaceTokens.sm }) {
      BackButton({ action: (): void => { this.onBack(); } })

      Column({ space: SpaceTokens.xs }) {
        Text(this.modeLabel)
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .letterSpacing(TypeTokens.headline.tracking)
          .fontColor(ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: SpaceTokens.inline }) {
          Progress({ value: this.progressValue, total: this.progressTotal, type: ProgressType.Linear })
            .width(44)
            .color(ColorTokens.brand)
            .backgroundColor(ColorTokens.separator)
            .style({ strokeWidth: SpaceTokens.xs, strokeRadius: RadiusTokens.xs, enableSmoothEffect: true })
          Text(this.hint)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .fontColor(this.isReady() ? ColorTokens.brand : ColorTokens.secondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      DesignButton({
        label: '发布',
        variant: 'primary',
        visualHeight: LayoutTokens.segmentedHeight,
        disabled: this.previewDisabled,
        action: (): void => { this.onPreview(); },
      })
    }
    .width('100%')
    .height(BAR_CONTENT_HEIGHT)
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(ColorTokens.canvas)
  }
}