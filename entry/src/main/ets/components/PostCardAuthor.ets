import { Avatar } from '../design/components/Avatar';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct PostCardAuthor {
  @Prop name: string = '';
  @Prop avatar: string = '';
  @Prop compact: boolean = false;
  onOpen: () => void = (): void => {};

  build() {
    Pressable({
      visualHeight: IconTokens.compact,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: (): void => { this.onOpen(); },
    }) {
      Row({ space: SpaceTokens.inlineTight }) {
        Text(this.name)
          .fontSize(this.compact ? TypeTokens.overline.size : TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .letterSpacing(TypeTokens.caption.tracking)
          .fontColor(ColorTokens.secondary)
          .constraintSize({ maxWidth: this.compact ? 88 : 132 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Avatar({
          avatar: this.avatar,
          name: this.name,
          avatarSize: this.compact ? 20 : IconTokens.avatarCompact,
        })
      }
      .alignItems(VerticalAlign.Center)
    }
  }
}
