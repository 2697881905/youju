import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { MentionRef } from '../models/types';
import { HighlightedText } from './HighlightedText';

// 标题纯文字层：底色/边框/圆角由外层信息区统一提供（PostCard 中与点赞/作者合并为一块）。
// 标题里若含 @提及 / #话题# 由 HighlightedText 负责着色与点击（提及蓝、话题棕）。
@Component
export struct PostCardTitle {
  @Prop title: string = '';
  @Prop compact: boolean = false;
  // 来自 post.mentions：有它才能把 @昵称 精确映射到 userId（否则退回按昵称搜索）
  @Prop mentions: MentionRef[] = [];

  build() {
    Column({ space: this.compact ? SpaceTokens.inlineTight : SpaceTokens.sm }) {
      HighlightedText({
        text: this.title,
        mentions: this.mentions,
        fontSize: this.compact ? TypeTokens.body.size + 2 : TypeTokens.headline.size,
        lineHeight: this.compact ? 24 : TypeTokens.headline.lineHeight,
        letterSpacing: TypeTokens.headline.tracking,
        maxLines: 2,
        serif: true,
        bold: true,
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
