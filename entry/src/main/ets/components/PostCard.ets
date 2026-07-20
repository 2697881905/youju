import { Post, User } from '../models/types';
import { formatCount } from '../utils/format';

import { upPost, cancelUpPost } from '../services/api';
import { safeShowToast } from '../utils/toast';

@Component
export struct PostCard {
  @Prop post: Post = {};

  onCancelBookmark?: (id: number) => void = undefined;

  @State liked: boolean = false;
  @State likeCount: number = 0;

  aboutToAppear(): void {
    this.liked = this.post.myUp ?? false;
    this.likeCount = this.post.upCount ?? 0;
  }

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

  private goUser(): void {
    const u: User | undefined = this.post.user;
    if (this.isDeletedUser()) {
      return;
    }
    if (u !== undefined && u.id !== undefined) {
      AppStorage.setOrCreate('targetUserId', String(u.id));
      this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
    }
  }

  async onLike(): Promise<void> {
    const id: number | undefined = this.post.id;
    if (id === undefined) {
      return;
    }
    const willLike: boolean = !this.liked;
    this.liked = willLike;
    this.likeCount = this.likeCount + (willLike ? 1 : -1);
    try {
      if (willLike) {
        await upPost(id);
      } else {
        await cancelUpPost(id);
      }
    } catch (e) {
      this.liked = !willLike;
      this.likeCount = this.likeCount + (willLike ? -1 : 1);
      safeShowToast(this.getUIContext(), { message: '操作失败，请先登录' });
    }
  }

  build() {
    Column() {
      // 封面图 — Apple 风格大圆角
      if (this.post.coverImage) {
        Image(this.post.coverImage)
          .width('100%')
          .height(180)
          .objectFit(ImageFit.Cover)
          .borderRadius(10)
          .margin({ bottom: 12 })
      }

      // 标题 — iOS 17pt Medium 风格
      Text(this.post.title ?? '')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(22)

      // 作者区
      if (this.post.user !== undefined && this.post.user.id !== undefined) {
        Row({ space: 8 }) {
          if (this.isDeletedUser()) {
            Text('?')
              .width(22).height(22).borderRadius(11)
              .fontSize(12).fontColor('#FFFFFF')
              .backgroundColor('#3A3A3C')
              .textAlign(TextAlign.Center)
          } else if (this.post.user.avatar) {
            Image(this.post.user.avatar)
              .width(22).height(22).borderRadius(11)
              .objectFit(ImageFit.Cover)
          } else {
            Text((this.post.user.nickname ?? '?').charAt(0))
              .width(22).height(22).borderRadius(11)
              .fontSize(12).fontColor('#FFFFFF')
              .backgroundColor($r('app.color.brand_primary'))
              .textAlign(TextAlign.Center)
          }
          Text(this.isDeletedUser() ? '已注销用户' : (this.post.user.nickname ?? '匿名'))
            .fontSize(13).fontColor($r('app.color.text_secondary'))
        }
        .margin({ top: 10 })
        .onClick(() => {
          this.goUser();
        })
      }

      // 底部互动行
      Row() {
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
          .margin({ left: 16 });
      }
      .margin({ top: 10 })
      .justifyContent(FlexAlign.Start);

      if (this.onCancelBookmark !== undefined) {
        Row() {
          Text('取消收藏')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'));
        }
        .margin({ top: 10 })
        .onClick(() => {
          if (this.post.id !== undefined) {
            this.onCancelBookmark!(this.post.id);
          }
        });
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    // Apple 卡片阴影 — 浅色模式深灰投影，深色模式淡化
    .shadow({ radius: 16, color: '#0D000000', offsetY: 2 })
    .stateStyles({
      normal: {
        .opacity(1)
      },
      pressed: {
        .opacity(0.92)
        .scale({ x: 0.985, y: 0.985 })
      }
    });
  }
}