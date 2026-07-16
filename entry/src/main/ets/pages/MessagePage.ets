// 消息通知（Tab 内容，骨架，待开发，P1）
// 规划：评论/顶/抄作业/系统 四类消息（P1）
@Component
export struct MessagePage {
  build() {
    Column() {
      Row() {
        Text('消息').fontSize(17).fontWeight(600).layoutWeight(1).textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      Column() {
        Text('消息通知（待开发，P1）').fontSize(20).fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
