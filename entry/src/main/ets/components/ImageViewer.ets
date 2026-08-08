import { resolveDisplayImageUrl } from '../services/api';
import { resolveActionIcon } from '../utils/actionIcons';
import { MotionCurves } from '../design/tokens/motion';

// 全屏图片查看器：黑色遮罩 + 原图宽度撑满屏幕、高度按比例自适应。
// 交互：单击任意处或右上角按钮关闭；双击或双指捏合缩放（1x~4x）；
// 内容超出视口时单指拖动平移（1x 长图也能上下滑动翻看，边界 clamp），缩放回到 1x 时自动复位。
// 使用方式：由父容器以全屏覆盖方式渲染（if 分支 + zIndex，或 bindContentCover）。
@Component
export struct ImageViewer {
  @Prop url: string = '';
  onClose: () => void = (): void => {};

  @State zoomScale: number = 1;
  @State translateX: number = 0;
  @State translateY: number = 0;
  // 图片宽高比（宽/高）。加载完成前用 3:4 占位，onComplete 读到真实尺寸后更新，
  // 使图片宽度撑满屏幕、高度按比例自适应，不再左右留黑边。
  @State imageRatio: number = 0.75;

  private pinchStartScale: number = 1;
  private panStartX: number = 0;
  private panStartY: number = 0;
  private viewWidth: number = 0;
  private viewHeight: number = 0;

  private clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }

  private toggleZoom(): void {
    const target: number = this.zoomScale > 1.01 ? 1 : 2.5;
    this.getUIContext().animateTo({ duration: 320, curve: MotionCurves.standard }, () => {
      this.zoomScale = target;
      if (target <= 1.01) {
        this.translateX = 0;
        this.translateY = 0;
      }
    });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 黑色背景铺底（单击关闭由手势统一处理，不重复绑 onClick）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
      // 原图宽度撑满屏幕，高度按真实宽高比自适应（onComplete 后无黑边）；支持缩放与平移
      Image(resolveDisplayImageUrl(this.url))
        .width('100%')
        .aspectRatio(this.imageRatio)
        .objectFit(ImageFit.Contain)
        .scale({ x: this.zoomScale, y: this.zoomScale })
        .translate({ x: this.translateX, y: this.translateY })
        .onComplete((event): void => {
          if (!event) {
            return;
          }
          const w: number = event.width;
          const h: number = event.height;
          if (w > 0 && h > 0) {
            this.imageRatio = w / h;
          }
        })
      // 右上角关闭按钮
      Image(resolveActionIcon('close'))
        .width(24)
        .height(24)
        .fillColor(Color.White)
        .position({ top: 16, right: 16 })
        .onClick((): void => { this.onClose(); })
      // 底部操作提示
      Text('长图可上下滑动，双击/捏合缩放')
        .fontSize(12).fontFamily($r('app.string.font_family'))
        .fontColor('#66FFFFFF')
        .position({ bottom: 48 })
    }
    .width('100%')
    .height('100%')
    .zIndex(999)
    .onAreaChange((_old: Area, area: Area) => {
      this.viewWidth = area.width as number;
      this.viewHeight = area.height as number;
    })
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        TapGesture({ count: 2 }).onAction((): void => { this.toggleZoom(); }),
        PinchGesture()
          .onActionStart((event: GestureEvent): void => { this.pinchStartScale = this.zoomScale; })
          .onActionUpdate((event: GestureEvent): void => {
            const target: number = this.clamp(this.pinchStartScale * event.scale, 1, 4);
            if (target <= 1.01) {
              this.zoomScale = 1;
              this.translateX = 0;
              this.translateY = 0;
            } else {
              this.zoomScale = target;
            }
          }),
        TapGesture({ count: 1 }).onAction((): void => { this.onClose(); }),
        PanGesture()
          .onActionStart((): void => {
            this.panStartX = this.translateX;
            this.panStartY = this.translateY;
          })
          .onActionUpdate((event: GestureEvent): void => {
            // 内容尺寸 = 图片显示尺寸 × 缩放。图片宽 = 视口宽（100%），高 = 宽 / 宽高比。
            const contentWidth: number = this.viewWidth * this.zoomScale;
            const contentHeight: number = (this.viewWidth / this.imageRatio) * this.zoomScale;
            // 可平移范围 = 内容超出视口的一半（超出才允许拖动，1x 长图也能上下翻看）
            const maxX: number = Math.max(0, (contentWidth - this.viewWidth) / 2);
            const maxY: number = Math.max(0, (contentHeight - this.viewHeight) / 2);
            if (maxX <= 0 && maxY <= 0) {
              return;
            }
            this.translateX = this.clamp(this.panStartX + event.offsetX, -maxX, maxX);
            this.translateY = this.clamp(this.panStartY + event.offsetY, -maxY, maxY);
          })
      )
    )
  }
}
