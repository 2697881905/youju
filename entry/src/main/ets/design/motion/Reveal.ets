import { LayoutTokens } from '../tokens/space';
import { MotionCurves, MotionTokens } from '../tokens/motion';

@Component
export struct Reveal {
  @BuilderParam content: () => void = this.emptyContent;
  @Prop index: number = 0;
  @Prop visible: boolean = true;
  @Prop reduceMotion: boolean = false;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  @State revealed: boolean = false;

  @Builder
  emptyContent(): void {}

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.appReduceMotion || this.systemReduceMotion;
  }

  build() {
    Column() {
      this.content()
    }
    .opacity(this.visible && (this.shouldReduceMotion() || this.revealed) ? 1 : 0)
    .translate({
      y: this.shouldReduceMotion() || this.revealed ? 0 : LayoutTokens.revealOffset,
    })
    .animation({
      duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.enter,
      delay: this.shouldReduceMotion() ? 0 : this.index * MotionTokens.stagger,
      curve: MotionCurves.decelerate,
    })
    .onAppear(() => {
      this.revealed = true;
    })
  }
}
