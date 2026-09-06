import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { ShadowTokens } from '../tokens/shadow';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { isImmersiveLightSenseSupported, GlassBlurStyle } from '../../utils/immersiveMaterial';
import { ImmersiveSurface } from '../components/ImmersiveSurface';

// 用于分享、筛选等短暂浮层：只动画 transform/opacity，并自动尊重减少动态效果设置。
@Component
export struct SpringPanel {
  @BuilderParam content: () => void = this.emptyContent;
  @Prop panelWidth: number = 344;
  @Prop panelPadding: number = SpaceTokens.lg;
  @Prop radius: number = RadiusTokens.lg;
  @Prop reduceMotion: boolean = false;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  @State presented: boolean = false;

  @Builder
  emptyContent(): void {}

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.appReduceMotion || this.systemReduceMotion;
  }

  build() {
    // 沉浸光感材质（浮层面板）：真机由 HdsVisualComponent 提供双边流光，模拟器降级为系统玻璃。
    // 入场编舞（opacity/translate/scale）作用于玻璃表面；流光层同步生成，视觉上像光晕先行透出。
    ImmersiveSurface({ radius: this.radius }) {
      Column() {
        this.content();
      }
      .width(this.panelWidth)
      .padding(this.panelPadding)
      .backgroundBlurStyle(GlassBlurStyle.Floating)
      .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .borderRadius(this.radius)
      .shadow(ShadowTokens.floating)
      .clip(true)
      .opacity(this.shouldReduceMotion() || this.presented ? 1 : 0)
      .translate({ y: this.shouldReduceMotion() || this.presented ? 0 : SpaceTokens.xl })
      .scale({
        x: this.shouldReduceMotion() || this.presented ? 1 : MotionTokens.enterScale,
        y: this.shouldReduceMotion() || this.presented ? 1 : MotionTokens.enterScale,
      })
      .animation({
        duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.container,
        curve: MotionCurves.springSoft,
      })
      .onAppear((): void => {
        this.presented = true;
      })
      .onDisAppear((): void => {
        // CustomDialog 控制器会复用 builder；关闭后复位，下一次打开仍有进入编舞。
        this.presented = false;
      });
    }
  }
}
