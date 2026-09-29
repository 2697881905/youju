// GlowInput_Api23 —— API 23-25 搜索输入：借用 HdsTabs 浮动栏的系统材质。
//
// 官方口径（API 26 之前）：可在 HdsTabs 的自定义 tabBar 中内嵌 Search 组件，借助
// barFloatingStyle 的 systemMaterialEffect 呈现近似沉浸光感。关键约束（缺一不可）：
//   - barOverlap(true) + barPosition(BarPosition.End) 是 barFloatingStyle 生效的必要条件；
//   - TabContent 高度置 0，只保留自定义 tabBar；
//   - Search 的 backgroundColor 必须透明，让 HdsTabs 的沉浸材质透出；
//   - gradientMask 的 maskColor 设透明，去除额外渐变底板。
// 注意：SDK 26 的 hdsMaterial.MaterialType 只有 NONE/ADAPTIVE（无 IMMERSIVE，那在
// openharmony uiMaterial 里），材质走 ADAPTIVE 由系统按设备算力自适应。
// 仅在 API 23-25 设备被实例化（SearchPanel 按 VersionRouter 分支）。

import { HdsTabs, hdsMaterial, HdsTabsController } from '@kit.UIDesignKit';
import { GlassTokens } from '../tokens/GlassTokens';
import { TypeTokens } from '../tokens/type';
import { SearchInputProps } from './SearchInputTypes';

@Component
export struct GlowInput_Api23 {
  @Prop placeholder: string = '';
  @Link text: string;
  @Prop fillWidth: boolean = false;
  onChange: (value: string) => void = (value: string): void => {};
  onEnter: (value: string) => void = (value: string): void => {};
  onFocusChanged: (focused: boolean) => void = (focused: boolean): void => {};

  private tabsController: HdsTabsController = new HdsTabsController();

  build() {
    HdsTabs({ controller: this.tabsController }) {
      TabContent() {
        // 不显示实际内容，只保留自定义 tabBar 承载搜索框
        Column().width('100%').height(0)
      }
      .tabBar(this.searchTabBuilder())
    }
    .barOverlap(true)
    .barPosition(BarPosition.End)
    .vertical(false)
    .scrollable(false)
    .barHeight(GlassTokens.SEARCH_HEIGHT)
    .barFloatingStyle({
      barWidth: { smallWidth: 334, mediumWidth: 334, largeWidth: '100%' },
      barSideMargin: 16,
      barBottomMargin: 0,
      gradientMask: { maskColor: '#00000000', maskHeight: 1 },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.EXQUISITE,
      },
    })
  }

  @Builder
  searchTabBuilder(): void {
    Search({ value: this.text, placeholder: this.placeholder })
      .width('100%')
      .height(GlassTokens.SEARCH_HEIGHT)
      .borderRadius(GlassTokens.SEARCH_RADIUS)
      // 必须透明：让 HdsTabs 的沉浸材质透出
      .backgroundColor(Color.Transparent)
      .placeholderColor(Color.Grey)
      .placeholderFont({ family: TypeTokens.fontFamily })
      .textFont({ family: TypeTokens.fontFamily })
      .onChange((v: string): void => {
        this.text = v;
        this.onChange(v);
      })
      .onSubmit((v: string): void => {
        this.text = v;
        this.onEnter(v);
      })
      .onFocus((): void => { this.onFocusChanged(true); })
      .onBlur((): void => { this.onFocusChanged(false); })
  }
}
