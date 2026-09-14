import { Pressable } from '../motion/Pressable';
import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

export type DesignButtonVariant = 'primary' | 'ghost' | 'glass' | 'outlined';

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

  // outlined：与首页分段栏「容器」/ 圈子下拉按钮同款的描边规格
  // （透明底 + glassBorderWidth 细描边 barBorder + lg 圆角 + 无阴影 + primary 文字）
  private isOutlined(): boolean {
    return this.variant === 'outlined';
  }

  private resolvedRadius(): number {
    if (this.cornerRadius > 0) {
      return this.cornerRadius;
    }
    if (this.isOutlined()) {
      // 按钮类用 pill：与 primary / glass 两个既有变体同形状（44 高上即全胶囊），
      // 也与同排的胶囊分段栏一致。容器类控件仍用 lg（见 docs/home-segmented-control-style-audit.md）。
      return RadiusTokens.pill;
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
        .fontColor(this.isPrimary() ? ColorTokens.onBrand : (this.isGlass() || this.isOutlined() ? ColorTokens.primary : ColorTokens.brand))
        .height(this.visualHeight)
        .width(this.fillWidth ? '100%' : 'auto')
        .padding({ left: SpaceTokens.block, right: SpaceTokens.block })
        .textAlign(TextAlign.Center)
        .backgroundColor(this.isPrimary() ? ColorTokens.brand : (this.isGlass() ? ColorTokens.elevated : Color.Transparent))
        .border({
          width: this.isPrimary() ? 0 : LayoutTokens.glassBorderWidth,
          color: this.isGlass() ? ColorTokens.separator : (this.isOutlined() ? ColorTokens.barBorder : ColorTokens.brand),
          style: BorderStyle.Solid,
        })
        .borderRadius(this.resolvedRadius())
        .shadow({
          radius: this.isGlass() ? 6 : 0,
          color: this.isGlass() ? ColorTokens.barShadow : Color.Transparent,
          offsetY: this.isGlass() ? 2 : 0,
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
