// 「一镜到底」动画层：把「卡片封面图」从卡片位飞入详情媒体位后淡出，露出真实内容。
// 用与卡片同 URL 的封面（缓存秒开），纯 transform（translate/scale）插值，不触发布局。
// 起点（src）优先用外部传入的卡片屏幕帧；取不到时用稳定默认卡位（屏中部下侧小卡）——
// 不再依赖 componentUtils/截图等易失效链路，保证动画必然出现。
import { display } from '@kit.ArkUI';
import { CardRect, cardRectOf } from '../utils/navigationTransition';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';

@Component
export struct CardSnapshotLayer {
  // 与卡片同一封面 URL（缓存命中即时显示）
  @Prop coverUrl: string = '';
  // 卡片媒体块屏幕帧（vp）；宽高 <=0 时使用默认起点卡位
  @Prop src: CardRect = { left: 0, top: 0, width: 0, height: 0 };
  // 卡面媒体展示比例（宽/高）
  @Prop aspect: number = 0.75;
  // 详情 hero 组件 id：首帧后尝试取真实目标帧（更精准），取不到用近似布局
  @Prop targetId: string = '';
  onDone?: () => void = undefined;

  @State scaleX: number = 1;
  @State scaleY: number = 1;
  @State translateX: number = 0;
  @State translateY: number = 0;
  @State layerOpacity: number = 1;

  // 目标帧用 @State：播放前实测到真实 hero 帧后需要触发一次重绘（宽高/位置随之更新）
  @State target: CardRect = { left: 0, top: 0, width: 0, height: 0 };
  private from: CardRect = { left: 0, top: 0, width: 0, height: 0 };
  private winW: number = 360;
  private winH: number = 780;
  private statusBarH: number = 0;

  aboutToAppear(): void {
    const d = display.getDefaultDisplaySync();
    this.winW = this.getUIContext().px2vp(d.width);
    this.winH = this.getUIContext().px2vp(d.height);
    this.statusBarH = (AppStorage.get<number>('statusBarHeight') ?? 44) as number;
    // 起点：有效的外部卡帧优先；否则默认「屏幕中部下侧小卡」位（稳定兜底）
    if (this.src.width > 0 && this.src.height > 0) {
      this.from = this.src;
    } else {
      const w: number = this.winW * 0.58;
      this.from = {
        left: (this.winW - w) / 2,
        top: this.statusBarH + this.winH * 0.46,
        width: w,
        height: w / Math.max(this.aspect, 0.01),
      };
    }
    // 目标：优先取详情 hero 真实帧（首帧可能未布局，探测一次）；否则按布局近似
    const real: CardRect | null = this.targetId.length > 0 ? cardRectOf(this.targetId) : null;
    if (real !== null && real.width > 0) {
      this.target = real;
    } else {
      const w: number = this.winW - 32;
      this.target = {
        left: 16,
        top: this.statusBarH + 150,
        width: w,
        height: w / Math.max(this.aspect, 0.01),
      };
    }
    // 首帧渲染完成后开始准备播放（避免转场首帧状态被动画系统提前记录导致无动画）
    setTimeout((): void => {
      this.waitTargetThenPlay(0);
    }, 80);
  }

  // 等真实目标帧出现再播：详情接口加载期间只有「加载壳」，壳里的媒体占位没有
  // detailHeroMedia 这个 id，此时实测会落到近似兜底值，飞完再被真实内容顶一下（二次对位）。
  // 轮询上限 ~800ms；始终拿不到就按近似兜底播，保证动画必然出现。
  private waitTargetThenPlay(attempt: number): void {
    if (this.targetId.length > 0) {
      const real: CardRect | null = cardRectOf(this.targetId);
      if (real !== null && real.width > 0 && real.height > 0) {
        this.target = real;
        this.play();
        return;
      }
      if (attempt < 20) {
        setTimeout((): void => {
          this.waitTargetThenPlay(attempt + 1);
        }, 40);
        return;
      }
    }
    this.play();
  }

  private play(): void {
    // 播放前重新实测目标帧：aboutToAppear 时详情 hero 往往尚未布局，
    // 早测会落到近似兜底值，导致飞行终点偏移、随后真内容渲染时再跳一下。
    if (this.targetId.length > 0) {
      const real: CardRect | null = cardRectOf(this.targetId);
      if (real !== null && real.width > 0) {
        this.target = real;
      }
    }
    const sw: number = this.from.width;
    const sh: number = this.from.height;
    const tw: number = this.target.width;
    const th: number = this.target.height;
    if (sw <= 0 || sh <= 0 || tw <= 0 || th <= 0) {
      this.finish();
      return;
    }
    const sx: number = sw / tw;
    const sy: number = sh / th;
    const tx: number = (this.from.left - this.target.left) + (tw * sx - tw) / 2;
    const ty: number = (this.from.top - this.target.top) + (th * sy - th) / 2;
    this.scaleX = sx;
    this.scaleY = sy;
    this.translateX = tx;
    this.translateY = ty;
    this.getUIContext().animateTo({
      duration: MotionTokens.page,
      curve: MotionCurves.emphasized,
    }, () => {
      this.scaleX = 1;
      this.scaleY = 1;
      this.translateX = 0;
      this.translateY = 0;
    });
    setTimeout((): void => {
      this.getUIContext().animateTo({
        duration: 180,
        curve: MotionCurves.decelerate,
      }, () => {
        this.layerOpacity = 0;
      });
      setTimeout((): void => {
        this.finish();
      }, 200);
    }, MotionTokens.page + 40);
  }

  private finish(): void {
    if (this.onDone !== undefined) {
      this.onDone();
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.coverUrl.length > 0) {
        Image(this.coverUrl)
          .width(this.target.width)
          .height(this.target.height)
          .position({ x: this.target.left, y: this.target.top })
          .objectFit(ImageFit.Cover)
          .borderRadius(14)
          .clip(true)
          .scale({ x: this.scaleX, y: this.scaleY })
          .translate({ x: this.translateX, y: this.translateY })
          .opacity(this.layerOpacity)
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}