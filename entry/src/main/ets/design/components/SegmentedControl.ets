import { Pressable } from '../motion/Pressable';
import { SharedSlide } from '../motion/SharedSlide';
import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';
import { isImmersiveLightSenseSupported, GlassBlurStyle } from '../../utils/immersiveMaterial';

export interface SegmentedItem {
  key: string;
  label: string;
}

const LONG_PRESS_MS: number = 180;
const MOVE_THRESHOLD: number = 6;
const CLICK_SUPPRESS_MS: number = 250;

@Component
export struct SegmentedControl {
  @Prop items: SegmentedItem[] = [];
  @Link selectedIndex: number;
  @Prop itemWidth: number = 52;
  @Prop fillWidth: boolean = true;
  @Prop glass: boolean = false;
  // 描边风格（搜索引擎顶栏同款）：透明底 + 细边框 + 大圆角 + 无阴影，与右侧搜索按钮视觉统一
  @Prop outlined: boolean = false;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  onSelect?: (index: number) => void = undefined;
  @State scrubbing: boolean = false;
  @State hoverIndex: number = -1;
  @State controlWidth: number = 0;
  @State glowX: number = 0;
  @State barPressed: boolean = false;
  private longPressTimer: number = 0;
  private suppressClickUntil: number = 0;
  private pressArmed: boolean = false;
  private pressDownX: number = 0;

  private select(index: number): void {
    if (index < 0 || index >= this.items.length) {
      return;
    }
    if (this.selectedIndex !== index) {
      this.selectedIndex = index;
    }
    if (this.onSelect !== undefined) {
      this.onSelect(index);
    }
  }

  private shouldReduceMotion(): boolean {
    return this.appReduceMotion || this.systemReduceMotion;
  }

  private activeIndex(): number {
    return this.scrubbing && this.hoverIndex >= 0 ? this.hoverIndex : this.selectedIndex;
  }

  private indexFromX(x: number): number {
    if (this.controlWidth <= 0 || this.items.length === 0) {
      return this.selectedIndex;
    }
    const itemWidth: number = this.controlWidth / this.items.length;
    return Math.min(this.items.length - 1, Math.max(0, Math.floor(x / itemWidth)));
  }

  private clampGlow(x: number): number {
    if (this.controlWidth <= 0) {
      return x;
    }
    return Math.min(this.controlWidth, Math.max(0, x));
  }

  private onItemClick(index: number): void {
    if (Date.now() < this.suppressClickUntil) {
      return;
    }
    this.select(index);
  }

  private onControlTouch(e: TouchEvent): void {
    if (e.type === TouchType.Down) {
      const touch = e.touches[0];
      if (!touch) {
        return;
      }
      this.pressDownX = touch.x;
      this.glowX = this.clampGlow(touch.x);
      this.barPressed = true;
      this.pressArmed = false;
      this.scrubbing = false;
      this.hoverIndex = -1;
      if (this.longPressTimer !== 0) {
        clearTimeout(this.longPressTimer);
      }
      this.longPressTimer = setTimeout((): void => {
        this.pressArmed = true;
        this.longPressTimer = 0;
      }, LONG_PRESS_MS) as number;
    } else if (e.type === TouchType.Move) {
      const touch = e.touches[0];
      if (!touch) {
        return;
      }
      this.glowX = this.clampGlow(touch.x);
      if (!this.pressArmed) {
        return;
      }
      if (!this.scrubbing && Math.abs(touch.x - this.pressDownX) > MOVE_THRESHOLD) {
        this.scrubbing = true;
      }
      if (this.scrubbing) {
        this.hoverIndex = this.indexFromX(touch.x);
      }
    } else {
      if (this.longPressTimer !== 0) {
        clearTimeout(this.longPressTimer);
        this.longPressTimer = 0;
      }
      if (this.scrubbing && this.hoverIndex >= 0) {
        this.select(this.hoverIndex);
        this.suppressClickUntil = Date.now() + CLICK_SUPPRESS_MS;
      }
      this.pressArmed = false;
      this.scrubbing = false;
      this.hoverIndex = -1;
      this.barPressed = false;
    }
  }

  @Builder
  private glowOverlay(): void {
    Column()
      .width(LayoutTokens.tabBarGlowSize)
      .height(LayoutTokens.segmentedHeight)
      .radialGradient({
        center: [LayoutTokens.tabBarGlowSize / 2, LayoutTokens.segmentedHeight / 2],
        radius: LayoutTokens.tabBarGlowSize / 2,
        colors: [
          [ColorTokens.glassWhite, 0.0],
          [ColorTokens.brandTint, 0.18],
          [ColorTokens.glassGlowMedium, 0.5],
          [ColorTokens.glassClear, 1.0],
        ],
      })
      .blendMode(BlendMode.SCREEN)
      .position({ x: this.glowX - LayoutTokens.tabBarGlowSize / 2, y: 0 })
      .opacity(this.barPressed ? (this.scrubbing ? 0.92 : 0.55) : 0)
      // 按压光斑弹性放大：模拟底部栏的点光源响应
      .scale({
        x: this.barPressed && !this.shouldReduceMotion() ? 1.18 : 1,
        y: this.barPressed && !this.shouldReduceMotion() ? 1.18 : 1,
      })
      .hitTestBehavior(HitTestMode.None)
      .animation({
        duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.base,
        curve: this.shouldReduceMotion() ? MotionCurves.standard : MotionCurves.spring,
      })
  }

  private intrinsicWidth(): number {
    return Math.max(1, this.items.length) * this.itemWidth + SpaceTokens.xs;
  }

  // 分段栏本体：
  // - glass：与底部悬浮导航栏材质完全一致（系统玻璃模糊 + 半透明底 + 细边框 + 柔和阴影）
  // - outline：与右侧搜索按钮同款描边（透明底 + 细边框 + 大圆角 + 无阴影）
  // - 默认：纯色 sunken 底
  @Builder
  controlBody(): void {
    Stack({ alignContent: Alignment.Center }) {
      // 分段滑块：outlined 用纸面高亮（同 glass）；默认 elevated
      SharedSlide({
        selectedIndex: this.activeIndex(),
        itemCount: this.items.length,
        controlHeight: LayoutTokens.segmentedHeight,
        inset: SpaceTokens.none,
        radius: RadiusTokens.lg,
        fill: this.outlined || this.glass ? ColorTokens.barSelectionSurface : ColorTokens.elevated,
        reduceMotion: this.shouldReduceMotion(),
      })
      Row({ space: SpaceTokens.none }) {
        ForEach(
          this.items,
          (item: SegmentedItem, index: number) => {
            Column() {
              Pressable({
                fillWidth: this.fillWidth,
                visualHeight: LayoutTokens.segmentedHeight,
                touchTargetHeight: LayoutTokens.minTouchTarget,
                reduceMotion: this.shouldReduceMotion(),
                action: () => { this.onItemClick(index); },
              }) {
                Text(item.label)
                  .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                  .fontWeight(this.activeIndex() === index ? TypeTokens.headline.weight : TypeTokens.callout.weight)
                  .lineHeight(TypeTokens.callout.lineHeight)
                  .letterSpacing(TypeTokens.callout.tracking)
                  .fontColor(this.activeIndex() === index ? ColorTokens.primary : ColorTokens.secondary)
                  .width(this.fillWidth ? '100%' : this.itemWidth)
                  .height(LayoutTokens.segmentedHeight - SpaceTokens.xs)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(Color.Transparent)
                  .borderRadius(RadiusTokens.sm)
                  .animation({
                    duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.fast,
                    curve: MotionCurves.standard,
                  })
              }
            }
            .layoutWeight(this.fillWidth ? 1 : 0)
          },
          (item: SegmentedItem) => item.key
        )
      }
      .height(LayoutTokens.segmentedHeight)
      .width(this.fillWidth ? '100%' : this.intrinsicWidth())
      .alignItems(VerticalAlign.Center)
      this.glowOverlay()
    }
    .width(this.fillWidth ? '100%' : this.intrinsicWidth())
    .height(LayoutTokens.segmentedHeight)
    .padding(SpaceTokens.xs / 2)
    .backgroundBlurStyle(this.glass ? GlassBlurStyle.Floating : BlurStyle.NONE)
    // 底/边框/阴影按风格分发：
    // - outlined → 透明底 + 细边框 barBorder + lg 圆角 + 无阴影（与右侧搜索按钮一致）
    // - glass   → 系统材质渲染透明底 / 低端机 barSurface + 细边框 + floatingBar 圆角 + 柔和阴影
    // - 默认    → 纯色 sunken 底、无边框
    .backgroundColor(this.outlined
      ? Color.Transparent
      : (this.glass ? (isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface) : ColorTokens.sunken))
    .borderRadius(this.outlined ? RadiusTokens.lg : (this.glass ? RadiusTokens.floatingBar : RadiusTokens.sm))
    .border({
      width: this.outlined || this.glass ? LayoutTokens.glassBorderWidth : 0,
      color: this.outlined || this.glass ? ColorTokens.barBorder : Color.Transparent,
      style: BorderStyle.Solid,
    })
    .shadow({
      radius: this.glass ? 18 : 0,
      color: this.glass ? ColorTokens.barShadow : Color.Transparent,
      offsetY: this.glass ? 8 : 0,
    })
    .clip(true)
    // 按压反馈（底部栏同款灵动感）：弹性回弹曲线（spring 过冲）+ 更明显的整栏下沉
    .scale({
      x: this.barPressed && !this.shouldReduceMotion() ? 0.99 : 1,
      y: this.barPressed && !this.shouldReduceMotion() ? 0.97 : 1,
    })
    .animation({
      duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.base,
      curve: this.shouldReduceMotion() ? MotionCurves.standard : MotionCurves.spring,
    })
    .onAreaChange((_old: Area, area: Area) => {
      this.controlWidth = area.width as number;
    })
    .onTouch((e: TouchEvent) => { this.onControlTouch(e); })
  }

  build() {
    this.controlBody()
  }
}
