import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';
import { formatCount } from '../../utils/format';

@Component
export struct CountRoll {
  @Prop @Watch('onValueChange') value: number = 0;
  @Prop prefix: string = '';
  @Prop textSize: number = TypeTokens.caption.size;
  @Prop textColor: ResourceColor = ColorTokens.tertiary;
  @State displayValue: number = 0;
  @State contentOpacity: number = 1;
  @State contentOffset: number = 0;
  private updateTimer: number = 0;

  aboutToAppear(): void {
    this.displayValue = this.value;
  }

  aboutToDisappear(): void {
    if (this.updateTimer !== 0) {
      clearTimeout(this.updateTimer);
      this.updateTimer = 0;
    }
  }

  private onValueChange(): void {
    if (this.updateTimer !== 0) {
      clearTimeout(this.updateTimer);
    }
    this.getUIContext().animateTo({ duration: MotionTokens.fast, curve: MotionCurves.accelerate }, () => {
      this.contentOpacity = 0;
      this.contentOffset = -SpaceTokens.xs;
    });
    this.updateTimer = setTimeout(() => {
      this.displayValue = this.value;
      this.contentOffset = SpaceTokens.xs;
      this.getUIContext().animateTo({ duration: MotionTokens.fast, curve: MotionCurves.decelerate }, () => {
        this.contentOpacity = 1;
        this.contentOffset = 0;
      });
      this.updateTimer = 0;
    }, MotionTokens.fast) as number;
  }

  build() {
    // 计数口径与全 App 统一（formatCount：≥1w 缩写）。滚动动效仍作用于 displayValue，
    // 小于 1w 时逐值滚动，跨过 1w 后显示缩写——不破坏数字变化的反馈，只统一显示格式。
    Text(this.prefix + formatCount(this.displayValue))
      .fontSize(this.textSize).fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.caption.weight)
      .lineHeight(TypeTokens.caption.lineHeight)
      .letterSpacing(TypeTokens.caption.tracking)
      .fontFeature(TypeTokens.tabularFeature)
      .fontColor(this.textColor)
      .opacity(this.contentOpacity)
      .translate({ y: this.contentOffset })
  }
}
