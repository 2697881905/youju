// 评论列表组件（盖楼式展示，含"事实补充"徽标 + 举报入口）
import { Comment } from '../models/types';
import { timeAgo, formatCount } from '../utils/format';

@Component
export struct CommentList {
  @Prop comments: Comment[] = [];
  // 举报回调（由 DetailPage 传入，打开 ReportDialog）
  reportCommentHandler: (commentId: number) => void = (_id: number) => {};

  @Builder
  avatar(c: Comment) {
    if (c.user?.avatar) {
      Image(c.user.avatar)
        .width(36)
        .height(36)
        .borderRadius(18)
        .objectFit(ImageFit.Cover)
    } else {
      Text((c.user?.nickname ?? '匿').slice(0, 1))
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor($r('app.color.brand_primary'))
        .fontColor(Color.White)
        .fontSize(14)
        .textAlign(TextAlign.Center)
    }
  }

  build() {
    Column({ space: 12 }) {
      if (this.comments.length === 0) {
        Text('还没有评论，来抢沙发')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      } else {
        ForEach(
          this.comments,
          (c: Comment) => {
            Row({ space: 10 }) {
              this.avatar(c)
              Column({ space: 4 }) {
                Row({ space: 6 }) {
                  Text(c.user?.nickname ?? '匿名用户')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_secondary'))
                  if (c.isFact === 1) {
                    Text('事实补充')
                      .fontSize(11)
                      .fontColor($r('app.color.brand_primary'))
                      .border({ width: 0.5, color: $r('app.color.brand_primary') })
                      .borderRadius(4)
                      .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                  }
                }
                Text(c.content ?? '')
                  .fontSize(15)
                  .fontColor($r('app.color.text_primary'))
                Text(timeAgo(c.createdAt) + ' · ' + formatCount(c.upCount) + ' 顶')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              // 举报入口
              Text('⋯')
                .fontSize(18)
                .fontColor($r('app.color.text_secondary'))
                .width(32)
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  this.getUIContext().showAlertDialog({
                    title: '操作',
                    message: '请选择操作',
                    primaryButton: {
                      value: '举报该评论',
                      fontColor: '#FF453A',
                      action: (): void => {
                        if (c.id !== undefined) {
                          this.reportCommentHandler(c.id);
                        }
                      },
                    },
                    secondaryButton: {
                      value: '取消',
                      action: (): void => {},
                    },
                  });
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          },
          (c: Comment) => c.id?.toString() ?? ''
        )
      }
    }
    .width('100%')
  }
}
