import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';
import { SharedSlide } from '../motion/SharedSlide';

export interface BottomTabItem {
  key: string;
  title: string;
  icon: Resource;
  color?: ResourceColor;
}

const LONG_PRESS_MS: number = 180;
const MOVE_THRESHOLD: number = 6;
const CLICK_SUPPRESS_MS: number = 250;

@Component
export struct BottomTabBar {
  @Prop items: BottomTabItem[] = [];
  @Link currentIndex: number;
  @Prop unreadCount: number = 0;
  onSelect?: (index: number) => void = undefined;

  @State scrubbing: boolean = false;
  @State glowX: number = 0;
  @State hoverIndex: number = -1;
  @State barPressed: boolean = false;
  @State barWidth: number = 0;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  private longPressTimer: number = 0;
  private suppressClickUntil: number = 0;
  private pressArmed: boolean = false;
  private pressDownX: number = 0;

  private select(index: number): void {
    if (index < 0 || index >= this.items.length) {
      return;
    }
    if (this.onSelect !== undefined) {
      this.onSelect(index);
    } else if (this.currentIndex !== index) {
      this.currentIndex = index;
    }
  }

  private isActive(index: number): boolean {
    return this.scrubbing ? this.hoverIndex === index : this.currentIndex === index;
  }

  private selectedIndex(): number {
    return this.scrubbing && this.hoverIndex >= 0 ? this.hoverIndex : this.currentIndex;
  }

  private shouldReduceMotion(): boolean {
    return this.appReduceMotion || this.systemReduceMotion;
  }

  private clampGlow(x: number): number {
    if (this.barWidth <= 0) {
      return x;
    }
    return Math.min(this.barWidth, Math.max(0, x));
  }

  private indexFromX(x: number): number {
    if (this.barWidth <= 0 || this.items.length === 0) {
      return this.currentIndex;
    }
    const w = this.barWidth / this.items.length;
    const idx = Math.floor(x / w);
    return Math.min(this.items.length - 1, Math.max(0, idx));
  }

  private onBarTouch(e: TouchEvent): void {
    if (e.type === TouchType.Down) {
      const t = e.touches[0];
      if (!t) {
        return;
      }
      const x = this.clampGlow(t.x);
      this.barPressed = true;
      this.pressArmed = false;
      this.scrubbing = false;
      this.hoverIndex = -1;
      this.pressDownX = x;
      this.glowX = x;
      if (this.longPressTimer !== 0) {
        clearTimeout(this.longPressTimer);
      }
      this.longPressTimer = setTimeout(() => {
        this.pressArmed = true;
      }, LONG_PRESS_MS) as number;
    } else if (e.type === TouchType.Move) {
      const t = e.touches[0];
      if (!t) {
        return;
      }
      const x = this.clampGlow(t.x);
      this.glowX = x;
      if (this.pressArmed && !this.scrubbing && Math.abs(x - this.pressDownX) > MOVE_THRESHOLD) {
        this.scrubbing = true;
      }
      if (this.scrubbing) {
        this.hoverIndex = this.indexFromX(this.glowX);
      }
    } else {
      if (this.longPressTimer !== 0) {
        clearTimeout(this.longPressTimer);
        this.longPressTimer = 0;
      }
      if (this.scrubbing) {
        this.select(this.indexFromX(this.glowX));
        this.suppressClickUntil = Date.now() + CLICK_SUPPRESS_MS;
      }
      this.barPressed = false;
      this.pressArmed = false;
      this.scrubbing = false;
      this.hoverIndex = -1;
    }
  }

  @Builder
  tabInner(item: BottomTabItem, index: number): void {
    Column({ space: 3 }) {
      Column({ space: 3 }) {
        if (index === 3 && this.unreadCount > 0) {
          Badge({
            count: this.unreadCount,
            position: BadgePosition.RightTop,
            style: { badgeColor: $r('app.color.semantic_red'), badgeSize: IconTokens.compact },
          }) {
            Image(item.icon)
              .width(IconTokens.tabBar)
              .height(IconTokens.tabBar)
              .fillColor(this.isActive(index) ? ColorTokens.brand : ColorTokens.tertiary)
              .scale({
                x: this.isActive(index) && !this.shouldReduceMotion() ? 1.08 : 1,
                y: this.isActive(index) && !this.shouldReduceMotion() ? 1.08 : 1,
              })
          }
        } else {
          Image(item.icon)
            .width(IconTokens.tabBar)
            .height(IconTokens.tabBar)
            .fillColor(this.isActive(index) ? ColorTokens.brand : ColorTokens.tertiary)
            .scale({
              x: this.isActive(index) && !this.shouldReduceMotion() ? 1.08 : 1,
              y: this.isActive(index) && !this.shouldReduceMotion() ? 1.08 : 1,
            })
        }
        Text(item.title)
          .fontSize(TypeTokens.navLabel.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(this.isActive(index) ? ColorTokens.brand : ColorTokens.secondary)
      }
      .width(LayoutTokens.tabBarItemWidth)
      .height(LayoutTokens.tabBarItemHeight)
      .justifyContent(FlexAlign.Center)
      .borderRadius(RadiusTokens.lg)
      .backgroundColor(Color.Transparent)
      .scale({
        x: this.isActive(index) || this.shouldReduceMotion() ? 1 : 0.96,
        y: this.isActive(index) || this.shouldReduceMotion() ? 1 : 0.96,
      })
      .animation({
        duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.base,
        curve: MotionCurves.standard,
      })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (Date.now() < this.suppressClickUntil) {
        return;
      }
      this.select(index);
    })
  }

  @Builder
  glowOverlay(): void {
    Column()
      .width(LayoutTokens.tabBarGlowSize)
      .height(LayoutTokens.tabBarHeight)
      .radialGradient({
        center: [LayoutTokens.tabBarGlowSize / 2, LayoutTokens.tabBarHeight / 2],
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
      .hitTestBehavior(HitTestMode.None)
      .animation({
        duration: MotionTokens.instant,
        curve: MotionCurves.standard,
      })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        SharedSlide({
          selectedIndex: this.selectedIndex(),
          itemCount: this.items.length,
          controlHeight: LayoutTokens.tabBarItemHeight,
          inset: SpaceTokens.none,
          itemWidth: LayoutTokens.tabBarItemWidth,
          radius: RadiusTokens.lg,
          fill: $r('app.color.bar_selection_surface'),
          reduceMotion: this.shouldReduceMotion(),
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        ForEach(this.items, (item: BottomTabItem, index: number) => {
          this.tabInner(item, index);
        }, (item: BottomTabItem) => item.key)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(LayoutTokens.tabBarHeight)
    .borderRadius(RadiusTokens.floatingBar)
    .backgroundColor(ColorTokens.elevated)
    .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
    .shadow({ radius: 16, color: ColorTokens.barShadow, offsetY: 7 })
    .clip(true)
    .scale({
      x: this.barPressed && !this.shouldReduceMotion() ? 0.994 : 1,
      y: this.barPressed && !this.shouldReduceMotion() ? 0.98 : 1,
    })
    .animation({
      duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.fast,
      curve: MotionCurves.standard,
    })
    .onAreaChange((_old: Area, area: Area) => {
      this.barWidth = area.width as number;
    })
    .onTouch((e: TouchEvent) => { this.onBarTouch(e); })
  }
}
