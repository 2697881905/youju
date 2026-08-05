import { formatCount } from '../../utils/format';
import { resolveActionIcon } from '../../utils/actionIcons';
import { Pressable } from '../motion/Pressable';
import { CountRoll } from '../motion/CountRoll';
import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

@Component
export struct StatRow {
  @Prop liked: boolean = false;
  @Prop likeCount: number = 0;
  @Prop commentCount: number = 0;
  @Prop showComment: boolean = true;
  @Prop compact: boolean = false;
  onLike?: () => void = undefined;

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
            .fillColor(this.liked ? ColorTokens.brand : ColorTokens.tertiary)
          CountRoll({
            value: this.likeCount,
            prefix: '顶 ',
            textSize: this.compact ? TypeTokens.overline.size : TypeTokens.caption.size,
            textColor: this.liked ? ColorTokens.brand : ColorTokens.tertiary,
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
            .fillColor(ColorTokens.tertiary)
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
