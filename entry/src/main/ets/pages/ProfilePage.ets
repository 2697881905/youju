// 个人主页（Tab 内容，骨架，待开发）
// 规划：头像/昵称 → 我发布的帖子 → 我收藏的帖子（P1）
@Component
export struct ProfilePage {
  build() {
    Column() {
      Row() {
        Text('').width(48)
        Text('我的').fontSize(17).fontWeight(600).layoutWeight(1).textAlign(TextAlign.Center)
        Text('设置').fontSize(16).fontColor($r('app.color.text_secondary')).width(48)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      Column() {
        Text('个人主页（待开发）').fontSize(20).fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
