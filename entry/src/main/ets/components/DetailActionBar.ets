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
import { GlassBlurStyle, isImmersiveLightSenseSupported } from '../utils/immersiveMaterial';

// 评论态压缩：视觉高度下调，触控目标由 Pressable touchTargetHeight 保持 44 不变
const COMPACT_CONTROL_HEIGHT: number = 32; // 输入框 / 发送键视觉高
const COMPACT_ROW_HEIGHT: number = 36;     // 操作行 / 关闭键视觉高

@Component
struct DetailActionButton {
  @Prop icon: Resource = resolveActionIcon('like');
  @Prop activeIcon: Resource = resolveActionIcon('like');
  @Prop label: string = '';
  @Prop active: boolean = false;
  @Prop disabled: boolean = false;
  @Prop activeColor: ResourceColor = ColorTokens.brand;
  @Prop @Watch('onFeedbackChanged') feedbackVersion: number = 0;
  @Prop iconSize: number = 22;
  @State confirmationScale: number = 1;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  onAction: () => void = (): void => {};
  private resetTimer: number = 0;
  aboutToDisappear(): void { if (this.resetTimer !== 0) clearTimeout(this.resetTimer); }
  private reduceMotion(): boolean { return this.appReduceMotion || this.systemReduceMotion; }
  private onFeedbackChanged(): void {
    if (this.feedbackVersion === 0 || this.reduceMotion()) return;
    if (this.resetTimer !== 0) clearTimeout(this.resetTimer);
    this.confirmationScale = MotionTokens.successScale;
    this.resetTimer = setTimeout((): void => {
      this.confirmationScale = 1;
      this.resetTimer = 0;
    }, MotionTokens.control) as number;
  }
  build() {
    Pressable({ disabled: this.disabled, visualHeight: COMPACT_ROW_HEIGHT,
      touchTargetHeight: LayoutTokens.minTouchTarget, action: (): void => { this.onAction(); } }) {
      Row({ space: SpaceTokens.xs }) {
        Image(this.active ? this.activeIcon : this.icon).width(this.iconSize).height(this.iconSize).fillColor(this.active ? this.activeColor : ColorTokens.secondary)
        Text(this.label).fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(this.active ? this.activeColor : ColorTokens.secondary).maxLines(1)
      }
      .height(COMPACT_ROW_HEIGHT)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      // 不再给活跃态铺底色：原先是 brandTint 圆角矩形，点赞/收藏点亮时会在按钮范围出现一层蒙层。
      // 状态表达只保留「图标换实心款 + 颜色变 activeColor + 数字变色」；
      // 按压反馈由外层 Pressable 的 stateStyles（透明度 + 缩放）承担，不需要底色。
      .opacity(this.disabled ? 0.55 : 1)
      .scale({ x: this.confirmationScale, y: this.confirmationScale })
      .animation({ duration: this.reduceMotion() ? MotionTokens.instant : MotionTokens.control,
        curve: MotionCurves.springBounce, expectedFrameRateRange: MotionFrameRates.default })
    }
  }
}

@Component
export struct DetailActionBar {
  @Link commenting: boolean;
  @Link commentText: string;
  @Prop upCount: number = 0;
  @Prop bookmarkCount: number = 0;
  @Prop uped: boolean = false;
  @Prop bookmarked: boolean = false;
  @Prop upPending: boolean = false;
  @Prop bookmarkPending: boolean = false;
  @Prop upFeedbackVersion: number = 0;
  @Prop bookmarkFeedbackVersion: number = 0;
  @Prop replyName: string = '';
  @State inputFocused: boolean = false;
  // 点赞/收藏按钮组的自然宽度（未聚焦时实测一次）。聚焦时把它动画到 0，
  // 输入框就在逐帧布局中平滑铺满整行 —— 见 focusExpand/focusCollapse 的注释。
  @State actionsW: number = 0;
  onUp: () => void = (): void => {};
  onBookmark: () => void = (): void => {};
  onSendComment: () => void = (): void => {};
  onCancelReply: () => void = (): void => {};

  // 取消键是否可见（聚焦展开时让位）
  private showCancel(): boolean {
    return this.commenting && !this.inputFocused;
  }

  /* 聚焦/失焦时的展开与收起：**必须包在 animateTo 里**，布局属性才会逐帧插值。
   * 依据官方 component-collection 的「布局动效」（LayoutAnimationSample）与「尺寸变换动效」
   * （SizeTransitionSample）：width / margin / padding 等布局属性放在 animateTo 中改，
   * ArkUI 会每帧重新布局并插值 —— 兄弟元素的宽度与外边距一变，输入框的 layoutWeight 就跟着连续变化，
   * 于是「输入框拉伸铺满一行」有了过渡，而不是瞬间回流。
   */
  private applyFocusLayout(focused: boolean): void {
    this.getUIContext().animateTo({
      duration: MotionTokens.container,
      curve: MotionCurves.springInteract,
      expectedFrameRateRange: MotionFrameRates.default,
    }, (): void => {
      this.inputFocused = focused;
    });
  }

  private collapseCancel(): void {
    this.getUIContext().animateTo({
      duration: MotionTokens.container,
      curve: MotionCurves.springInteract,
      expectedFrameRateRange: MotionFrameRates.default,
    }, (): void => {
      this.commenting = false;
      this.commentText = '';
    });
  }

  build() {
    // 注意：这里不用 Row({ space })。space 由父容器插入、不随子元素折叠而收缩，
    // 会让输入框差一段间距铺不满；改用各子元素自己的 margin（margin 是 animateTo 可插值的布局属性）。
    Row() {
      // 点赞/收藏：整组折叠（宽度 + 透明度 + 外边距一起动画），而不是用 if 把它从布局里摘掉
      Row({ space: SpaceTokens.md }) {
        DetailActionButton({ icon: resolveActionIcon('like'), activeIcon: resolveActionIcon('likeActive'),
          label: formatCount(this.upCount), active: this.uped, activeColor: ColorTokens.like,
          disabled: this.upPending, feedbackVersion: this.upFeedbackVersion,
          iconSize: 24, onAction: (): void => { this.onUp(); } })
        DetailActionButton({ icon: resolveActionIcon('bookmark'), activeIcon: resolveActionIcon('bookmarkActive'),
          label: formatCount(this.bookmarkCount), active: this.bookmarked, activeColor: ColorTokens.bookmark,
          disabled: this.bookmarkPending, feedbackVersion: this.bookmarkFeedbackVersion,
          iconSize: 24, onAction: (): void => { this.onBookmark(); } })
      }
      // actionsW 实测前用 'auto'（内容宽度）兜底，实测后一律走数值，保证 0 ↔ 自然宽 是纯数值插值
      .width(this.inputFocused ? 0 : (this.actionsW > 0 ? this.actionsW : 'auto'))
      .opacity(this.inputFocused ? 0 : 1)
      .clip(true)
      .margin({ right: this.inputFocused ? 0 : SpaceTokens.md })
      .hitTestBehavior(this.inputFocused ? HitTestMode.None : HitTestMode.Default)
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        if (this.inputFocused) {
          return;
        }
        const w: number = parseFloat(String(newValue.width));
        if (w > 0 && Math.abs(w - this.actionsW) > 0.5) {
          this.actionsW = w;
        }
      })

      GlowInput({ placeholder: this.replyName.length > 0 ? ('回复 @' + this.replyName) : '说点什么…',
        text: $commentText, fillWidth: true, inputHeight: COMPACT_CONTROL_HEIGHT, radius: RadiusTokens.sm,
        fontSize: 14, segmentStyle: true,
        onFocusChanged: (focused: boolean): void => { this.applyFocusLayout(focused); },
        onEnter: (): void => { this.onSendComment(); } })

      Text('发送').height(COMPACT_CONTROL_HEIGHT)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight).fontColor(ColorTokens.onBrand)
        .backgroundColor(ColorTokens.brand).borderRadius(RadiusTokens.pill)
        .margin({ left: SpaceTokens.md })
        .onClick((): void => { this.onSendComment(); })

      // 取消键：同样折叠而不是 if 摘除（宽度固定 36，直接数值插值）
      Row() {
        Text('×').width(COMPACT_ROW_HEIGHT).height(COMPACT_ROW_HEIGHT)
          .fontSize(22).textAlign(TextAlign.Center).fontColor(ColorTokens.secondary)
          .onClick((): void => { this.collapseCancel(); this.onCancelReply(); })
      }
      .width(this.showCancel() ? COMPACT_ROW_HEIGHT : 0)
      .opacity(this.showCancel() ? 1 : 0)
      .clip(true)
      .margin({ left: this.showCancel() ? SpaceTokens.md : 0 })
      .hitTestBehavior(this.showCancel() ? HitTestMode.Default : HitTestMode.None)
    }
    .width('100%')
    .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
    .backgroundBlurStyle(GlassBlurStyle.Floating)
    .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
    .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
    .borderRadius(RadiusTokens.none)
    .animation({ duration: MotionTokens.container, curve: MotionCurves.springInteract,
      expectedFrameRateRange: MotionFrameRates.default })
  }
}
