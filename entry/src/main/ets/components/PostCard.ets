import { Post } from '../models/types';
import { formatCount } from '../utils/format';

@Component
export struct PostCard {
  @Prop post: Post = {};

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
