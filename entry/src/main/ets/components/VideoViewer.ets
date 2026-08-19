import { resolveDisplayImageUrl } from '../services/api';
import { resolveActionIcon } from '../utils/actionIcons';
import { TypeTokens } from '../design/tokens/type';

// 全屏视频查看器（自绘现代播放条，替代系统 controls 旧样式）：
// - 打开即自动播放，画面 Contain 完整展示；不用系统控制器（其样式老旧且带边框线）
// - 底部玻璃质感播放条：播放/暂停 + 进度滑杆 + 时间；播放中 3s 自动隐藏，点按画面切换显隐
// - 右上角关闭；返回手势由宿主页面 onBackPress 消费（关闭查看器而非退出聊天页）
@Component
export struct VideoViewer {
  @Prop url: string = '';
  onClose: () => void = (): void => {};

  private controller: VideoController = new VideoController();
  @State playing: boolean = false;
  @State currentSec: number = 0;
  @State durationSec: number = 0;
  @State dragging: boolean = false;
  @State showBar: boolean = true;
  private hideTimer: number = -1;

  aboutToDisappear(): void {
    this.clearHideTimer();
  }

  private clearHideTimer(): void {
    if (this.hideTimer !== -1) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
  }

  // 播放中 3s 无操作自动隐藏播放条；暂停时保持常显
  private scheduleHide(): void {
    this.clearHideTimer();
    if (this.playing) {
      this.hideTimer = setTimeout((): void => {
        this.showBar = false;
        this.hideTimer = -1;
      }, 3000);
    } else {
      this.showBar = true;
    }
  }

  private togglePlay(): void {
    if (this.playing) {
      this.controller.pause();
    } else {
      this.controller.start();
    }
  }

  // 点按画面：切换播放条显隐（显示时重新计时自动隐藏）
  private onScreenTap(): void {
    if (this.showBar) {
      this.clearHideTimer();
      this.showBar = false;
    } else {
      this.showBar = true;
      this.scheduleHide();
    }
  }

  private fmt(sec: number): string {
    const s: number = Math.max(0, Math.floor(sec));
    const m: number = Math.floor(s / 60);
    const r: number = s % 60;
    return m + ':' + (r < 10 ? '0' : '') + r;
  }

  @Builder
  pauseIcon() {
    Row({ space: 3 }) {
      Column().width(4).height(14).borderRadius(2).backgroundColor(Color.White)
      Column().width(4).height(14).borderRadius(2).backgroundColor(Color.White)
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  bottomBar() {
    Row({ space: 10 }) {
      // 播放/暂停切换
      Column() {
        if (this.playing) {
          this.pauseIcon()
        } else {
          Image($r('app.media.video_play'))
            .width(18)
            .height(18)
            .fillColor(Color.White)
            // 三角形视觉重心偏左，轻微右移光学居中
            .translate({ x: 1 })
        }
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick((): void => {
        this.togglePlay();
        this.showBar = true;
        this.scheduleHide();
      })

      // 进度滑杆：拖动中不回写视频进度，松手才 seek
      Slider({
        value: this.currentSec,
        min: 0,
        max: this.durationSec > 0 ? this.durationSec : 1,
        step: 1,
      })
        .layoutWeight(1)
        .selectedColor(Color.White)
        .trackColor('#40FFFFFF')
        .blockColor(Color.White)
        .blockSize({ width: 14, height: 14 })
        .trackThickness(3)
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.Begin) {
            this.dragging = true;
          }
          if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
            this.currentSec = value;
          } else if (mode === SliderChangeMode.End) {
            this.controller.setCurrentTime(value);
            this.dragging = false;
          } else if (mode === SliderChangeMode.Click) {
            this.controller.setCurrentTime(value);
          }
        })

      Text(this.fmt(this.currentSec) + ' / ' + this.fmt(this.durationSec))
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor('#E6FFFFFF')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor('#59000000')
    .backdropBlur(30)
    .borderRadius(999)
    .margin({ left: 16, right: 16, bottom: 34 })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      Video({ src: resolveDisplayImageUrl(this.url), controller: this.controller })
        .width('100%')
        .height('100%')
        .controls(false)
        .autoPlay(true)
        .objectFit(ImageFit.Contain)
        .onStart((): void => {
          this.playing = true;
          this.scheduleHide();
        })
        .onPause((): void => {
          this.playing = false;
          this.showBar = true;
          this.clearHideTimer();
        })
        .onFinish((): void => {
          this.playing = false;
          this.showBar = true;
          this.clearHideTimer();
        })
        .onPrepared((event): void => {
          if (event) {
            this.durationSec = event.duration;
          }
        })
        .onUpdate((event): void => {
          if (event && !this.dragging) {
            this.currentSec = event.time;
          }
        })
        .onClick((): void => { this.onScreenTap(); })

      // 右上角关闭按钮
      Image(resolveActionIcon('close'))
        .width(24)
        .height(24)
        .fillColor(Color.White)
        .position({ top: 16, right: 16 })
        .onClick((): void => { this.onClose(); })

      // 底部播放条（暂停时常显；播放中 3s 自动隐藏）
      if (this.showBar) {
        Column() {
          this.bottomBar()
        }
        .width('100%')
        .position({ bottom: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .zIndex(999)
  }
}
