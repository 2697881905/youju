import { MotionCurves, MotionTokens } from '../tokens/motion';
import { LayoutTokens } from '../tokens/space';

@Component
export struct Pressable {
  @BuilderParam content: () => void = this.emptyContent;
  @Prop disabled: boolean = false;
  @Prop reduceMotion: boolean = false;
  @Prop fillWidth: boolean = false;
  @Prop fullResponseRegion: boolean = false;
  @Prop visualHeight: number = 0;
  @Prop touchTargetHeight: number = LayoutTokens.minTouchTarget;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  action: () => void = () => {};

  @Builder
  emptyContent(): void {}

  private touchOffset(): number {
    return this.visualHeight > 0 ? (this.visualHeight - this.touchTargetHeight) / 2 : 0;
  }

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.appReduceMotion || this.systemReduceMotion;
  }

  build() {
    Column() {
      this.content()
    }
    .width(this.fillWidth ? '100%' : 'auto')
    .responseRegion({
      x: 0,
      y: this.touchOffset(),
      width: '100%',
      height: this.fullResponseRegion ? '100%' : this.touchTargetHeight,
    })
    .animation({ duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.fast, curve: MotionCurves.standard })
    .stateStyles({
      normal: {
        .opacity(1)
        .scale({ x: 1, y: 1 })
      },
      pressed: {
        .opacity(this.disabled ? 1 : MotionTokens.pressOpacity)
        .scale({
          x: this.disabled || this.shouldReduceMotion() ? 1 : MotionTokens.pressScale,
          y: this.disabled || this.shouldReduceMotion() ? 1 : MotionTokens.pressScale,
        })
      }
    })
    .enabled(!this.disabled)
    .onClick(() => {
      if (!this.disabled) {
        this.action();
      }
    })
  }
}
