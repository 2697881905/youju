// GlowInput_Api26 —— API 26+ 搜索输入：Search + systemMaterial 系统材质。
//
// 实现对齐官方「多设备新闻阅读」示例的 SearchBuilder（原样参照其参数口径）：
//   - 材质：ImmersiveStyle.THIN + materialColor(sys.color.background_secondary，系统半透明
//     次级背景色，深浅色自适应) + applyShadow —— materialColor 是可见性的关键：搜索栏底下
//     若是纯色画布，全透明材质会「隐形」（首版实测教训）；
//   - backgroundColor(Color.Transparent)：材质需要透出，不能被底色盖住；
//   - 官方搜索框圆角 24、高 40；
//   - 版本判断用 deviceInfo.apiAvailable(26)（官方样例口径，编译期校验只认数字/特定版本串）。
// 仅在 API 26+ 设备被实例化（SearchPanel 按 VersionRouter 分支），材质对象惰性单例。

import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
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
  // 材质惰性单例：@since 26 的构造不能在老运行时触碰（本组件只在 26+ 分支被构造，
  // 再按官方口径用 apiAvailable 兜底一次）。
  private searchMaterial: uiMaterial.Material | undefined = undefined;

  aboutToAppear(): void {
    if (deviceInfo.sdkApiVersion >= 26) {
      this.searchMaterial = new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        materialColor: $r('sys.color.background_secondary'),
        applyShadow: true,
      });
    }
  }

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
    if (deviceInfo.sdkApiVersion >= 26) {
      Search({ placeholder: this.placeholder, value: this.text })
        .height(GlassTokens.SEARCH_HEIGHT)
        .borderRadius(24)
        .backgroundColor(Color.Transparent)
        .layoutWeight(this.fillWidth ? 1 : 0)
        .width(this.fillWidth ? 'auto' : '100%')
        .placeholderColor(Color.Grey)
        .placeholderFont({ family: TypeTokens.fontFamily })
        .textFont({ family: TypeTokens.fontFamily })
        .systemMaterial(this.searchMaterial)
        .onChange((v: string): void => { this.emitChange(v); })
        .onSubmit((v: string): void => {
          this.text = v;
          this.onEnter(v);
        })
        .onFocus((): void => { this.onFocusChanged(true); })
        .onBlur((): void => { this.onFocusChanged(false); })
    } else {
      // 兜底：26 材质不可用（理论上到不了这里——分支已按版本分派），给系统次级背景
      Search({ placeholder: this.placeholder, value: this.text })
        .height(GlassTokens.SEARCH_HEIGHT)
        .borderRadius(24)
        .backgroundColor($r('sys.color.background_secondary'))
        .layoutWeight(this.fillWidth ? 1 : 0)
        .width(this.fillWidth ? 'auto' : '100%')
        .placeholderColor(Color.Grey)
        .placeholderFont({ family: TypeTokens.fontFamily })
        .textFont({ family: TypeTokens.fontFamily })
        .onChange((v: string): void => { this.emitChange(v); })
        .onSubmit((v: string): void => {
          this.text = v;
          this.onEnter(v);
        })
        .onFocus((): void => { this.onFocusChanged(true); })
        .onBlur((): void => { this.onFocusChanged(false); })
    }
  }
}
