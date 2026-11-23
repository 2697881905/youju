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
        // 昵称是本行的弹性余量：外层（PostCard footer 行）压缩本组件时，嵌套 Row 的子元素
        // flexShrink 默认同样是 0，必须显式声明昵称可收缩，压缩量才会落成「昵称截断」
        // 而不是把头像压扁；头像恒完整（flexShrink 0）。
        Text(this.name)
          .fontSize(this.compact ? TypeTokens.overline.size : TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .letterSpacing(TypeTokens.caption.tracking)
          .fontColor(ColorTokens.secondary)
          .constraintSize({ maxWidth: this.compact ? 64 : 132 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .flexShrink(1)
        Avatar({
          avatar: this.avatar,
          name: this.name,
          avatarSize: this.compact ? 20 : IconTokens.avatarCompact,
        })
          .flexShrink(0)
      }
      .alignItems(VerticalAlign.Center)
    }
  }
}
