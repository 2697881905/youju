// 消息通知（Tab 内容，简版：四类消息入口 + 空态；真实通知系统待 P1）
import { promptAction } from '@kit.ArkUI';

interface MessageCategory {
  icon: string;
  title: string;
  desc: string;
}

const CATEGORIES: MessageCategory[] = [
  { icon: '💬', title: '评论', desc: '谁回复了你' },
  { icon: '⭐', title: '顶', desc: '谁顶了你的帖子' },
  { icon: '🔖', title: '收藏', desc: '谁抄了你的作业' },
  { icon: '📢', title: '系统', desc: '官方通知' },
];

@Component
export struct MessagePage {
  build() {
    Column() {
      // 顶栏
      Row() {
        Text('消息')
          .fontSize(17).fontWeight(600)
          .layoutWeight(1).textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      // 四类消息入口卡片
      ForEach(CATEGORIES, (c: MessageCategory) => {
        Row({ space: 14 }) {
          Text(c.icon).fontSize(24)
          Column({ space: 2 }) {
            Text(c.title)
              .fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text(c.desc)
              .fontSize(12).fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text('›')
            .fontSize(20).fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .backgroundColor($r('app.color.card_bg'))
        .margin({ bottom: 8 })
        .onClick(() => {
          promptAction.showToast({ message: c.title + '消息开发中' });
        })
      }, (c: MessageCategory) => c.title)

      // 空态
      Column() {
        Text('暂无新消息')
          .fontSize(14).fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1).width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
