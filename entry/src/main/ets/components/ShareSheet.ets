// 分享面板（占位：复制链接 / 复制标题；系统分享待域名确定后接入）
// 仿 ReportDialog 的 @CustomDialog 写法；动态数据通过页面传入的回调闭包读取，
// 避免 CustomDialogController builder 参数在构造期定值的坑（open 时才是最新值）。
@CustomDialog
export struct ShareSheet {
  controller: CustomDialogController;
  onCopyLink: () => void = (): void => {};
  onCopyTitle: () => void = (): void => {};
  onSystemShare: () => void = (): void => {};

  build() {
    Column({ space: 12 }) {
      Text('分享到')
        .fontSize(18)
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      this.option('复制链接', this.onCopyLink)
      this.option('复制标题', this.onCopyTitle)
      this.option('系统分享（即将上线）', this.onSystemShare)

      Text('取消')
        .width('100%')
        .height(48)
        .textAlign(TextAlign.Center)
        .fontSize(16)
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
        .fontSize(15)
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
