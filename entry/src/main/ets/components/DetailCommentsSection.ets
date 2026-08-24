import { Comment } from '../models/types';
import { formatCount } from '../utils/format';
import { CommentList } from './CommentList';
import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct DetailCommentsSection {
  @Prop comments: Comment[] = [];
  @Prop commentCount: number = 0;
  onReportComment: (commentId: number) => void = (_commentId: number): void => {};

  build() {
    Column({ space: SpaceTokens.item }) {
      Divider().color(ColorTokens.separator)
      Text('评论 ' + formatCount(this.commentCount))
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.primary)
      CommentList({
        comments: this.comments,
        reportCommentHandler: (commentId: number): void => { this.onReportComment(commentId); },
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
