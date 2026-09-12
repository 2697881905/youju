import { formatCount } from '../../utils/format';
import { resolveActionIcon } from '../../utils/actionIcons';
import { Pressable } from '../motion/Pressable';
import { CountRoll } from '../motion/CountRoll';
import { MotionCurves, MotionTokens, MotionFrameRates } from '../tokens/motion';
import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

@Component
export struct StatRow {
  @Prop @Watch('onLikedChanged') liked: boolean = false;
  @Prop likeCount: number = 0;
  @Prop commentCount: number = 0;
  @Prop showComment: boolean = true;
  @Prop compact: boolean = false;
  onLike?: () => void = undefined;
  // 点赞成功反馈：图标弹性缩放脉冲（GSAP 风格 Yoyo），与 pressed 缩放互不冲突
  @State animLikePulse: number = 1;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;

  private reduceMotion(): boolean {
    return this.appReduceMotion || this.systemReduceMotion;
  }

  // 点赞态翻转（乐观更新广播回写）时播放：1 → successScale → 1 的一次往返弹性脉冲
  private onLikedChanged(): void {
    if (!this.liked || this.reduceMotion()) {
      return;
    }
    this.getUIContext().animateTo({
      duration: MotionTokens.base,
      curve: MotionCurves.springBounce,          // 明显回弹（springMotion(0.4, 0.7)）
      playMode: PlayMode.Alternate,              // 往返播放（GSAP Yoyo 映射）
      iterations: 2,                             // 1 → 1.045 → 1
      expectedFrameRateRange: MotionFrameRates.default,
    }, () => {
      this.animLikePulse = MotionTokens.successScale;
    });
  }

  build() {
    Row({ space: SpaceTokens.block }) {
      Pressable({
        visualHeight: IconTokens.compact,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        action: () => {
          if (this.onLike !== undefined) {
            this.onLike();
          }
        },
      }) {
        Row({ space: SpaceTokens.inlineTight }) {
          Image(resolveActionIcon('like'))
            .width(this.compact ? 14 : IconTokens.compact)
            .height(this.compact ? 14 : IconTokens.compact)
            .scale({ x: this.animLikePulse, y: this.animLikePulse })
          CountRoll({
            value: this.likeCount,
            prefix: '顶 ',
            textSize: this.compact ? TypeTokens.overline.size : TypeTokens.caption.size,
            textColor: this.liked ? ColorTokens.like : ColorTokens.tertiary,
          })
        }
        .borderRadius(RadiusTokens.xs)
        .alignItems(VerticalAlign.Center)
      }

      if (this.showComment) {
        Row({ space: SpaceTokens.inlineTight }) {
          Image(resolveActionIcon('comment'))
            .width(IconTokens.compact)
            .height(IconTokens.compact)
          Text(formatCount(this.commentCount))
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .letterSpacing(TypeTokens.caption.tracking)
            .fontFeature(TypeTokens.tabularFeature)
            .fontColor(ColorTokens.tertiary)
        }
        .alignItems(VerticalAlign.Center)
      }
    }
    .alignItems(VerticalAlign.Center)
  }
}
