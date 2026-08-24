import { ParchmentPreview } from '../design/preview/ParchmentPreview';
import { ColorTokens } from '../design/tokens/color';

// 设计系统先行版预览页：羊皮纸 + 宋体，真机查看效果用。可从「设置 - 通用 - 设计系统预览」进入。
@Entry
@Component
struct ParchmentPreviewPage {
  build() {
    Stack() {
      ParchmentPreview()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
  }
}