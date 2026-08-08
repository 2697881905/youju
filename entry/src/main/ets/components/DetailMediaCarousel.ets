import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';

// 详情媒体阅读是纯展示边界，页面保留全屏查看和数据加载状态。
// 图片按真实比例自适应渲染：宽度撑满、高度随当前页图片比例变化（clamp 后），不再 3:4 裁切。
@Component
export struct DetailMediaCarousel {
  @Prop images: string[] = [];
  @Link activeIndex: number;
  onOpenImage: (url: string) => void = (_url: string): void => {};

  // 已加载图片的真实宽高比缓存（索引 → 比例），仅在切换页时读取，无需响应式
  private ratios: number[] = [];
  // 当前展示比例：默认 3:4 占位，加载完成或切换页后按真实比例更新
  @State currentRatio: number = 0.75;

  private static readonly MIN_RATIO: number = 0.5; // 最高 2:1 竖长
  private static readonly MAX_RATIO: number = 1.6; // 最宽 1.6:1 横宽

  private clampRatio(ratio: number): number {
    if (!(ratio > 0)) {
      return 0.75;
    }
    if (ratio < DetailMediaCarousel.MIN_RATIO) {
      return DetailMediaCarousel.MIN_RATIO;
    }
    if (ratio > DetailMediaCarousel.MAX_RATIO) {
      return DetailMediaCarousel.MAX_RATIO;
    }
    return ratio;
  }

  build() {
    if (this.images.length > 0) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Swiper() {
          ForEach(this.images, (url: string, index: number) => {
            Image(url)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
              .backgroundColor(ColorTokens.sunken)
              .borderRadius(RadiusTokens.lg)
              .onComplete((event): void => {
                if (!event) {
                  return;
                }
                const w: number = event.width;
                const h: number = event.height;
                if (w > 0 && h > 0) {
                  const ratio: number = this.clampRatio(w / h);
                  this.ratios[index] = ratio;
                  if (index === this.activeIndex) {
                    this.currentRatio = ratio;
                  }
                }
              })
              .onClick((): void => { this.onOpenImage(url); })
          }, (url: string, index: number) => url + '_' + index)
        }
        .width('100%')
        .aspectRatio(this.currentRatio)
        .animation({ duration: 250, curve: Curve.EaseInOut })
        .indicator(false)
        .loop(false)
        .onChange((index: number): void => {
          this.activeIndex = index;
          const cached: number = this.ratios[index] ?? 0;
          this.currentRatio = cached > 0 ? cached : 0.75;
        })

        if (this.images.length > 1) {
          Text((this.activeIndex + 1) + ' / ' + this.images.length)
            .fontSize(12).fontFamily($r('app.string.font_family'))
            .fontColor(Color.White)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#99000000')
            .borderRadius(12)
            .margin({ right: 10, bottom: 10 })
        }
      }
      .width('100%')
      .backgroundColor(ColorTokens.sunken)
      .borderRadius(RadiusTokens.lg)
      .clip(true)
    }
  }
}
