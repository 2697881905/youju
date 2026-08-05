import { MotionCurves, MotionTokens } from '../tokens/motion';
import { SpaceTokens } from '../tokens/space';

@Component
export struct Collapse {
  @BuilderParam content: () => void = this.emptyContent;
  @Prop expanded: boolean = false;
  @Prop reduceMotion: boolean = false;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;

  @Builder
  emptyContent(): void {}

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.appReduceMotion || this.systemReduceMotion;
  }

  build() {
    Column() {
      if (this.expanded) {
        Column() {
          this.content()
        }
        .width('100%')
        .transition(TransitionEffect.OPACITY
          .animation({
            duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.base,
            curve: MotionCurves.decelerate,
          })
          .combine(TransitionEffect.translate({ y: SpaceTokens.sm })
            .animation({
              duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.base,
              curve: MotionCurves.decelerate,
            })))
      }
    }
    .width('100%')
  }
}
