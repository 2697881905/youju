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

  // 逐帧跟手：浮点索引（Swiper 拖动/吸附过程中的连续位置）不做补间，逐帧即时贴合手势；
  // 整数索引（点击切换）保留弹性动画（springInteract 过冲回弹）
  private isTracking(): boolean {
    return Math.abs(this.selectedIndex - Math.round(this.selectedIndex)) > 0.001;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .position({ x: this.inset, y: this.inset })
        .translate({ x: this.selectedOffset() })
        .backgroundColor(this.fill)
        .shadow(this.slideShadow)
        // 华为应用商店同款按压反馈：按下滑块轻微缩小，松手 spring 过冲回弹
        .scale({
          x: this.pressed ? MotionTokens.pressSlideScale : 1,
          y: this.pressed ? MotionTokens.pressSlideScale : 1,
        })
        // 跟手分支必须用 duration 可控的线性曲线：springMotion 是物理弹簧，
        // 动画时长由 response(0.6s) 与初速度决定、忽略 duration —— duration:0 不会瞬时生效，
        // 逐帧喂入会变成 0.6s 弹簧逐帧追赶，滑块弹性滞后于手指（不跟手）。
        // 整数索引（点击切换）保留 springMotion 弹性动画（时长由弹簧参数自算）。
        .animation({
          duration: this.isTracking() ? MotionTokens.none : MotionTokens.base,
          curve: this.isTracking() ? Curve.Linear : MotionCurves.springInteract,
        })
        // ⚠️ 尺寸/圆角声明在 animation **之后**：显式动画吃掉的是它之前声明的可动画属性，
        // 宽度入域后，容器宽度被 onAreaChange 重测的那一帧会把滑块弹成小圆块
        // （真机连拍收尾帧 dj10/dh10：滑块宽 512 → 100px，肉眼是「滑块缩一下」）。
        .width(this.pillWidth())
        .height(Math.max(0, this.controlHeight - this.inset * 2))
        .borderRadius(this.radius)
    }
    .width('100%')
    .height(this.controlHeight)
    .hitTestBehavior(HitTestMode.BLOCK_DESCENDANTS)
    .onAreaChange((_old: Area, next: Area) => {
      // 只接受有效且确有变化的宽度：0/抖动值会把滑块宽度算成 0，再被上面的动画补间出来
      const w: number = next.width as number;
      if (w > 0 && Math.abs(w - this.containerWidth) > 0.5) {
        this.containerWidth = w;
      }
    })
  }
}
