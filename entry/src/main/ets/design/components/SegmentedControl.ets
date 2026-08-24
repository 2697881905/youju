import { Pressable } from '../motion/Pressable';
import { SharedSlide } from '../motion/SharedSlide';
import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

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
          [ColorTokens.glassGlowHeavy, 0.18],
          [ColorTokens.glassGlowMedium, 0.5],
          [ColorTokens.glassClear, 1.0],
        ],
      })
      .blendMode(BlendMode.SCREEN)
      .position({ x: this.glowX - LayoutTokens.tabBarGlowSize / 2, y: 0 })
      .opacity(this.barPressed ? (this.scrubbing ? 0.92 : 0.55) : 0)
      .hitTestBehavior(HitTestMode.None)
      .animation({ duration: MotionTokens.instant, curve: MotionCurves.standard })
  }

  private intrinsicWidth(): number {
    return Math.max(1, this.items.length) * this.itemWidth + SpaceTokens.xs;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      SharedSlide({
        selectedIndex: this.activeIndex(),
        itemCount: this.items.length,
        controlHeight: LayoutTokens.segmentedHeight,
        inset: SpaceTokens.xs / 2,
        radius: RadiusTokens.sm,
        fill: this.glass ? ColorTokens.barSelectionSurface : ColorTokens.elevated,
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
    .backgroundColor(this.glass ? ColorTokens.elevated : ColorTokens.sunken)
    .borderRadius(this.glass ? RadiusTokens.md : RadiusTokens.sm)
    .border({
      width: this.glass ? 1 : 0,
      color: this.glass ? ColorTokens.separator : Color.Transparent,
      style: BorderStyle.Solid,
    })
    .shadow({
      radius: this.glass ? 8 : 0,
      color: this.glass ? ColorTokens.barShadow : Color.Transparent,
      offsetY: this.glass ? 3 : 0,
    })
    .clip(true)
    .onAreaChange((_old: Area, area: Area) => {
      this.controlWidth = area.width as number;
    })
    .onTouch((e: TouchEvent) => { this.onControlTouch(e); })
}
}
