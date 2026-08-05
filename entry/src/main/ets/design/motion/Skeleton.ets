import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';

@Component
export struct Skeleton {
  @Prop skeletonWidth: Length = '100%';
  @Prop skeletonHeight: number = SpaceTokens.base;
  @Prop radius: number = RadiusTokens.xs;
  @Prop reduceMotion: boolean = false;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  @State travel: number = -LayoutTokens.skeletonHighlightWidth;
  @State measuredWidth: number = LayoutTokens.skeletonDefaultWidth;

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.appReduceMotion || this.systemReduceMotion;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(ColorTokens.skeletonBase)

      if (!this.shouldReduceMotion()) {
        Column()
          .width(LayoutTokens.skeletonHighlightWidth)
          .height('100%')
          .linearGradient({
            angle: 90,
            colors: [
              [ColorTokens.skeletonBase, 0],
              [ColorTokens.skeletonHighlight, 0.5],
              [ColorTokens.skeletonBase, 1],
            ],
          })
          .translate({ x: this.travel })
          .animation({
            duration: MotionTokens.shimmer,
            curve: MotionCurves.linear,
            iterations: -1,
          })
      }
    }
    .width(this.skeletonWidth)
    .height(this.skeletonHeight)
    .borderRadius(this.radius)
    .clip(true)
    .onAreaChange((_old: Area, next: Area) => {
      this.measuredWidth = next.width as number;
    })
    .onAppear(() => {
      this.travel = this.measuredWidth + LayoutTokens.skeletonHighlightWidth;
    })
  }
}
