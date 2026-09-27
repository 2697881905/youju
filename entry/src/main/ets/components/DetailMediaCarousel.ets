import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';

// 详情媒体阅读是纯展示边界，页面保留全屏查看和数据加载状态。
//
// 预览比例规则（单一事实源，判据 = 宽/高，3:4 = 0.75 为界）：
//   · 宽/高 < 3:4（比 3:4 更竖长，如 9:16）→ 容器钳到 3:4，ImageFit.Contain：
//     图完整可见、居中，左右露出 sunken 底色（留白，不裁剪、不变形）；
//   · 宽/高 ≥ 3:4（1:1 / 4:3 / 16:9 …）→ 容器 = 图片真实比例，横向不设上限；
//     此时框比例 == 图比例，Contain 即满框，无裁切、无缩放变形；
//   · 恰好等于 3:4 归入「保持原比例」组（同样满框）；
//   · 解码失败 / 尺寸异常（w≤0、h≤0、NaN）→ 兜底 3:4。
// 逐图生效：容器比例跟随当前页，滑动切换按 250ms 动画过渡。
@Component
export struct DetailMediaCarousel {
  @Prop images: string[] = [];
  @Link activeIndex: number;
  // 卡片一镜到底时锁定源卡片比例，避免首图解码后详情媒体高度突然跳变。
  // 普通详情入口传 0，继续使用图片真实比例。
  @Prop initialAspect: number = 0;
  // 一镜到底的**阅读**比例（转场结束后媒体框的展示比例；0 = 不切换）。
  // 与 initialAspect（飞行目标框比例）解耦：飞行段锁卡面比例让截图落点严丝合缝，
  // 首图就绪交接时再平滑切到阅读比例（如卡堆卡面 4:3 → 阅读 3:4，竖图不被压横）。
  @Prop readingAspect: number = 0;
  onOpenImage: (url: string) => void = (_url: string): void => {};
  // 首图解码完成回调：一镜到底详情页据此从 hero 切到真实轮播（图片命中缓存通常即时触发）
  onFirstReady: (() => void) | null = null;

  // 已加载图片的真实宽高比缓存（索引 → 比例），仅在切换页时读取，无需响应式
  private ratios: number[] = [];
  private firstReadyFired: boolean = false;
  // 当前展示比例：默认 3:4 占位，加载完成或切换页后按真实比例更新
  @State currentRatio: number = 0.75;

  // 竖长下限：比 3:4 更竖长（宽/高 < 0.75）一律钳到 3:4；横向不设上限（16:9 等保持原比例）。
  private static readonly MIN_RATIO: number = 3 / 4;

  private clampRatio(ratio: number): number {
    if (!(ratio > 0)) {
      return DetailMediaCarousel.MIN_RATIO;
    }
    if (ratio < DetailMediaCarousel.MIN_RATIO) {
      return DetailMediaCarousel.MIN_RATIO;
    }
    return ratio;
  }

  aboutToAppear(): void {
    if (this.initialAspect > 0) {
      this.currentRatio = this.clampRatio(this.initialAspect);
    }
  }

  // 一镜到底交接：把锁定在「飞行目标比例」（initialAspect）上的媒体框平滑归位到
  // **首图真实比例**（与滑动切换后 onChange 的行为一致；真实比例未知时才回退阅读比例）。
  // 不能长期停在锁定比例上：1:1 图片进详情被展示成 3:4、滑动一次才"恢复"，
  // 就是停在锁定值上造成的（用户实测）。用 animateTo 包住，让框高变化与页面
  // 随之的布局联动（正文移动）一起进入动画，而不是硬跳一帧。
  private applyReadingAspect(): void {
    const real: number = this.ratios[0] ?? 0;
    const target: number = real > 0 ? this.clampRatio(real)
      : (this.readingAspect > 0 ? this.clampRatio(this.readingAspect) : 0);
    if (!(target > 0) || Math.abs(target - this.currentRatio) < 0.01) {
      return;
    }
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseInOut }, (): void => {
      this.currentRatio = target;
    });
  }

  build() {
    if (this.images.length > 0) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Swiper() {
          ForEach(this.images, (url: string, index: number) => {
            Image(url)
              .width('100%')
              .height('100%')
              // 统一 Contain：被钳到 3:4 的竖长图左右留白、完整显示；
              // 未钳制的图容器比例 == 图比例，Contain 即满框（无需 Cover 裁切分支）
              .objectFit(ImageFit.Contain)
              .backgroundColor(ColorTokens.sunken)
              .borderRadius(RadiusTokens.lg)
              // 图在 Swiper 内：Image 默认 draggable=true，长按后横向拖动会被系统拖拽接管，
              // Swiper 收不到滑动 → 多图翻不动
              .draggable(false)
              .onComplete((event): void => {
                if (!event) {
                  return;
                }
                const w: number = event.width;
                const h: number = event.height;
                if (w > 0 && h > 0) {
                  const ratio: number = this.clampRatio(w / h);
                  this.ratios[index] = ratio;
                  if (index === this.activeIndex && this.initialAspect <= 0) {
                    this.currentRatio = ratio;
                  }
                }
                if (index === 0 && !this.firstReadyFired) {
                  this.firstReadyFired = true;
                  if (this.onFirstReady !== null) {
                    this.onFirstReady();
                  }
                  // 交接同帧：媒体框从「飞行目标比例」平滑归位到首图真实比例
                  this.applyReadingAspect();
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
        .disableSwipe(this.images.length <= 1)
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
