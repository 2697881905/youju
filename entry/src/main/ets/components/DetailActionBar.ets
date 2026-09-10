import { resolveActionIcon } from '../utils/actionIcons';
import { formatCount } from '../utils/format';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { Pressable } from '../design/motion/Pressable';
import { GlowInput } from '../design/components/GlowInput';

@Component
struct DetailActionButton {
  @Prop icon: Resource = resolveActionIcon('like');
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
        // 一律主题线条图标（激活/未激活同形），状态色由下方文字表达（保留反馈缩放动效）
        Image(this.icon)
          .width(IconTokens.small)
          .height(IconTokens.small)
        Text(this.label)
          .fontSize(TypeTokens.navLabel.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(this.active ? this.activeColor : ColorTokens.secondary)
          .maxLines(1)
      }
      .width('100%')
      .height(LayoutTokens.minTouchTarget)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .opacity(this.disabled ? 0.6 : 1)
      .scale({ x: this.confirmationScale, y: this.confirmationScale })
      .animation({
        duration: this.reduceMotion() ? MotionTokens.instant : MotionTokens.control,
        curve: MotionCurves.spring,
      })
    }
  }
}

// 固定底部操作层只负责呈现状态；请求、乐观更新和失败回滚属于 DetailPage。
@Component
export struct DetailActionBar {
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
    // 无玻璃栏：仅保留点赞/收藏/评论/分享操作内容（评论输入态就地切换）
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
      .height('100%')
      .justifyContent(FlexAlign.Center)
      } else {
        Row() {
          DetailActionButton({ icon: resolveActionIcon('like'), label: formatCount(this.upCount), active: this.uped, activeColor: ColorTokens.like, disabled: this.upPending, feedbackVersion: this.upFeedbackVersion, onAction: (): void => { this.onUp(); } }).layoutWeight(1)
          DetailActionButton({ icon: resolveActionIcon('bookmark'), label: formatCount(this.bookmarkCount), active: this.bookmarked, activeColor: ColorTokens.bookmark, disabled: this.bookmarkPending, feedbackVersion: this.bookmarkFeedbackVersion, onAction: (): void => { this.onBookmark(); } }).layoutWeight(1)
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
    .height(LayoutTokens.tabBarHeight)
  }
}
