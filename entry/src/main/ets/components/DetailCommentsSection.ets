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
  // 通知跳转定位的目标评论 id（>0 时该条短暂高亮，见 CommentList）
  @Prop highlightCommentId: number = 0;
  // 帖子作者 id（透传给 CommentList：帖主可直接删除自己帖子下的评论）
  @Prop postAuthorId: number = 0;
  onReportComment: (commentId: number) => void = (_commentId: number): void => {};
  onReplyComment: (comment: Comment) => void = (_comment: Comment): void => {};
  // 删除成功回调（CommentList → 详情页，同步 post.comments / commentCount）
  onDeletedComment: (comment: Comment) => void = (_comment: Comment): void => {};

  build() {
    Column({ space: SpaceTokens.item }) {
      Divider().color(ColorTokens.separator)
      Text('评论 ' + formatCount(this.commentCount))
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.primary)
      CommentList({
        comments: this.comments,
        highlightCommentId: this.highlightCommentId,
        postAuthorId: this.postAuthorId,
        reportCommentHandler: (commentId: number): void => { this.onReportComment(commentId); },
        onReplyComment: (cmt: Comment): void => { this.onReplyComment(cmt); },
        onDeleted: (cmt: Comment): void => { this.onDeletedComment(cmt); },
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
