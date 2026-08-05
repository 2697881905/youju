import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens } from '../design/tokens/space';

// 详情媒体阅读是纯展示边界，页面保留全屏查看和数据加载状态。
@Component
export struct DetailMediaCarousel {
  @Prop images: string[] = [];
  @Link activeIndex: number;
  onOpenImage: (url: string) => void = (_url: string): void => {};

  build() {
    if (this.images.length > 0) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Swiper() {
          ForEach(this.images, (url: string) => {
            Image(url)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .backgroundColor(ColorTokens.sunken)
              .borderRadius(RadiusTokens.lg)
              .onClick((): void => { this.onOpenImage(url); })
          }, (url: string) => url)
        }
        .width('100%')
        .height('100%')
        .indicator(false)
        .loop(false)
        .onChange((index: number): void => { this.activeIndex = index; })

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
      .aspectRatio(LayoutTokens.cardMediaAspectRatio)
      .backgroundColor(ColorTokens.sunken)
      .borderRadius(RadiusTokens.lg)
      .clip(true)
    }
  }
}
