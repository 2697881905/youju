// GlowInput_Api26 —— API 26+ 搜索输入：Search + systemMaterial 系统材质。
//
// 官方方案（API 26 起 Search 支持 systemMaterial 通用属性）：系统材质接管背景/描边/阴影，
// 呈现动态模糊融合效果。要点：
//   - backgroundColor 必须透明（Color.Transparent），否则材质被底色盖住；
//   - ImmersiveStyle.THIN 为官方搜索框推荐材质厚度；
//   - interactive: true 启用交互式光感（点击/聚焦动态响应）；
//   - 不要与 backgroundColor/border/shadow 属性同用（材质会接管它们）。
// 仅在 API 26+ 设备被实例化（SearchPanel 按 VersionRouter 分支），材质对象惰性单例。

import { uiMaterial } from '@kit.ArkUI';
import { GlassTokens } from '../tokens/GlassTokens';
import { TypeTokens } from '../tokens/type';
import { SearchInputProps } from './SearchInputTypes';

@Component
export struct GlowInput_Api26 {
  @Prop placeholder: string = '';
  @Link text: string;
  @Prop fillWidth: boolean = false;
  @Prop debounceMs: number = 0;
  onChange: (value: string) => void = (value: string): void => {};
  onEnter: (value: string) => void = (value: string): void => {};
  onFocusChanged: (focused: boolean) => void = (focused: boolean): void => {};

  private suggestTimer: number = 0;

  aboutToDisappear(): void {
    if (this.suggestTimer !== 0) {
      clearTimeout(this.suggestTimer);
      this.suggestTimer = 0;
    }
  }

  // onChange 出口：debounceMs > 0 时按毫秒防抖（搜索面板传 300；末次击键的值胜出）
  private emitChange(v: string): void {
    this.text = v;
    if (this.debounceMs > 0) {
      if (this.suggestTimer !== 0) {
        clearTimeout(this.suggestTimer);
      }
      this.suggestTimer = setTimeout((): void => {
        this.suggestTimer = 0;
        this.onChange(v);
      }, this.debounceMs) as number;
    } else {
      this.onChange(v);
    }
  }

  build() {
    Search({ placeholder: this.placeholder, value: this.text })
      .height(GlassTokens.SEARCH_HEIGHT)
      .borderRadius(GlassTokens.SEARCH_RADIUS)
      // 必须透明：系统材质需要透出（材质会接管背景/描边/阴影）
      .backgroundColor(Color.Transparent)
      .layoutWeight(this.fillWidth ? 1 : 0)
      .width(this.fillWidth ? 'auto' : '100%')
      .placeholderColor(Color.Grey)
      .placeholderFont({ family: TypeTokens.fontFamily })
      .textFont({ family: TypeTokens.fontFamily })
      .systemMaterial(new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        interactive: true,
        lightEffect: { color: Color.White },
      }))
      .onChange((v: string): void => { this.emitChange(v); })
      .onSubmit((v: string): void => {
        this.text = v;
        this.onEnter(v);
      })
      .onFocus((): void => { this.onFocusChanged(true); })
      .onBlur((): void => { this.onFocusChanged(false); })
  }
}
