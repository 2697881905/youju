import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { ShadowTokens } from '../tokens/shadow';
import { LayoutTokens, SpaceTokens } from '../tokens/space';

@Component
export struct SharedSlide {
  @Prop selectedIndex: number = 0;
  @Prop itemCount: number = 1;
  @Prop controlHeight: number = LayoutTokens.segmentedHeight;
  @Prop inset: number = SpaceTokens.xs;
  @Prop itemWidth: number = 0;
  @Prop radius: number = RadiusTokens.sm;
  @Prop fill: ResourceColor = ColorTokens.elevated;
  // 滑块投影：默认极轻接触阴影；参照华为应用商店分段栏可传入更柔和的悬浮投影
  @Prop slideShadow: ShadowOptions = ShadowTokens.cardContact;
  // 按压态：滑块缩小的弹性形变（华为应用商店同款按压反馈），松手后 spring 回弹
  @Prop pressed: boolean = false;
  @Prop reduceMotion: boolean = false;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  @State containerWidth: number = 0;

  private safeCount(): number {
    return Math.max(1, this.itemCount);
  }

  private slotWidth(): number {
    return Math.max(0, (this.containerWidth - this.inset * 2) / this.safeCount());
  }

  private pillWidth(): number {
    const slot: number = this.slotWidth();
    return this.itemWidth > 0 ? Math.min(this.itemWidth, slot) : slot;
  }

  private selectedOffset(): number {
    const safeIndex: number = Math.max(0, Math.min(this.safeCount() - 1, this.selectedIndex));
    return safeIndex * this.slotWidth() + (this.slotWidth() - this.pillWidth()) / 2;
  }

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.appReduceMotion || this.systemReduceMotion;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(this.pillWidth())
        .height(Math.max(0, this.controlHeight - this.inset * 2))
        .position({ x: this.inset, y: this.inset })
        .translate({ x: this.selectedOffset() })
        .backgroundColor(this.fill)
        .borderRadius(this.radius)
        .shadow(this.slideShadow)
        // 华为应用商店同款按压反馈：按下滑块轻微缩小，松手 spring 过冲回弹
        .scale({
          x: this.pressed && !this.shouldReduceMotion() ? MotionTokens.pressSlideScale : 1,
          y: this.pressed && !this.shouldReduceMotion() ? MotionTokens.pressSlideScale : 1,
        })
        .animation({
          duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.base,
          curve: this.shouldReduceMotion() ? MotionCurves.standard : MotionCurves.springInteract,
        })
    }
    .width('100%')
    .height(this.controlHeight)
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_old: Area, next: Area) => {
      this.containerWidth = next.width as number;
    })
  }
}
