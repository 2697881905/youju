import { LayoutTokens } from '../tokens/space';
import { MotionCurves, MotionTokens } from '../tokens/motion';

@Component
export struct Reveal {
  @BuilderParam content: () => void = this.emptyContent;
  @Prop index: number = 0;
  @Prop visible: boolean = true;
  @State revealed: boolean = false;

  @Builder
  emptyContent(): void {}

  build() {
    Column() {
      this.content()
    }
    .opacity(this.visible && this.revealed ? 1 : 0)
    .translate({
      y: this.revealed ? 0 : LayoutTokens.revealOffset,
    })
    .animation({
      duration: MotionTokens.enter,
      delay: this.index * MotionTokens.stagger,
      curve: MotionCurves.decelerate,
    })
    .onAppear(() => {
      this.revealed = true;
    })
  }
}
