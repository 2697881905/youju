// 分享面板（占位：复制链接 / 复制标题；系统分享待域名确定后接入）
// 仿 ReportDialog 的 @CustomDialog 写法；动态数据通过页面传入的回调闭包读取，
// 避免 CustomDialogController builder 参数在构造期定值的坑（open 时才是最新值）。
import { EXTERNAL_SHARE_ENABLED } from '../utils/share';

@CustomDialog
export struct ShareSheet {
  controller: CustomDialogController;
  onCopyLink: () => void = (): void => {};
  onCopyTitle: () => void = (): void => {};
  onSystemShare: () => void = (): void => {};
  onShareCard: () => void = (): void => {};
  onShareToDm: () => void = (): void => {};

  build() {
    Column({ space: 12 }) {
      Text('分享到')
        .fontSize(18).fontFamily($r('app.string.font_family'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      // 站内「分享到私信」始终可用，优先展示
      this.option('分享到私信', this.onShareToDm)
      // 外部分享（卡片/链接/系统分享）仍受落地页就绪状态控制
      if (EXTERNAL_SHARE_ENABLED) {
        this.option('分享卡片', this.onShareCard)
        this.option('复制链接', this.onCopyLink)
        this.option('复制标题', this.onCopyTitle)
        this.option('系统分享', this.onSystemShare)
      }

      Text('取消')
        .width('100%')
        .height(48)
        .textAlign(TextAlign.Center)
        .fontSize(16).fontFamily($r('app.string.font_family'))
        .fontColor($r('app.color.text_secondary'))
        .onClick(() => {
          this.controller.close();
        })
        .margin({ top: 4 })
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }

  @Builder
  option(label: string, action: () => void) {
    Row() {
      Text(label)
        .fontSize(15).fontFamily($r('app.string.font_family'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .onClick(() => {
      action();
    })
  }
}
