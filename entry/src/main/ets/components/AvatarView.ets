// 可复用头像组件：品牌色描边圆环 + 居中正圆头像 + 首字母占位兜底。
// 用于个人主页 / 编辑资料等需要"头像框"的场景，自动跟随深色模式（品牌色在
// base/dark 的 color.json 均有定义）。

@Component
export struct AvatarView {
  @Prop avatar: string = '';
  @Prop name: string = '';
  @Prop avatarSize: number = 64;
  @Prop ringWidth: number = 2;

  build() {
    Stack() {
      if (this.avatar.length > 0) {
        Image(this.avatar)
          .width(this.avatarSize)
          .height(this.avatarSize)
          .borderRadius(this.avatarSize / 2)
          .objectFit(ImageFit.Cover)
      } else {
        Text(this.name.trim().length > 0 ? this.name.trim().charAt(0) : '?')
          .width(this.avatarSize)
          .height(this.avatarSize)
          .borderRadius(this.avatarSize / 2)
          .fontSize(this.avatarSize * 0.42)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.brand_primary'))
          .textAlign(TextAlign.Center)
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
    .borderRadius(this.avatarSize / 2)
    .border({ width: this.ringWidth, color: $r('app.color.brand_primary') })
  }
}
