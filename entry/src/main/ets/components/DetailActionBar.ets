import { resolveActionIcon } from '../utils/actionIcons';
import { formatCount } from '../utils/format';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { Pressable } from '../design/motion/Pressable';

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
        Image(this.icon)
          .width(IconTokens.small)
          .height(IconTokens.small)
          .fillColor(this.active ? this.activeColor : ColorTokens.secondary)
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
  onUp: () => void = (): void => {};
  onBookmark: () => void = (): void => {};
  onSendComment: () => void = (): void => {};
  onShare: () => void = (): void => {};

  build() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        // 与主页底部栏共用同一层玻璃高光，操作内容始终在同一块悬浮面板内切换。
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [
              [ColorTokens.glassSheenTop, 0.0],
              [ColorTokens.glassSheenUpper, 0.32],
              [ColorTokens.glassSheenLower, 0.68],
              [ColorTokens.glassSheenBottom, 1.0],
            ],
          })
          .hitTestBehavior(HitTestMode.None)

        if (this.commenting) {
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
            .onClick((): void => { this.commenting = false; this.commentText = ''; })
            TextInput({ placeholder: '理性补充，有图有真相', text: this.commentText })
              .fontFamily(TypeTokens.fontFamily)
              .layoutWeight(1)
              .height(LayoutTokens.minTouchTarget)
              .backgroundColor(ColorTokens.elevated)
              .borderRadius(RadiusTokens.floatingBar)
              .onChange((value: string): void => { this.commentText = value; })
            Text('发送')
              .width(56)
              .height(LayoutTokens.minTouchTarget)
              .textAlign(TextAlign.Center)
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(ColorTokens.onBrand)
              .backgroundColor(ColorTokens.brand)
              .borderRadius(RadiusTokens.floatingBar)
              .onClick((): void => { this.onSendComment(); })
          }
          .width('100%')
          .height('100%')
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
          .alignItems(VerticalAlign.Center)
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
      .layoutWeight(1)
      .height(LayoutTokens.tabBarHeight)
      .backdropBlur(LayoutTokens.glassBlur)
      .backgroundColor(ColorTokens.barSurface)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.floatingBar)
      .shadow({ radius: 22, color: ColorTokens.barShadow, offsetY: 10 })
      .clip(true)
    }
    .width('100%')
    .height(LayoutTokens.tabBarHeight + LayoutTokens.tabBarBottomGap)
    .padding({ left: LayoutTokens.tabBarSideMargin, right: LayoutTokens.tabBarSideMargin })
    .alignItems(VerticalAlign.Top)
  }
}
