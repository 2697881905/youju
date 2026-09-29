import { MotionCurves, MotionTokens } from '../tokens/motion';
import { SpaceTokens } from '../tokens/space';

@Component
export struct Collapse {
  @BuilderParam content: () => void = this.emptyContent;
  @Prop expanded: boolean = false;

  @Builder
  emptyContent(): void {}

  build() {
    Column() {
      if (this.expanded) {
        Column() {
          this.content()
        }
        .width('100%')
        .transition(TransitionEffect.OPACITY
          .animation({
            duration: MotionTokens.base,
            curve: MotionCurves.decelerate,
          })
          .combine(TransitionEffect.translate({ y: SpaceTokens.sm })
            .animation({
              duration: MotionTokens.base,
              curve: MotionCurves.decelerate,
            })))
      }
    }
    .width('100%')
  }
}
