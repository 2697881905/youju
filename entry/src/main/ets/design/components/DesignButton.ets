import { Pressable } from '../motion/Pressable';
import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

export type DesignButtonVariant = 'primary' | 'ghost' | 'glass';

@Component
export struct DesignButton {
  @Prop label: string = '';
  @Prop variant: DesignButtonVariant = 'primary';
  @Prop @Watch('onDisabledChanged') disabled: boolean = false;
  @Prop fillWidth: boolean = false;
  @Prop visualHeight: number = LayoutTokens.minTouchTarget;
  @Prop cornerRadius: number = 0;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  @State readyPulse: boolean = false;
  private pulseTimer: number = 0;
  action?: () => void = undefined;

  private safeLabel(): string {
    return this.label ?? '';
  }

  private isPrimary(): boolean {
    return this.variant === 'primary';
  }

  private isGlass(): boolean {
    return this.variant === 'glass';
  }

  private resolvedRadius(): number {
    if (this.cornerRadius > 0) {
      return this.cornerRadius;
    }
    return this.isPrimary() || this.isGlass() ? RadiusTokens.pill : RadiusTokens.md;
  }

  aboutToDisappear(): void {
    if (this.pulseTimer !== 0) {
      clearTimeout(this.pulseTimer);
      this.pulseTimer = 0;
    }
  }

  private shouldReduceMotion(): boolean {
    return this.appReduceMotion || this.systemReduceMotion;
  }

  private onDisabledChanged(): void {
    if (this.disabled || this.shouldReduceMotion()) {
      this.readyPulse = false;
      return;
    }
    if (this.pulseTimer !== 0) {
      clearTimeout(this.pulseTimer);
    }
    this.readyPulse = true;
    this.pulseTimer = setTimeout((): void => {
      this.readyPulse = false;
      this.pulseTimer = 0;
    }, MotionTokens.base) as number;
  }

  build() {
    Pressable({
      disabled: this.disabled,
      fillWidth: this.fillWidth,
      visualHeight: this.visualHeight,
      reduceMotion: this.shouldReduceMotion(),
      action: () => {
        if (this.action !== undefined) {
          this.action();
        }
      },
    }) {
      Text(this.safeLabel())
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(TypeTokens.callout.lineHeight)
        .letterSpacing(TypeTokens.callout.tracking)
        .fontColor(this.isPrimary() ? ColorTokens.onBrand : (this.isGlass() ? ColorTokens.primary : ColorTokens.brand))
        .height(this.visualHeight)
        .width(this.fillWidth ? '100%' : 'auto')
        .padding({ left: SpaceTokens.block, right: SpaceTokens.block })
        .textAlign(TextAlign.Center)
        .backgroundColor(this.isPrimary() ? ColorTokens.brand : (this.isGlass() ? ColorTokens.barSurface : Color.Transparent))
        .border({
          width: this.isPrimary() ? 0 : LayoutTokens.glassBorderWidth,
          color: this.isGlass() ? ColorTokens.barBorder : ColorTokens.brand,
          style: BorderStyle.Solid,
        })
        .backdropBlur(this.isGlass() ? LayoutTokens.glassBlur : 0)
        .borderRadius(this.resolvedRadius())
        .shadow({
          radius: this.isGlass() ? 10 : 0,
          color: this.isGlass() ? ColorTokens.barShadow : Color.Transparent,
          offsetY: this.isGlass() ? 4 : 0,
        })
        .opacity(this.disabled ? 0.45 : 1)
        .scale({
          x: this.readyPulse && !this.shouldReduceMotion() ? 1.03 : 1,
          y: this.readyPulse && !this.shouldReduceMotion() ? 1.03 : 1,
        })
        .translate({ y: this.readyPulse && !this.shouldReduceMotion() ? -SpaceTokens.inlineTight : 0 })
        .animation({
          duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.fast,
          curve: MotionCurves.standard,
        })
    }
  }
}
