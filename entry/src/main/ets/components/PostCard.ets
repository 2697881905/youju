import { Post, User } from '../models/types';
import { formatCount } from '../utils/format';
import { router } from '@kit.ArkUI';

@Component
export struct PostCard {
  @Prop post: Post = {};

  // 进入他人主页（作者区点击）
  private goUser(): void {
    const u: User | undefined = this.post.user;
    if (u !== undefined && u.id !== undefined) {
      AppStorage.setOrCreate('targetUserId', String(u.id));
      router.pushUrl({ url: 'pages/UserProfilePage' });
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

      // 作者区（点击进他人主页）
      if (this.post.user !== undefined && this.post.user.id !== undefined) {
        Row({ space: 8 }) {
          if (this.post.user.avatar) {
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
          Text(this.post.user.nickname ?? '匿名')
            .fontSize(12).fontColor($r('app.color.text_secondary'))
        }
        .margin({ top: 8 })
        .onClick(() => {
          this.goUser();
        })
      }

      Row() {
        Text('⭐ ' + formatCount(this.post.upCount))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'));
        Text('💬 ' + formatCount(this.post.commentCount))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 12 });
      }
      .margin({ top: 8 })
      .justifyContent(FlexAlign.Start);
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12);
  }
}
