import { resolveDisplayImageUrl, resolvePlayableMediaUrl } from '../services/api';
import { TypeTokens } from '../design/tokens/type';
import { GlassBlurStyle } from '../utils/immersiveMaterial';

// 全屏视频播放器（自绘现代播放条，替代系统 controls 旧样式）：
// - 挂载即自动播放，画面 Contain 完整展示；不用系统控制器（其样式老旧且带边框线）
// - 起播优化：cos:// 引用先换 COS 直读签名再喂给播放器（见 resolvePlayableMediaUrl），
//   解析期间先显示封面不黑屏；直读不可达时回退字节流代理。
// - 底部玻璃质感播放条：播放/暂停 + 进度滑杆 + 时间；播放中 3s 自动隐藏，点按画面切换显隐
// - 右上角关闭；本组件自身**不处理返回**：它是纯展示层，由宿主决定关闭动作
//   （独立播放器页：NavDestination 的 pop / @Entry 的 router.back()；聊天页内浮层：
//   宿主在 utils/overlayBackGuard 登记守卫后经双壳返回拦截消费）。卸载即停播、释放播放器。
@Component
export struct VideoViewer {
  @Prop @Watch('onSourceChanged') url: string = '';
  // 可选封面：解析/首帧就绪前由它顶上，避免打开瞬间整屏黑场
  @Prop poster: string = '';
  onClose: () => void = (): void => {};

  private controller: VideoController = new VideoController();
  // 实际喂给播放器的源：解析完成前为空 → 只显示封面
  @State src: string = '';
  @State playing: boolean = false;
  @State currentSec: number = 0;
  @State durationSec: number = 0;
  @State dragging: boolean = false;
  @State showBar: boolean = true;
  private hideTimer: number = -1;
  // 代理回退地址（onError 兜底用）与「当前是否在用直读源」
  private proxySrc: string = '';
  private usingDirect: boolean = false;
  // 解析代次：源切换后丢弃过期结果，避免旧 URL 回填
  private resolveToken: number = 0;

  aboutToAppear(): void {
    this.resolveSource();
  }

  aboutToDisappear(): void {
    this.clearHideTimer();
  }

  private onSourceChanged(): void {
    this.playing = false;
    this.currentSec = 0;
    this.durationSec = 0;
    this.resolveSource();
  }

  // 解析播放源：cos:// → COS 直读签名（快），失败/非 cos → 字节流代理
  private async resolveSource(): Promise<void> {
    const token: number = ++this.resolveToken;
    this.proxySrc = resolveDisplayImageUrl(this.url);
    let playable: string = this.proxySrc;
    try {
      playable = await resolvePlayableMediaUrl(this.url);
    } catch (e) {
      playable = this.proxySrc;
    }
    if (token !== this.resolveToken) {
      return;
    }
    this.usingDirect = playable.length > 0 && playable !== this.proxySrc;
    this.src = playable;
  }

  // 直读源播放失败（个别网络对 COS 域名不友好）→ 回退字节流代理，只回退一次
  private fallbackToProxy(): void {
    if (!this.usingDirect || this.proxySrc.length === 0 || this.src === this.proxySrc) {
      return;
    }
    this.usingDirect = false;
    this.src = this.proxySrc;
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
    // 不再包 ImmersiveSurface：HDS 双边流光按用户要求去掉，仅保留系统玻璃材质本身
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
    .backgroundBlurStyle(GlassBlurStyle.Dialog)
    // 视频底下没有可透出的流光层，保留深色磨砂底保证白字可读（原非沉浸设备同款兜底值）
    .backgroundColor('#59000000')
    .borderRadius(999)
    .margin({ left: 16, right: 16, bottom: 34 })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      if (this.src.length > 0) {
        Video({
          src: this.src,
          // 首帧就绪前显示封面；无封面时不传（undefined == 未设置）
          previewUri: this.poster.length > 0 ? resolveDisplayImageUrl(this.poster) : undefined,
          controller: this.controller,
        })
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
        .onError((): void => {
          // 直读源失败（个别网络对 COS 域名不友好）：回退字节流代理，只回退一次
          this.fallbackToProxy();
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
      } else if (this.poster.length > 0) {
        // 播放源解析中：先显示封面（无封面时保持黑底，不显示半成品播放器）
        Image(resolveDisplayImageUrl(this.poster))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .draggable(false)
      }

      // 右上角关闭按钮
      Image($r('app.media.close_x_white'))
        .width(24)
        .height(24)
        .position({ top: 16, right: 16 })
        .onClick((): void => { this.onClose(); })
        .fillColor(Color.White)

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
