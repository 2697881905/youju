// 发布页顶栏：返回 · 「发布内容」+ 原生进度条 + 下一步提示 · 清空 / 预览。
// 旧版把标题列用 Stack 压在按钮行正中，窄屏上与「清空」互撞；改为单行三段式布局。
// 进度用系统 Progress（Linear，自带 enableSmoothEffect 补间），不再用手写「草稿完成 2/3」纯文本。
// 栏底铺纯色 canvas（非磨砂）：发布页是表单不是信息流，内容会从栏下滚过，
// 半透明材质会在标题区切出一条与页面底色不一致的灰带（首页分段栏灰带同因），故用实色遮挡。
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
  @Prop progressValue: number = 0;
  @Prop progressTotal: number = 3;
  @Prop hint: string = '';
  @Prop previewDisabled: boolean = false;
  onClear: () => void = (): void => {};
  onPreview: () => void = (): void => {};
  onBack: () => void = (): void => {};

  private isReady(): boolean {
    return this.progressValue >= this.progressTotal;
  }

  build() {
    Row({ space: SpaceTokens.sm }) {
      BackButton({ action: (): void => { this.onBack(); } })

      Column({ space: SpaceTokens.xs }) {
        Text('发布内容')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .letterSpacing(TypeTokens.headline.tracking)
          .fontColor(ColorTokens.primary)
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
      .alignItems(HorizontalAlign.Center)

      DesignButton({
        label: '清空',
        variant: 'ghost',
        visualHeight: LayoutTokens.segmentedHeight,
        action: (): void => { this.onClear(); },
      })
      DesignButton({
        label: '预览',
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
