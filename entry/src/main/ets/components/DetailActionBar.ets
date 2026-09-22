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
      // 固定 LTR：图标恒在文字左侧——父层镜像（Rtl）时不跟随翻转
      .direction(Direction.Ltr)
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
  // 点赞/收藏按钮组的自然宽度（未聚焦时实测一次）：输入层的让位 padding 用它计算
  @State actionsW: number = 0;
  // 智感握姿（官方 SmartReach 范式）：输入+发送 与 点赞/收藏 两组随握持手互换侧别，
  // 且两组是**持久节点**——换边只变对齐/方向/让位 padding（全部可插值的布局属性），
  // 在 animateTo 内连续滑动（Title 同款），无节点销毁重建、无叠化、焦点不丢。
  // holdingHandStatus 由 gripAwareness 写入（1=左手 2=右手 0=未握持/不支持，离手不触发迁移）。
  @StorageProp('holdingHandStatus') @Watch('onHoldingHandChanged') holdingHandStatus: number = 0;
  // 布局侧：true = 输入+发送靠右（默认右手布局）；false = 靠左（左手镜像）。
  // 驱动：层1 justifyContent（点赞/收藏滑动）+ 层2 direction（发送始终靠拇指侧）。
  @State inputOnRight: boolean = true;
  // 让位 padding 的方向：与 inputOnRight 分开动画（450ms，慢一拍）——
  // 发送随对齐弹簧先到位，输入框的让位/展宽随后跟上（错峰）。
  @State padOnRight: boolean = true;
  onUp: () => void = (): void => {};
  onBookmark: () => void = (): void => {};
  onSendComment: () => void = (): void => {};
  onCancelReply: () => void = (): void => {};

  // 取消键是否可见（聚焦展开时让位）
  private showCancel(): boolean {
    return this.commenting && !this.inputFocused;
  }

  // 输入层的让位宽度：点赞/收藏组自然宽 + 间距；聚焦时归零（输入框铺满整行）
  private actionsReserve(): number {
    return this.inputFocused ? 0 : (this.actionsW > 0 ? this.actionsW + SpaceTokens.md : 0);
  }

  /* 聚焦/失焦：折叠点赞/收藏层 + 让位 padding 归零。必须在 animateTo 内（布局属性逐帧插值）。
   * 依据官方 component-collection 布局动效：width/padding 放进 animateTo 逐帧插值，
   * 输入框的 layoutWeight 随让位 padding 连续变化 → 平滑铺满。 */
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

  // 握持手变化 → 两组跟手换边（官方 SmartReach 范式）。两次 animateTo 错峰：
  // 对齐/方向（发送随动、先到位）用 350 弹性弹簧（与 Title 握姿动画同款）；
  // 输入层让位 padding 用 450 —— 发送先到，输入框随后跟上。
  // 全程无节点重建：输入聚焦期间换边也安全（输入框带着焦点一起滑动）。
  onHoldingHandChanged(): void {
    const right: boolean = this.holdingHandStatus === 2;
    if (right === this.inputOnRight) {
      return;
    }
    this.getUIContext().animateTo({
      duration: 350,
      curve: curves.interpolatingSpring(0, 1, 170, 17),
    }, (): void => {
      this.inputOnRight = right;
    });
    this.getUIContext().animateTo({
      duration: 450,
      curve: MotionCurves.springInteract,
    }, (): void => {
      this.padOnRight = right;
    });
  }

  build() {
    // 两层 Stack：层1 点赞/收藏（对齐侧翻转）、层2 输入+发送+取消（让位 padding + 方向镜像）。
    // 全部是**属性变化**（justifyContent/padding/direction），无节点销毁重建——
    // 在 animateTo 内连续滑动（Title 同款）。
    // 注意：不用 Row({ space })，间距全走各子元素自己的 margin（镜像时可控）。
    Stack() {
      // 层1：点赞/收藏组
      Row() {
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
        .onAreaChange((_oldValue: Area, newValue: Area): void => {
          if (this.inputFocused) {
            return;
          }
          const w: number = parseFloat(String(newValue.width));
          if (w > 0 && Math.abs(w - this.actionsW) > 0.5) {
            this.actionsW = w;
          }
        })
      }
      .width('100%')
      .justifyContent(this.inputOnRight ? FlexAlign.Start : FlexAlign.End)
      .opacity(this.inputFocused ? 0 : 1)
      .hitTestBehavior(this.inputFocused ? HitTestMode.None : HitTestMode.Default)

      // 层2：输入框 + 发送 + 取消键（不用 Row({space})，间距走 margin——镜像时可控）
      Row() {
        GlowInput({ placeholder: this.replyName.length > 0 ? ('回复 @' + this.replyName) : '说点什么…',
          text: $commentText, fillWidth: true, inputHeight: COMPACT_CONTROL_HEIGHT, radius: RadiusTokens.sm,
          fontSize: 14, segmentStyle: true,
          onFocusChanged: (focused: boolean): void => { this.applyFocusLayout(focused); },
          onEnter: (): void => { this.onSendComment(); } })
          .layoutWeight(1)

        Text('发送').height(COMPACT_CONTROL_HEIGHT)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight).fontColor(ColorTokens.onBrand)
          .backgroundColor(ColorTokens.brand).borderRadius(RadiusTokens.pill)
          // 间距朝输入框一侧：镜像时翻转
          .margin(this.inputOnRight ? { left: SpaceTokens.md } : { right: SpaceTokens.md })
          .onClick((): void => { this.onSendComment(); })

        // 取消键：宽度 36 ↔ 0 折叠（镜像时留白边朝向翻转）
        Row() {
          Text('×').width(COMPACT_ROW_HEIGHT).height(COMPACT_ROW_HEIGHT)
            .fontSize(22).textAlign(TextAlign.Center).fontColor(ColorTokens.secondary)
            .onClick((): void => { this.collapseCancel(); this.onCancelReply(); })
        }
        .width(this.showCancel() ? COMPACT_ROW_HEIGHT : 0)
        .opacity(this.showCancel() ? 1 : 0)
        .clip(true)
        .margin(this.inputOnRight
          ? { left: this.showCancel() ? SpaceTokens.md : 0 }
          : { right: this.showCancel() ? SpaceTokens.md : 0 })
      }
      .width('100%')
      .padding({
        left: this.padOnRight ? this.actionsReserve() : 0,
        right: this.padOnRight ? 0 : this.actionsReserve(),
      })
      .direction(this.inputOnRight ? Direction.Ltr : Direction.Rtl)
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
  }
}
