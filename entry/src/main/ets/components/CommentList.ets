// 评论列表组件（盖楼式展示，含"事实补充"徽标 + 举报入口 + 作者删除）
import { Comment } from '../models/types';
import { timeAgo, formatCount } from '../utils/format';
import { getUserId } from '../utils/auth';
import { deleteComment, upComment } from '../services/api';
import { safeShowToast } from '../utils/toast';

@Component
export struct CommentList {
  @Prop comments: Comment[] = [];
  // 举报回调（由 DetailPage 传入，打开 ReportDialog）
  reportCommentHandler: (commentId: number) => void = (_id: number) => {};

  // 删除评论：二次确认 → 调 API → 乐观移除
  private onDeleteComment(c: Comment): void {
    this.getUIContext().showAlertDialog({
      title: '删除评论？',
      message: '删除后不可恢复，确定要删除吗？',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '确认删除', fontColor: '#FF453A', action: async (): Promise<void> => {
        try {
          if (c.id !== undefined) {
            await deleteComment(c.id);
          }
          // 乐观移除：从列表中剔除该评论
          const idx: number = this.comments.indexOf(c);
          if (idx >= 0) {
            this.comments.splice(idx, 1);
          }
          safeShowToast(this.getUIContext(), { message: '评论已删除' });
        } catch (e) {
          safeShowToast(this.getUIContext(), { message: (e as Error).message });
        }
      } },
    });
  }

  // 评论作者是否已注销（后端软删匿名化）
  private isDeletedCommentUser(c: Comment): boolean {
    const u = c.user;
    if (u === undefined) {
      return false;
    }
    if (u.deleted === true) {
      return true;
    }
    if (u.nickname === '已注销用户') {
      return true;
    }
    return false;
  }

  @Builder
  avatar(c: Comment) {
    if (this.isDeletedCommentUser(c)) {
      Text('?')
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('#3A3A3C')
        .fontColor(Color.White)
        .fontSize(14)
        .textAlign(TextAlign.Center)
    } else if (c.user?.avatar) {
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
                  Text(this.isDeletedCommentUser(c) ? '已注销用户' : (c.user?.nickname ?? '匿名用户'))
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
                Text(timeAgo(c.createdAt) + ' · ')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'));
                Text('👍 ' + formatCount(c.upCount))
                  .fontSize(12)
                  .fontColor($r('app.color.brand_primary'))
                  .onClick(async () => {
                    if (c.id !== undefined) {
                      try {
                        await upComment(c.id);
                        c.upCount = (c.upCount ?? 0) + 1;
                      } catch (_e) {
                        // 幂等忽略
                      }
                    }
                  })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              // 操作菜单（作者可删除，他人可举报）
              Text('⋯')
                .fontSize(18)
                .fontColor($r('app.color.text_secondary'))
                .width(32)
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  const isOwner: boolean = c.userId === getUserId();
                  if (isOwner) {
                    this.getUIContext().showAlertDialog({
                      title: '操作',
                      message: '',
                      primaryButton: { value: '取消', action: (): void => {} },
                      secondaryButton: {
                        value: '删除该评论',
                        fontColor: '#FF453A',
                        action: (): void => {
                          this.onDeleteComment(c);
                        },
                      },
                    });
                  } else {
                    this.getUIContext().showAlertDialog({
                      title: '操作',
                      message: '',
                      primaryButton: {
                        value: '举报该评论',
                        fontColor: '#FF453A',
                        action: (): void => {
                          if (c.id !== undefined) {
                            this.reportCommentHandler(c.id);
                          }
                        },
                      },
                      secondaryButton: { value: '取消', action: (): void => {} },
                    });
                  }
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
