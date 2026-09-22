import { resolveActionIcon } from '../utils/actionIcons';
import { formatCount } from '../utils/format';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { MotionCurves, MotionTokens, MotionFrameRates } from '../design/tokens/motion';
import { curves } from '@kit.ArkUI';
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
  // 智感握姿（官方 SmartReach 范式）：底部组件随握持手跟手换边——
  // 右手握持：输入+发送靠右、点赞/收藏靠左；左手握持：整体镜像。
  // holdingHandStatus 由 gripAwareness 写入（1=左手 2=右手 0=未握持/不支持，离手不触发迁移）。
  @StorageProp('holdingHandStatus') @Watch('onHoldingHandChanged') holdingHandStatus: number = 0;
  // 输入组贴边侧：true = 输入+发送靠右（默认右手布局）；false = 靠左（左手镜像）
  @State inputOnRight: boolean = true;
  // 输入聚焦期间收到换边：先挂起、失焦后再翻转 —— 分支重排会重建输入框丢焦点
  @State pendingOnRight: boolean = true;
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
    // 失焦时应用聚焦期间挂起的握姿换边（换边会重建输入框，聚焦期间只能挂起）
    if (!focused && this.pendingOnRight !== this.inputOnRight) {
      this.applyInputSide(this.pendingOnRight);
    }
  }

  // 握持手变化 → 输入组跟手换边（官方 SmartReach 范式：底部组件随握持手左右迁移）。
  // 右手：输入+发送靠右、点赞/收藏靠左；左手：整体镜像。0=未握持/不支持保持当前侧。
  onHoldingHandChanged(): void {
    const wantRight: boolean = this.holdingHandStatus === 2;
    if (wantRight === this.inputOnRight) {
      this.pendingOnRight = wantRight;
      return;
    }
    // 聚焦输入期间换边会重建输入框（if/else 分支重排）丢焦点，先挂起、失焦再翻转
    if (this.inputFocused) {
      this.pendingOnRight = wantRight;
      return;
    }
    this.applyInputSide(wantRight);
  }

  private applyInputSide(right: boolean): void {
    this.pendingOnRight = right;
    if (right === this.inputOnRight) {
      return;
    }
    // 换边动画与 Title 的握姿动画同款：interpolatingSpring 弹性弹簧（带过冲回弹），
    // 分支重排的新旧子元素再走 gripSwapTransition 的方向性滑入/淡出。
    this.getUIContext().animateTo({
      duration: 350,
      curve: curves.interpolatingSpring(0, 1, 170, 17),
    }, (): void => {
      this.inputOnRight = right;
    });
  }

  // 换边转场（对齐 Title 的跟手感）：新旧子元素沿「移动方向」弹性滑动——
  // 新子元素从对侧滑入（**纯滑动，无淡入**），旧子元素向移动方向滑出并淡出。
  // 分支重排是销毁重建，同一节点无法连续滑动——用方向性滑动模拟连续迁移观感。
  private gripSwapTransition(): TransitionEffect {
    // 滑动方向：换到右侧布局（inputOnRight=true）→ 子元素从左（-60）进入、
    // 旧元素向左（-60）退出；换到左侧布局反之。
    const offset: number = this.inputOnRight ? -60 : 60;
    const slide: TransitionEffect = TransitionEffect
      .translate({ x: offset })
      .animation({ curve: curves.interpolatingSpring(0, 1, 170, 17) });
    const slideOut: TransitionEffect = TransitionEffect
      .translate({ x: offset })
      .combine(TransitionEffect.OPACITY)
      .animation({ curve: curves.interpolatingSpring(0, 1, 170, 17) });
    return TransitionEffect.asymmetric(slide, slideOut);
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

  // 点赞/收藏组：整组折叠（宽度 + 透明度 + 外边距一起动画），而不是用 if 把它从布局里摘掉
  @Builder
  actionsGroup() {
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
    // 组与输入框之间的间距：镜像布局时间距朝向输入框的一侧随之翻转
    .margin(this.inputFocused
      ? { left: 0, right: 0 }
      : (this.inputOnRight ? { right: SpaceTokens.md } : { left: SpaceTokens.md }))
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
    .transition(this.gripSwapTransition())
  }

  @Builder
  inputField() {
    GlowInput({ placeholder: this.replyName.length > 0 ? ('回复 @' + this.replyName) : '说点什么…',
      text: $commentText, fillWidth: true, inputHeight: COMPACT_CONTROL_HEIGHT, radius: RadiusTokens.sm,
      fontSize: 14, segmentStyle: true,
      onFocusChanged: (focused: boolean): void => { this.applyFocusLayout(focused); },
      onEnter: (): void => { this.onSendComment(); } })
  }

  @Builder
  sendButton() {
    Text('发送').height(COMPACT_CONTROL_HEIGHT)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.headline.weight).fontColor(ColorTokens.onBrand)
      .backgroundColor(ColorTokens.brand).borderRadius(RadiusTokens.pill)
      // 间距朝输入框一侧：镜像时翻转
      .margin(this.inputOnRight ? { left: SpaceTokens.md } : { right: SpaceTokens.md })
      .onClick((): void => { this.onSendComment(); })
      .transition(this.gripSwapTransition())
  }

  @Builder
  cancelButton() {
    // 取消键：同样折叠而不是 if 摘除（宽度固定 36，直接数值插值）
    Row() {
      Text('×').width(COMPACT_ROW_HEIGHT).height(COMPACT_ROW_HEIGHT)
        .fontSize(22).textAlign(TextAlign.Center).fontColor(ColorTokens.secondary)
        .onClick((): void => { this.collapseCancel(); this.onCancelReply(); })
    }
    .width(this.showCancel() ? COMPACT_ROW_HEIGHT : 0)
    .opacity(this.showCancel() ? 1 : 0)
    .clip(true)
    .margin(this.showCancel()
      ? (this.inputOnRight ? { left: SpaceTokens.md } : { right: SpaceTokens.md })
      : { left: 0, right: 0 })
    .hitTestBehavior(this.showCancel() ? HitTestMode.Default : HitTestMode.None)
    .transition(this.gripSwapTransition())
  }

  build() {
    // 注意：不用 Row({ space })，间距全走各子元素自己的 margin（可插值）。
    // 智感握姿：输入组随握持手换边（右手=输入在右；左手=输入在左），
    // 分支重排时子元素走 gripSwapTransition 淡入淡出。
    Row() {
      if (this.inputOnRight) {
        this.actionsGroup()
        this.inputField()
        this.sendButton()
        this.cancelButton()
      } else {
        this.cancelButton()
        this.sendButton()
        this.inputField()
        this.actionsGroup()
      }
    }
    .width('100%')
    .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
    // 毛玻璃底栏：GlassBlurStyle.Floating = BACKGROUND_THICK 通透厚玻璃——
    // 自带系统着色与半透明，重糊但略微透出底部内容；API 23+ 纯材质，
    // 低端机回落 barSurface 实底；玻璃描边勾出栏体边界。
    .backgroundBlurStyle(GlassBlurStyle.Floating)
    .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
    .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
    .borderRadius(RadiusTokens.none)
    .animation({ duration: MotionTokens.container, curve: MotionCurves.springInteract,
      expectedFrameRateRange: MotionFrameRates.default })
  }
}
