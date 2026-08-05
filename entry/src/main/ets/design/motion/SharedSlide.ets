import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { ShadowTokens } from '../tokens/shadow';
import { LayoutTokens, SpaceTokens } from '../tokens/space';

@Component
export struct SharedSlide {
  @Prop selectedIndex: number = 0;
  @Prop itemCount: number = 1;
  @Prop controlHeight: number = LayoutTokens.segmentedHeight;
  @Prop inset: number = SpaceTokens.xs;
  @Prop itemWidth: number = 0;
  @Prop radius: number = RadiusTokens.sm;
  @Prop fill: ResourceColor = ColorTokens.elevated;
  @Prop reduceMotion: boolean = false;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  @State containerWidth: number = 0;

  private safeCount(): number {
    return Math.max(1, this.itemCount);
  }

  private slotWidth(): number {
    return Math.max(0, (this.containerWidth - this.inset * 2) / this.safeCount());
  }

  private pillWidth(): number {
    const slot: number = this.slotWidth();
    return this.itemWidth > 0 ? Math.min(this.itemWidth, slot) : slot;
  }

  private selectedOffset(): number {
    const safeIndex: number = Math.max(0, Math.min(this.safeCount() - 1, this.selectedIndex));
    return safeIndex * this.slotWidth() + (this.slotWidth() - this.pillWidth()) / 2;
  }

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.appReduceMotion || this.systemReduceMotion;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(this.pillWidth())
        .height(Math.max(0, this.controlHeight - this.inset * 2))
        .position({ x: this.inset, y: this.inset })
        .translate({ x: this.selectedOffset() })
        .backgroundColor(this.fill)
        .borderRadius(this.radius)
        .shadow(ShadowTokens.cardContact)
        .animation({
          duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.base,
          curve: MotionCurves.standard,
        })
    }
    .width('100%')
    .height(this.controlHeight)
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_old: Area, next: Area) => {
      this.containerWidth = next.width as number;
    })
  }
}
