// 评论列表组件（楼中楼盖楼式展示：一级评论 + 子回复面板，含"事实补充"徽标 + 举报入口 + 作者删除 + 回复入口）
import { Comment } from '../models/types';
import { timeAgo, formatCount } from '../utils/format';
import { deleteComment, upComment, cancelUpComment } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { resolveActionIcon } from '../utils/actionIcons';
import { openUserProfile } from '../utils/nav';
import { getUserId, getCurrentUser } from '../utils/auth';
import { Avatar } from '../design/components/Avatar';

@Component
export struct CommentList {
  @Prop comments: Comment[] = [];
  // 举报回调（由 DetailPage 传入，打开 ReportDialog）
  reportCommentHandler: (commentId: number) => void = (_id: number) => {};
  // P1-1 楼中楼：点击评论下「回复」时上报该评论（上层构建回复目标）
  // 参数命名为 cmt 避免与类型 Comment 在 Rollup 中冲突
  onReplyComment: (cmt: Comment) => void = (_cmt: Comment): void => {};
  // 评论点赞本地态：用 Map/Set 保存（@State 顶层替换触发重渲染），避免直接改 ForEach 项不刷新
  @State likedIds: Set<number> = new Set<number>();
  @State upCounts: Map<number, number> = new Map<number, number>();

  // 删除评论：二次确认 → 调 API → 乐观移除（一级评论删整条，子回复从其父的 replies 中移除）
  private onDeleteComment(c: Comment): void {
    this.getUIContext().showAlertDialog({
      title: '删除评论？',
      message: '删除后不可恢复，确定要删除吗？',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '确认删除', fontColor: $r('app.color.semantic_red'), action: async (): Promise<void> => {
        try {
          if (c.id !== undefined) {
            await deleteComment(c.id);
          }
          // 乐观移除：一级评论在整个列表中剔除（连带其 replies）；子回复从其父的 replies 中剔除
          const idx: number = this.comments.indexOf(c);
          if (idx >= 0) {
            this.comments.splice(idx, 1);
          } else {
            for (const root of this.comments) {
              const rs = root.replies ?? [];
              const ri: number = rs.indexOf(c);
              if (ri >= 0) {
                rs.splice(ri, 1);
                break;
              }
            }
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

  // 取评论当前展示点赞数（优先本地乐观态）
  private commentUp(c: Comment): number {
    if (c.id === undefined) {
      return c.upCount ?? 0;
    }
    if (this.upCounts.has(c.id)) {
      return this.upCounts.get(c.id) ?? 0;
    }
    return c.upCount ?? 0;
  }

  // 当前用户是否已赞该评论（本地态）
  private isLiked(c: Comment): boolean {
    if (c.id === undefined) {
      return false;
    }
    return this.likedIds.has(c.id);
  }

  // 评论点赞：乐观更新 + 失败回滚；通过替换 @State 的 Map/Set 触发即时重渲染
  private async onLike(c: Comment): Promise<void> {
    if (c.id === undefined) {
      return;
    }
    const id: number = c.id;
    const base: number = this.commentUp(c);
    const willLike: boolean = !this.isLiked(c);
    const newLiked: Set<number> = new Set<number>(this.likedIds);
    if (willLike) {
      newLiked.add(id);
    } else {
      newLiked.delete(id);
    }
    const newCounts: Map<number, number> = new Map<number, number>(this.upCounts);
    newCounts.set(id, base + (willLike ? 1 : -1));
    this.likedIds = newLiked;
    this.upCounts = newCounts;
    try {
      if (willLike) {
        await upComment(id);
      } else {
        await cancelUpComment(id);
      }
    } catch (e) {
      const rbLiked: Set<number> = new Set<number>(this.likedIds);
      if (willLike) {
        rbLiked.delete(id);
      } else {
        rbLiked.add(id);
      }
      const rbCounts: Map<number, number> = new Map<number, number>(this.upCounts);
      rbCounts.set(id, base);
      this.likedIds = rbLiked;
      this.upCounts = rbCounts;
    }
  }

  // 点击评论者头像跳转其主页（已注销用户不跳转，与 PostCard.goUser 一致）
  private goUser(c: Comment): void {
    if (this.isDeletedCommentUser(c)) {
      return;
    }
    const uid: number | undefined = c.userId ?? c.user?.id;
    if (uid !== undefined) {
      openUserProfile(uid);
      this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
    }
  }

  // 解析评论头像 URL：优先服务端头像；若该项属于当前登录用户且服务端未带出头像
  // （如刚发完评论服务端尚未回填、或本账号头像仅存于本地登录态），用本地 authAvatar 兜底，
  // 与个人主页（读 authAvatar）保持一致，避免「主页有头像、评论区却显示首字」。
  private commentAvatarUrl(c: Comment): string {
    const remote: string = c.user?.avatar ?? '';
    if (remote.length > 0) {
      return remote;
    }
    if (c.userId !== undefined && c.userId === getUserId()) {
      return getCurrentUser()?.avatar ?? '';
    }
    return '';
  }

  // 评论展示昵称（已注销用户统一展示"已注销用户"）
  private displayName(c: Comment): string {
    return this.isDeletedCommentUser(c) ? '已注销用户' : (c.user?.nickname ?? '匿名用户');
  }

  // 评论者昵称（未注销时取原始昵称，用于回复态「回复 @xxx」）
  private rawName(c: Comment): string {
    return this.isDeletedCommentUser(c) ? '已注销用户' : (c.user?.nickname ?? '匿名用户');
  }

  // 一级评论头像（36）
  @Builder
  avatar(c: Comment) {
    if (this.isDeletedCommentUser(c)) {
      Text('?')
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('#3A3A3C')
        .fontColor(Color.White)
        .fontSize(14).fontFamily($r('app.string.font_family'))
        .textAlign(TextAlign.Center)
    } else {
      Column() {
        Avatar({
          avatar: this.commentAvatarUrl(c),
          name: c.user?.nickname ?? '匿',
          avatarSize: 36,
        })
      }
      .width(36)
      .height(36)
      .onClick(() => {
        this.goUser(c);
      })
    }
  }

  // 子回复头像（28）
  @Builder
  subAvatar(c: Comment) {
    if (this.isDeletedCommentUser(c)) {
      Text('?')
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor('#3A3A3C')
        .fontColor(Color.White)
        .fontSize(12).fontFamily($r('app.string.font_family'))
        .textAlign(TextAlign.Center)
    } else {
      Column() {
        Avatar({
          avatar: this.commentAvatarUrl(c),
          name: c.user?.nickname ?? '匿',
          avatarSize: 28,
        })
      }
      .width(28)
      .height(28)
      .onClick(() => {
        this.goUser(c);
      })
    }
  }

  // 点赞 + 回复 操作条（一级/子回复共用）
  @Builder
  actionStrip(c: Comment, compact: boolean) {
    Row({ space: 14 }) {
      Row({ space: 2 }) {
        Image(this.isLiked(c) ? resolveActionIcon('likeActive') : resolveActionIcon('like'))
          .width(compact ? 12 : 13)
          .height(compact ? 12 : 13)
        Text(formatCount(this.commentUp(c)))
          .fontSize(compact ? 11 : 12).fontFamily($r('app.string.font_family'))
          .fontColor(this.isLiked(c) ? $r('app.color.ds_like') : $r('app.color.text_secondary'))
      }
      .onClick(() => {
        this.onLike(c);
      })
      Text('回复')
        .fontSize(compact ? 11 : 12).fontFamily($r('app.string.font_family'))
        .fontColor($r('app.color.text_secondary'))
        .onClick(() => {
          this.onReplyComment(c);
        })
    }
  }

  // 评论操作菜单（作者可删除，他人可举报）
  @Builder
  menuButton(c: Comment) {
    Text('⋯')
      .fontSize(18).fontFamily($r('app.string.font_family'))
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
              fontColor: $r('app.color.semantic_red'),
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
              fontColor: $r('app.color.semantic_red'),
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

  // 子回复行：回复 @xxx + 内容 + 操作条
  @Builder
  subRow(r: Comment, parentName: string) {
    Row({ space: 8 }) {
      this.subAvatar(r)
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(this.displayName(r))
            .fontSize(13).fontFamily($r('app.string.font_family'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
          if (r.isFact === 1) {
            Text('事实补充')
              .fontSize(10).fontFamily($r('app.string.font_family'))
              .fontColor($r('app.color.brand_primary'))
              .border({ width: 0.5, color: $r('app.color.brand_primary') })
              .borderRadius(3)
              .padding({ left: 3, right: 3, top: 0, bottom: 0 })
          }
        }
        Text('回复 @' + parentName + '：' + (r.content ?? ''))
          .fontSize(14).fontFamily($r('app.string.font_family'))
          .fontColor($r('app.color.text_primary'))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 4 }) {
          Text(timeAgo(r.createdAt))
            .fontSize(11).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'))
          this.actionStrip(r, true)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.menuButton(r)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column({ space: 12 }) {
      if (this.comments.length === 0) {
        Text('还没有评论，来抢沙发')
          .fontSize(13).fontFamily($r('app.string.font_family'))
          .fontColor($r('app.color.text_secondary'))
      } else {
        ForEach(
          this.comments,
          (c: Comment) => {
            Column({ space: 6 }) {
              Row({ space: 10 }) {
                this.avatar(c)
                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    Text(this.displayName(c))
                      .fontSize(14).fontFamily($r('app.string.font_family'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_secondary'))
                    if (c.isFact === 1) {
                      Text('事实补充')
                        .fontSize(11).fontFamily($r('app.string.font_family'))
                        .fontColor($r('app.color.brand_primary'))
                        .border({ width: 0.5, color: $r('app.color.brand_primary') })
                        .borderRadius(4)
                        .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                    }
                  }
                  Text(c.content ?? '')
                    .fontSize(15).fontFamily($r('app.string.font_family'))
                    .fontColor($r('app.color.text_primary'))
                  Row({ space: 4 }) {
                    Text(timeAgo(c.createdAt))
                      .fontSize(12).fontFamily($r('app.string.font_family'))
                      .fontColor($r('app.color.text_secondary'))
                    this.actionStrip(c, false)
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                this.menuButton(c)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)

              // 楼中楼：该一级评论下的全部回复（浅色面板 + 缩进对齐头像内侧）
              // 宽度用 calc 扣除左缩进，避免 100%＋margin 导致右侧溢出、操作按钮丢出屏幕
              if ((c.replies ?? []).length > 0) {
                Column({ space: 8 }) {
                  ForEach(
                    c.replies ?? [],
                    (r: Comment) => {
                      this.subRow(r, c.user?.nickname ?? '该条评论')
                    },
                    (r: Comment) => 'r' + (r.id?.toString() ?? '')
                  )
                }
                .width('calc(100% - 46vp)')
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 8, right: 8, top: 8, bottom: 8 })
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(10)
                .margin({ top: 4, left: 46 })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          },
          (c: Comment) => c.id?.toString() ?? ''
        )
      }
    }
    .width('100%')
  }
}