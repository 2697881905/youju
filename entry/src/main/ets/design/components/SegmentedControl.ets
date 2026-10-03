import { Pressable } from '../motion/Pressable';
import { SharedSlide } from '../motion/SharedSlide';
import { ColorTokens } from '../tokens/color';
import { GlassTokens } from '../tokens/GlassTokens';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';
import { ShadowTokens } from '../tokens/shadow';
import { isImmersiveLightSenseSupported, isSystemMaterialActive, GlassBlurStyle, TopButtonMaterialModifier } from '../../utils/immersiveMaterial';

export interface SegmentedItem {
  key: string;
  label: string;
}

// —— 沉浸光感（华为应用商店分段栏同款）降级参数 ——
// API 26+（未来）：原生 backgroundSystemMaterial(uiMaterial.ImmersiveMaterial)，升级 SDK 后替换为：
//   .backgroundSystemMaterial(new uiMaterial.ImmersiveMaterial({
//     style: uiMaterial.ImmersiveStyle.THIN, interactive: true, applyShadow: true, colorInvert: true }))
// API 23~25（当前）：半透明白玻璃底 + backdropBlur 伪沉浸 + 1px 高光边框（系统原生，无第三方库）。
// 玻璃常量与 GlowInput 共享：统一在 design/tokens/GlassTokens.ets 维护（GlassTokens.SEGMENT_*）。
// 选中滑块悬浮投影（参照华为应用商店分段栏）：加重的柔和投影，突出滑块浮起感
const IMMERSIVE_SLIDE_SHADOW: ShadowOptions = { radius: 14, color: '#33000000', offsetY: 4 };

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
  // 按压/长按光斑（glowOverlay）：默认开启；试点场景可传 false 关闭，避免长按高光干扰沉浸光感观感
  @Prop glowEnabled: boolean = true;
  // 选中滑块投影：默认极轻接触阴影；参照华为应用商店分段栏可传悬浮投影（ShadowTokens 或自定义）
  @Prop slideShadow: ShadowOptions = ShadowTokens.cardContact;
  // 沉浸光感模式（华为应用商店分段栏同款）：玻璃底 + backdropBlur + 高光边框 + 滑块悬浮投影，
  // 并自动关闭按压/长按光斑；内部按 API 分级降级（见文件头 IMMERSIVE_* 注释）
  @Prop immersive: boolean = false;
  // 系统材质（沉浸光感 @since 26.0.0）：驻留 Navigation 标题栏时挂到整栏表面，
  // 由系统材质接管背景/边框/阴影（低版本设备门禁不通过，保留上面的风格分发）。
  // 注：属性名不能叫 systemMaterial —— 与 ArkUI 内置通用属性同名会与 CustomComponent 基类冲突。
  @Prop useSystemMaterial: boolean = false;
  // Swiper 联动跟手位置：滚动（拖动/吸附）中由页面喂入的连续（浮点）索引，1:1 跟手；
  // -1 表示未在滚动（回退 activeIndex()，点击切换仍走弹性动画）
  @Prop slidePosition: number = -1;
  onSelect?: (index: number) => void = undefined;
  @State scrubbing: boolean = false;
  @State hoverIndex: number = -1;
  @State controlWidth: number = 0;
  @State glowX: number = 0;
  @State barPressed: boolean = false;
  private longPressTimer: number = 0;
  // 系统材质修饰器（沉浸光感）：只创建实例，低版本设备由修饰器内部的门禁自动跳过。
  private materialModifier: TopButtonMaterialModifier = new TopButtonMaterialModifier();

  // 卸载时清掉在途的长按/扫选定时器：否则回调会在已销毁的组件上写 hoverIndex 等状态。
  aboutToDisappear(): void {
    if (this.longPressTimer !== 0) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = 0;
    }
  }
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
          [ColorTokens.glowTint, 0.0],
          [ColorTokens.glowTint, 0.35],
          [ColorTokens.glassClear, 1.0],
        ],
      })
      // 白底迁移：SCREEN 混合在纯白底上数学不可见（白+任何值=白），
      // 改 normal 混合 + 品牌蓝低透明光斑（glow_tint 随深浅模式切换）
      .position({ x: this.glowX - LayoutTokens.tabBarGlowSize / 2, y: 0 })
      // 沉浸光感模式强制关闭光斑：长按高光会干扰玻璃观感
      .opacity(!this.immersive && this.glowEnabled && this.barPressed ? (this.scrubbing ? 0.92 : 0.55) : 0)
      // 按压光斑弹性放大：模拟底部栏的点光源响应
      .scale({
        x: !this.immersive && this.glowEnabled && this.barPressed ? 1.18 : 1,
        y: !this.immersive && this.glowEnabled && this.barPressed ? 1.18 : 1,
      })
      .hitTestBehavior(HitTestMode.None)
      .animation({
        duration: MotionTokens.base,
        curve: MotionCurves.spring,
      })
  }

  private intrinsicWidth(): number {
    return Math.max(1, this.items.length) * this.itemWidth + SpaceTokens.xs;
  }

  // 分段栏本体：
  // - glass：与底部悬浮导航栏材质完全一致（系统玻璃模糊 + 半透明底 + 细边框 + 柔和阴影）
  // - outline：与右侧搜索按钮同款描边（透明底 + 细边框 + 大圆角 + 无阴影）
  // - immersive：华为应用商店同款沉浸光感（玻璃底 + backdropBlur + 高光边框 + 滑块悬浮投影）
  // - 默认：纯色 sunken 底
  @Builder
  controlBody(): void {
    Stack({ alignContent: Alignment.Center }) {
      // 分段滑块：immersive/outlined/glass 用纸面高亮；默认 elevated
      SharedSlide({
        // 跟手位置优先：滚动中喂入的连续（浮点）索引；未滚动时回退整数选中索引
        selectedIndex: this.slidePosition >= 0 ? this.slidePosition : this.activeIndex(),
        itemCount: this.items.length,
        controlHeight: LayoutTokens.segmentedHeight,
        // 滑块内缩量与容器 padding 一致，滑块高度/圆角按同心原则收进容器（不超出分段栏）
        inset: SpaceTokens.xs / 2,
        radius: RadiusTokens.lg - SpaceTokens.xs / 2,
        fill: this.immersive || this.outlined || this.glass ? ColorTokens.barSelectionSurface : ColorTokens.elevated,
        slideShadow: this.immersive ? IMMERSIVE_SLIDE_SHADOW : this.slideShadow,
        // 华为应用商店同款：按下滑块缩小，松手 spring 回弹
        pressed: this.barPressed,
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
                    duration: MotionTokens.fast,
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
    // 沉浸光感（systemMaterial @since 26.0.0）：驻留标题栏时由系统材质接管底/边框/阴影；
    // 低版本设备门禁不通过 → 保留下方按风格分发的原有样式（见 utils/immersiveMaterial.ets）
    .attributeModifier(this.useSystemMaterial ? this.materialModifier : undefined)
    // immersive：backdropBlur 伪沉浸（API 26+ 升级后替换为 backgroundSystemMaterial，见文件头注释）
    .backdropBlur(this.immersive ? GlassTokens.SEGMENT_BLUR : 0)
    .backgroundBlurStyle(!this.immersive && this.glass ? GlassBlurStyle.Floating : BlurStyle.NONE)
    // 底/边框/阴影按风格分发：
    // - immersive → 半透明白玻璃底 + 1px 高光边框 + lg 圆角 + 无整栏阴影（滑块自带悬浮投影）
    // - outlined  → 透明底 + 细边框 barBorder + lg 圆角 + 无阴影（与右侧搜索按钮一致）
    // - glass     → 系统材质渲染透明底 / 低端机 barSurface + 细边框 + floatingBar 圆角 + 柔和阴影
    // - 默认      → 纯色 sunken 底、无边框
    .backgroundColor(this.immersive
      ? GlassTokens.SEGMENT_BG
      : (this.outlined
        ? Color.Transparent
        : (this.glass ? (isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface) : ColorTokens.sunken)))
    .borderRadius(this.immersive ? RadiusTokens.lg : (this.outlined ? RadiusTokens.lg : (this.glass ? RadiusTokens.floatingBar : RadiusTokens.sm)))
    .border({
      // 材质生效时自绘描边让位（材质已接管底/边框/阴影，自绘边框会叠成第二圈）——与 DesignButton 同一规则
      width: (this.useSystemMaterial && isSystemMaterialActive())
        ? 0
        : (this.immersive ? 1 : (this.outlined || this.glass ? LayoutTokens.glassBorderWidth : 0)),
      color: this.immersive ? GlassTokens.SEGMENT_BORDER : (this.outlined || this.glass ? ColorTokens.barBorder : Color.Transparent),
      style: BorderStyle.Solid,
    })
    .shadow({
      radius: this.immersive ? 0 : (this.glass ? 18 : 0),
      color: this.immersive ? Color.Transparent : (this.glass ? ColorTokens.barShadow : Color.Transparent),
      offsetY: this.immersive ? 0 : (this.glass ? 8 : 0),
    })
    .clip(true)
    // 按压反馈（底部栏同款灵动感）：弹性回弹曲线（spring 过冲）+ 更明显的整栏下沉
    .scale({
      x: this.barPressed ? 0.99 : 1,
      y: this.barPressed ? 0.97 : 1,
    })
    .animation({
      duration: MotionTokens.base,
      curve: MotionCurves.spring,
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
