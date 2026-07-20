import { Post, User } from '../models/types';
import { formatCount } from '../utils/format';
import { router } from '@kit.ArkUI';
import { upPost, cancelUpPost } from '../services/api';
import { safeShowToast } from '../utils/toast';

@Component
export struct PostCard {
  @Prop post: Post = {};

  // 取消收藏回调（可选）：由「我收藏」Tab 传入；信息流等场景不传则不显示取消入口。
  // 注意：函数型属性不加装饰器，由组件字面量 PostCard({ post, onCancelBookmark: ... }) 赋值。
  onCancelBookmark?: (id: number) => void = undefined;

  // 本地点赞态（来自 api 数据，组件内管理；命名避开 upCount 与 post.upCount 混淆）
  @State liked: boolean = false;
  @State likeCount: number = 0;

  // @State 不能在声明处读 @Prop post（ArkTS V1 限制），统一在 aboutToAppear 初始化；
  // ForEach 重建实例会重跑此处，刷新列表后点赞态正确复位。
  aboutToAppear(): void {
    this.liked = this.post.myUp ?? false;
    this.likeCount = this.post.upCount ?? 0;
  }

  // 作者是否已注销（后端软删匿名化）：deleted 标记或昵称==='已注销用户'
  private isDeletedUser(): boolean {
    const u = this.post.user;
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

  // 进入他人主页（作者区点击）；已注销作者不跳转
  private goUser(): void {
    const u: User | undefined = this.post.user;
    if (this.isDeletedUser()) {
      return;
    }
    if (u !== undefined && u.id !== undefined) {
      AppStorage.setOrCreate('targetUserId', String(u.id));
      router.pushUrl({ url: 'pages/UserProfilePage' });
    }
  }

  // 点赞乐观更新 + 失败回滚（与 DetailPage.onUp 同一模式）
  async onLike(): Promise<void> {
    const id: number | undefined = this.post.id;
    if (id === undefined) {
      return;
    }
    const willLike: boolean = !this.liked;
    // 先改本地态
    this.liked = willLike;
    this.likeCount = this.likeCount + (willLike ? 1 : -1);
    try {
      if (willLike) {
        await upPost(id);
      } else {
        await cancelUpPost(id);
      }
    } catch (e) {
      // 回滚（顺序与正向相反）
      this.liked = !willLike;
      this.likeCount = this.likeCount + (willLike ? -1 : 1);
      safeShowToast(this.getUIContext(), { message: '操作失败，请先登录' });
    }
  }

  build() {
    Column() {
      if (this.post.coverImage) {
        Image(this.post.coverImage)
          .width('100%')
          .height(160)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .margin({ bottom: 8 });
      }
      Text(this.post.title ?? '')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      // 作者区（点击进他人主页；已注销作者降级展示且不跳转）
      if (this.post.user !== undefined && this.post.user.id !== undefined) {
        Row({ space: 8 }) {
          if (this.isDeletedUser()) {
            Text('?')
              .width(20).height(20).borderRadius(10)
              .fontSize(11).fontColor('#fff')
              .backgroundColor('#3A3A3C')
              .textAlign(TextAlign.Center)
          } else if (this.post.user.avatar) {
            Image(this.post.user.avatar)
              .width(20).height(20).borderRadius(10)
              .objectFit(ImageFit.Cover)
          } else {
            Text((this.post.user.nickname ?? '?').charAt(0))
              .width(20).height(20).borderRadius(10)
              .fontSize(11).fontColor('#fff')
              .backgroundColor($r('app.color.brand_primary'))
              .textAlign(TextAlign.Center)
          }
          Text(this.isDeletedUser() ? '已注销用户' : (this.post.user.nickname ?? '匿名'))
            .fontSize(12).fontColor($r('app.color.text_secondary'))
        }
        .margin({ top: 8 })
        .onClick(() => {
          this.goUser();
        })
      }

      // 底部互动行：点赞（可点击 + 乐观更新）｜评论（只读）
      Row() {
        // 点赞按钮：点击乐观更新 + 回滚。
        // 说明：ArkUI 的 .onClick(ClickEvent) 为非冒泡事件，不会触发父级 GridItem 的跳转，
        // 因此无需 stopPropagation（ClickEvent 也无该 API）。
        Row({ space: 4 }) {
          Text('👍')
            .fontSize(13)
          Text('顶 ' + formatCount(this.likeCount))
            .fontSize(13)
            .fontColor(this.liked ? $r('app.color.brand_primary') : $r('app.color.text_secondary'));
        }
        .onClick(() => {
          this.onLike();
        })

        Text('💬 ' + formatCount(this.post.commentCount))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 12 });
      }
      .margin({ top: 8 })
      .justifyContent(FlexAlign.Start);

      // 收藏 Tab：取消收藏入口（仅当父组件传入回调时显示）
      if (this.onCancelBookmark !== undefined) {
        Row() {
          Text('取消收藏')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'));
        }
        .margin({ top: 8 })
        .onClick(() => {
          if (this.post.id !== undefined) {
            this.onCancelBookmark!(this.post.id);
          }
        });
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12);
  }
}
