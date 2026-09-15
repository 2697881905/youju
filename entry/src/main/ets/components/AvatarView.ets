// 可复用头像组件：墨色描边圆环（随主题黑/白）+ 居中正圆头像 + 默认头像兜底。
// 用于个人主页 / 编辑资料等需要"头像框"的场景；无头像时显示品牌默认头像
// （据印·经验叠层，resources/base/media/default_avatar.svg），去蓝、中性、跨主题。

import { resolveDisplayImageUrl } from '../services/api';

@Component
export struct AvatarView {
  @Prop avatar: string = '';
  @Prop name: string = '';
  @Prop avatarSize: number = 64;
  @Prop ringWidth: number = 2;
  // 头像 URL 加载失败标记：置位后回退到品牌默认头像，避免破损图/空白
  @State loadFailed: boolean = false;

  build() {
    // 头像框（品牌色描边圆环）尺寸 = 头像内容 + 两侧描边；内容居中且完全落在框内，
    // 避免描边压在头像内容边缘导致「内容 / 框不重合」。
    Stack({ alignContent: Alignment.Center }) {
      if (this.avatar.length > 0 && !this.loadFailed) {
        Image(resolveDisplayImageUrl(this.avatar))
          .width(this.avatarSize)
          .height(this.avatarSize)
          .borderRadius(this.avatarSize / 2)
          .objectFit(ImageFit.Cover)
          .clip(true)
          .onError(() => {
            // URL 非空但加载失败（404/过期/断网）→ 回退默认头像
            this.loadFailed = true;
          })
      } else {
        // 无头像兜底：品牌默认头像（据印·经验叠层），去蓝、中性、跨主题
        Image($r('app.media.default_avatar'))
          .width(this.avatarSize)
          .height(this.avatarSize)
          .borderRadius(this.avatarSize / 2)
          .objectFit(ImageFit.Cover)
          .clip(true)
      }
    }
    .width(this.avatarSize + 2 * this.ringWidth)
    .height(this.avatarSize + 2 * this.ringWidth)
    .borderRadius((this.avatarSize + 2 * this.ringWidth) / 2)
    .border({ width: this.ringWidth, color: $r('app.color.text_primary') })
  }
}
