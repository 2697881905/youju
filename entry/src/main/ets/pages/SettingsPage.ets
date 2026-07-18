// 设置页（极简）：顶栏返回按钮 + 「设置」标题；
// 列表项「账号绑定」点击跳转到账号绑定管理页。
import { router } from '@kit.ArkUI';

@Entry
@Component
struct SettingsPage {
  build() {
    Column() {
      // 顶栏：返回 + 标题
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor($r('app.color.text_primary'))
          .width(48)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          })
        Text('设置')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('')
          .width(48)
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 })

      // 列表
      Column({ space: 12 }) {
        Row() {
          Text('账号绑定')
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text('›')
            .fontSize(18)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(12)
        .onClick(() => {
          router.pushUrl({ url: 'pages/AccountBindingPage' });
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8 })

      // 底部安全提示
      Text('鸿蒙账号为主账号，不可解绑。')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
