import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

@Component
export struct CountRoll {
  @Prop @Watch('onValueChange') value: number = 0;
  @Prop prefix: string = '';
  @Prop reduceMotion: boolean = false;
  @Prop textSize: number = TypeTokens.caption.size;
  @Prop textColor: ResourceColor = ColorTokens.tertiary;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
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

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.appReduceMotion || this.systemReduceMotion;
  }

  private onValueChange(): void {
    if (this.shouldReduceMotion()) {
      this.displayValue = this.value;
      return;
    }
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
    Text(this.prefix + String(this.displayValue))
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
