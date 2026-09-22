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
        Image(this.active ? this.activeIcon : this.icon).width(this.iconSize).height(this.iconSize)
        Text(this.label).fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(this.active ? this.activeColor : ColorTokens.secondary).maxLines(1)
      }
      .height(COMPACT_ROW_HEIGHT)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      .borderRadius(RadiusTokens.sm)
      .backgroundColor(this.active ? ColorTokens.brandTint : Color.Transparent)
      .opacity(this.disabled ? 0.55 : 1)
      .scale({ x: this.confirmationScale, y: this.confirmationScale })
      .animation({ duration: this.reduceMotion() ? MotionTokens.instant : MotionTokens.control,
        curve: MotionCurves.springBounce, expectedFrameRateRange: MotionFrameRates.default })
    }
  }
}

@Component
struct DetailCommentInput {
  @Link text: string;
  @Prop replyName: string = '';
  onFocusChanged?: (focused: boolean) => void = undefined;
  onSend: () => void = (): void => {};
  build() {
    GlowInput({ placeholder: this.replyName.length > 0 ? ('回复 @' + this.replyName) : '说点什么…',
      text: $text, fillWidth: true, inputHeight: COMPACT_CONTROL_HEIGHT, radius: RadiusTokens.sm,
      segmentStyle: true, onFocusChanged: (focused: boolean): void => {
        if (this.onFocusChanged !== undefined) this.onFocusChanged(focused);
      }, onEnter: (): void => { this.onSend(); } })
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
  onUp: () => void = (): void => {};
  onBookmark: () => void = (): void => {};
  onSendComment: () => void = (): void => {};
  onCancelReply: () => void = (): void => {};

  build() {
    Row({ space: SpaceTokens.md }) {
      if (!this.inputFocused) {
        DetailActionButton({ icon: resolveActionIcon('like'), activeIcon: resolveActionIcon('likeActive'),
          label: formatCount(this.upCount), active: this.uped, activeColor: ColorTokens.like,
          disabled: this.upPending, feedbackVersion: this.upFeedbackVersion,
          iconSize: 24, onAction: (): void => { this.onUp(); } })
        DetailActionButton({ icon: resolveActionIcon('bookmark'), activeIcon: resolveActionIcon('bookmarkActive'),
          label: formatCount(this.bookmarkCount), active: this.bookmarked, activeColor: ColorTokens.bookmark,
          disabled: this.bookmarkPending, feedbackVersion: this.bookmarkFeedbackVersion,
          iconSize: 24, onAction: (): void => { this.onBookmark(); } })
      }
      GlowInput({ placeholder: this.replyName.length > 0 ? ('回复 @' + this.replyName) : '说点什么…',
        text: $commentText, fillWidth: true, inputHeight: COMPACT_CONTROL_HEIGHT, radius: RadiusTokens.sm,
        fontSize: 14, segmentStyle: true, onFocusChanged: (focused: boolean): void => { this.inputFocused = focused; },
        onEnter: (): void => { this.onSendComment(); } })
      Text('发送').height(COMPACT_CONTROL_HEIGHT)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight).fontColor(ColorTokens.onBrand)
        .backgroundColor(ColorTokens.brand).borderRadius(RadiusTokens.pill)
        .onClick((): void => { this.onSendComment(); })
      if (this.commenting && !this.inputFocused) {
        Text('×').width(COMPACT_ROW_HEIGHT).height(COMPACT_ROW_HEIGHT)
          .fontSize(22).textAlign(TextAlign.Center).fontColor(ColorTokens.secondary)
          .onClick((): void => { this.commenting = false; this.commentText = ''; this.onCancelReply(); })
      }
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
