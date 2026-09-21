import { resolveActionIcon } from '../utils/actionIcons';
import { formatCount } from '../utils/format';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { MotionCurves, MotionTokens, MotionFrameRates } from '../design/tokens/motion';
import { Pressable } from '../design/motion/Pressable';
import { GlowInput } from '../design/components/GlowInput';
import { bottomNavInset } from '../utils/cardTokens';
import { GlassBlurStyle, isImmersiveLightSenseSupported } from '../utils/immersiveMaterial';

@Component
struct DetailActionButton {
  @Prop icon: Resource = resolveActionIcon('like');
  // 激活态专用图标（实心彩色 SVG，base/dark 双套状态色）；缺省回退线条 icon
  @Prop activeIcon: Resource = resolveActionIcon('like');
  @Prop label: string = '';
  @Prop active: boolean = false;
  @Prop disabled: boolean = false;
  @Prop activeColor: ResourceColor = ColorTokens.brand;
  @Prop @Watch('onFeedbackChanged') feedbackVersion: number = 0;
  @State confirmationScale: number = 1;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  onAction: () => void = (): void => {};
  private resetTimer: number = 0;

  aboutToDisappear(): void {
    if (this.resetTimer !== 0) {
      clearTimeout(this.resetTimer);
      this.resetTimer = 0;
    }
  }

  private reduceMotion(): boolean {
    return this.appReduceMotion || this.systemReduceMotion;
  }

  private onFeedbackChanged(): void {
    if (this.feedbackVersion === 0 || this.reduceMotion()) {
      return;
    }
    if (this.resetTimer !== 0) {
      clearTimeout(this.resetTimer);
    }
    this.confirmationScale = MotionTokens.successScale;
    this.resetTimer = setTimeout((): void => {
      this.confirmationScale = 1;
      this.resetTimer = 0;
    }, MotionTokens.control) as number;
  }

  build() {
    Pressable({
      disabled: this.disabled,
      fillWidth: true,
      visualHeight: LayoutTokens.minTouchTarget,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: (): void => { this.onAction(); },
    }) {
      Column({ space: SpaceTokens.inlineTight }) {
        // 激活态切换实心彩色图标（点赞红/收藏黄），未激活保持主题线条图标；
        // 状态色由图标 + 下方文字共同表达（保留反馈缩放动效）
        if (this.active) {
          Image(this.activeIcon)
            .width(IconTokens.tabBar)
            .height(IconTokens.tabBar)
        } else {
          Image(this.icon)
            .width(IconTokens.tabBar)
            .height(IconTokens.tabBar)
        }
        Text(this.label)
          .fontSize(TypeTokens.navLabel.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(this.active ? this.activeColor : ColorTokens.secondary)
          .maxLines(1)
      }
      .width('100%')
      .height(LayoutTokens.tabBarItemHeight)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .opacity(this.disabled ? 0.6 : 1)
      .scale({ x: this.confirmationScale, y: this.confirmationScale })
      .animation({
        duration: this.reduceMotion() ? MotionTokens.instant : MotionTokens.control,
        curve: MotionCurves.springBounce,
        expectedFrameRateRange: MotionFrameRates.default,
      })
    }
  }
}

// 固定底部操作层只负责呈现状态；请求、乐观更新和失败回滚属于 DetailPage。
@Component
export struct DetailActionBar {
  // 响应式绑定系统导航条高度（AppStorage 由 refreshWindowInsets 实测写入）：
  // 切换三键/手势导航会触发 avoidAreaChange → 值更新 → 本组件自动重绘。
  @StorageProp('navBarHeight') navBarHeight: number = 0;

  @Link commenting: boolean;
  @Link commentText: string;
  @Prop upCount: number = 0;
  @Prop bookmarkCount: number = 0;
  @Prop commentCount: number = 0;
  @Prop uped: boolean = false;
  @Prop bookmarked: boolean = false;
  @Prop upPending: boolean = false;
  @Prop bookmarkPending: boolean = false;
  @Prop upFeedbackVersion: number = 0;
  @Prop bookmarkFeedbackVersion: number = 0;
  @Prop showShare: boolean = true;
  // P1-1 评论回复态：replyName 非空时输入框进入「回复 @xx」
  @Prop replyName: string = '';
  onUp: () => void = (): void => {};
  onBookmark: () => void = (): void => {};
  onSendComment: () => void = (): void => {};
  onShare: () => void = (): void => {};
  onCancelReply: () => void = (): void => {};

  build() {
    // 悬浮玻璃 Dock：与首页 BottomTabBar **同 token 同视觉**——
    // 外层 padding = tabBarSideMargin(18)、margin = tabBarBottomGap(18)+bottomNavInset()、
    // 药丸高 = tabBarHeight(64)、圆角 = floatingBar、材质 = Floating blur（沉浸光感降级同策略）。
    // 滚动列表尾部以 barBottomReserve()（floatingBarReserve 94 + 导航条高）预留，恰好覆盖本 Dock。
    Row() {
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          if (this.commenting) {
            Column({ space: 4 }) {
              // 楼中楼回复态提示条：仅当回复目标非空时显示
              if (this.replyName.length > 0) {
                Row() {
                  Text('回复 @' + this.replyName)
                    .fontSize(12).fontFamily(TypeTokens.fontFamily)
                    .fontColor(ColorTokens.brand)
                }
                .width('100%')
                .padding({ left: SpaceTokens.sm })
              }
              Row({ space: SpaceTokens.sm }) {
                Row() {
                  Image(resolveActionIcon('close'))
                    .width(IconTokens.compact)
                    .height(IconTokens.compact)
                    .fillColor(ColorTokens.secondary)
                }
                .width(LayoutTokens.minTouchTarget)
                .height(LayoutTokens.minTouchTarget)
                .justifyContent(FlexAlign.Center)
                .onClick((): void => { this.commenting = false; this.commentText = ''; this.onCancelReply(); })
                // 聚焦流光输入框：键入（聚焦）点亮原生流光，失焦熄灭
                GlowInput({
                  placeholder: this.replyName.length > 0 ? ('回复 @' + this.replyName) : '理性补充，有图有真相',
                  text: $commentText,
                  fillWidth: true,
                })
                // 发送按钮：暖白玻璃胶囊 + 主文字色 + 柔和阴影（与输入框同区，非品牌蓝）
                Text('发送')
                  .width(56)
                  .height(LayoutTokens.minTouchTarget)
                  .textAlign(TextAlign.Center)
                  .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                  .fontWeight(TypeTokens.headline.weight)
                  .fontColor(ColorTokens.primary)
                  .backgroundColor(Color.Transparent)
                  .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
                  .borderRadius(RadiusTokens.lg)
                  .stateStyles({
                    pressed: {
                      .scale({ x: 0.95, y: 0.95 })
                      .backgroundColor(ColorTokens.brandTint)
                    },
                    normal: {
                      .scale({ x: 1, y: 1 })
                      .backgroundColor(Color.Transparent)
                    },
                  })
                  .animation({ duration: MotionTokens.fast, curve: MotionCurves.standard })
                  .onClick((): void => { this.onSendComment(); })
              }
              .width('100%')
              .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          } else {
            Row() {
              DetailActionButton({ icon: resolveActionIcon('like'), activeIcon: resolveActionIcon('likeActive'), label: formatCount(this.upCount), active: this.uped, activeColor: ColorTokens.like, disabled: this.upPending, feedbackVersion: this.upFeedbackVersion, onAction: (): void => { this.onUp(); } }).layoutWeight(1)
              DetailActionButton({ icon: resolveActionIcon('bookmark'), activeIcon: resolveActionIcon('bookmarkActive'), label: formatCount(this.bookmarkCount), active: this.bookmarked, activeColor: ColorTokens.bookmark, disabled: this.bookmarkPending, feedbackVersion: this.bookmarkFeedbackVersion, onAction: (): void => { this.onBookmark(); } }).layoutWeight(1)
              DetailActionButton({ icon: resolveActionIcon('comment'), label: formatCount(this.commentCount), onAction: (): void => { this.commenting = true; } }).layoutWeight(1)
              if (this.showShare) {
                DetailActionButton({ icon: resolveActionIcon('share'), label: '分享', onAction: (): void => { this.onShare(); } }).layoutWeight(1)
              }
            }
            .width('100%')
            .height('100%')
          }
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height(LayoutTokens.tabBarHeight)
    .padding({ left: LayoutTokens.tabBarSideMargin, right: LayoutTokens.tabBarSideMargin })
    .margin({ bottom: LayoutTokens.tabBarBottomGap + bottomNavInset() })
    .borderRadius(RadiusTokens.floatingBar)
    // 沉浸光感材质：真机（HarmonyOS 6+）hdsMaterial，模拟器/低端机降级为系统模糊——与首页 Dock 同策略
    .backgroundBlurStyle(GlassBlurStyle.Floating)
    .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
    .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
    .shadow({ radius: 18, color: ColorTokens.barShadow, offsetY: 8 })
    .clip(true)
  }
}
