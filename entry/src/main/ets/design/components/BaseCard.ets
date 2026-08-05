import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { ShadowTokens } from '../tokens/shadow';
import { SpaceTokens } from '../tokens/space';

export type CardElevation = 0 | 1 | 2;

@Component
export struct BaseCard {
  @BuilderParam content: () => void = this.emptyContent;
  @Prop cardPadding: number = SpaceTokens.base;
  @Prop radius: number = RadiusTokens.lg;
  @Prop elevation: CardElevation = 1;
  @Prop pressable: boolean = false;
  @Prop reduceMotion: boolean = false;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  action: () => void = () => {};

  @Builder
  emptyContent(): void {}

  private contactShadow(): ShadowOptions {
    return this.elevation === 0 ? ShadowTokens.none : ShadowTokens.cardContact;
  }

  private ambientShadow(): ShadowOptions {
    if (this.elevation === 0) {
      return ShadowTokens.none;
    }
    return this.elevation === 2 ? ShadowTokens.floating : ShadowTokens.cardAmbient;
  }

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.appReduceMotion || this.systemReduceMotion;
  }

  build() {
    Column() {
      Column() {
        this.content()
      }
      .width('100%')
      .padding(this.cardPadding)
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(this.radius)
      .shadow(this.contactShadow())
    }
    .width('100%')
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(this.radius)
    .shadow(this.ambientShadow())
    .animation({
      duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.fast,
      curve: MotionCurves.standard,
    })
    .stateStyles({
      normal: {
        .opacity(1)
        .scale({ x: 1, y: 1 })
      },
      pressed: {
        .opacity(this.pressable ? MotionTokens.pressOpacity : 1)
        .scale({
          x: this.pressable && !this.shouldReduceMotion() ? MotionTokens.pressScale : 1,
          y: this.pressable && !this.shouldReduceMotion() ? MotionTokens.pressScale : 1,
        })
      }
    })
    .onClick(() => {
      this.action();
    })
  }
}
