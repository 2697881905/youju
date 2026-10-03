import { Pressable } from '../motion/Pressable';
import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';
import { isSystemMaterialActive, TopButtonMaterialModifier } from '../../utils/immersiveMaterial';

export type DesignButtonVariant = 'primary' | 'ghost' | 'glass' | 'outlined';

@Component
export struct DesignButton {
  @Prop label: string = '';
  @Prop variant: DesignButtonVariant = 'primary';
  @Prop @Watch('onDisabledChanged') disabled: boolean = false;
  @Prop fillWidth: boolean = false;
  @Prop visualHeight: number = LayoutTokens.minTouchTarget;
  @Prop cornerRadius: number = 0;
  // 沉浸光感：驻留 Navigation 标题栏时由系统材质接管按钮表面（低版本门禁自动跳过，保留原描边样式）。
  // 与 SegmentedControl / TagNav 的 useSystemMaterial 同一范式。
  @Prop useSystemMaterial: boolean = false;
  private materialModifier: TopButtonMaterialModifier = new TopButtonMaterialModifier();
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

  private onDisabledChanged(): void {
    if (this.disabled) {
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
          // 材质生效时自绘描边让位（材质已接管表面，自绘边框会叠成第二圈描边）
          width: (this.useSystemMaterial && isSystemMaterialActive())
            ? 0
            : (this.isPrimary() ? 0 : LayoutTokens.glassBorderWidth),
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
          x: this.readyPulse ? 1.03 : 1,
          y: this.readyPulse ? 1.03 : 1,
        })
        .translate({ y: this.readyPulse ? -SpaceTokens.inlineTight : 0 })
        .animation({
          duration: MotionTokens.fast,
          curve: MotionCurves.standard,
        })
        // 沉浸光感：材质挂在按钮表面节点上（Pressable 尾随闭包之后不能再接属性链，
        // 与首页搜索按钮把材质挂在内层 Row 同一做法）；低版本门禁自动跳过
        .attributeModifier(this.useSystemMaterial ? this.materialModifier : undefined)
    }
  }
}
