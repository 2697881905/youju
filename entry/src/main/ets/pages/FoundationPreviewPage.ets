import { FoundationPreview } from '../design/preview/FoundationPreview';

// Phase1 内部预览页：不挂接产品导航，仅用于 DevEco Preview 与设计地基验收。
@Entry
@Component
struct FoundationPreviewPage {
  build() {
    Column() {
      FoundationPreview()
    }
    .width('100%')
    .height('100%')
  }
}
