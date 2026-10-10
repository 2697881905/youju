// 全局断点中心：一多适配的**唯一**断点源（官方「一多开发指导」断点体系）
//
// 关键原则：断点依据 = **应用窗口宽度（vp）**，不是机型 —— 2in1 自由窗口随意缩放、
// 折叠屏展开/折叠、分屏都随窗口走（官方最佳实践口径：「别识别机型，去测容器」）。
//
// 系统断点（窗口宽 vp）：sm(320-599) / md(600-839) / lg(840+)（xs 为穿戴档，本应用不适用）。
// 宽屏判定 isWidePane = md 及以上（≥600vp）—— 消息双栏/多列布局与悬浮栏握姿跟随的总开关。
//
// 消费方式（与本工程 navMode.ets 同款约定）：
//   @StorageProp('isWidePane') isWidePane: boolean = false;   // build 属性里直读变量才建立绑定
//   @StorageProp('currentBreakpoint') bp: string = 'sm';
//
// 折叠态：foldStatusChange 同步写 AppStorage（悬停态适配后续接入用）。
import { window, display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export const KEY_CURRENT_BREAKPOINT: string = 'currentBreakpoint';
export const KEY_IS_WIDE_PANE: string = 'isWidePane';
export const KEY_FOLD_STATUS: string = 'foldStatus';

const TAG: string = 'breakpointCenter';
const DOMAIN: number = 0x0000;

let started: boolean = false;
let density: number = 0;

export function isWideBreakpoint(bp: string): boolean {
  return bp === 'md' || bp === 'lg';
}

function applyWindowWidth(widthPx: number): void {
  const wVp: number = widthPx / (density > 0 ? density : 3.3);
  const bp: string = wVp >= 840 ? 'lg' : (wVp >= 600 ? 'md' : 'sm');
  AppStorage.setOrCreate<string>(KEY_CURRENT_BREAKPOINT, bp);
  AppStorage.setOrCreate<boolean>(KEY_IS_WIDE_PANE, isWideBreakpoint(bp));
  hilog.info(DOMAIN, TAG, 'windowWidth=%{public}fvp breakpoint=%{public}s', wVp, bp);
}

// 应用启动时调用一次（EntryAbility.onWindowStageCreate，loadContent 之前）。幂等。
export function initBreakpointCenter(ctx: common.Context): void {
  if (started) {
    return;
  }
  started = true;
  // 先落确定性初值（sm/非宽屏）：窗口实测值异步就绪后覆盖，消费方 @StorageProp 会即时收到更新。
  AppStorage.setOrCreate<string>(KEY_CURRENT_BREAKPOINT, 'sm');
  AppStorage.setOrCreate<boolean>(KEY_IS_WIDE_PANE, false);
  try {
    const disp: display.Display = display.getDefaultDisplaySync();
    density = disp.densityPixels;
    // 折叠态取 display.getFoldStatus()（Display 接口本身无 foldStatus 属性，编译期实测）
    AppStorage.setOrCreate<number>(KEY_FOLD_STATUS, Number(display.getFoldStatus()));
  } catch (e) {
    // display 不可用：density 兜底 3.3，断点仍可用
  }
  window.getLastWindow(ctx)
    .then((win: window.Window): void => {
      const rect = win.getWindowProperties().windowRect;
      applyWindowWidth(rect.width);
      win.on('windowSizeChange', (size: window.Size): void => {
        applyWindowWidth(size.width);
      });
    })
    .catch((): void => {
      hilog.warn(DOMAIN, TAG, 'getLastWindow failed, breakpoint falls back to sm');
      AppStorage.setOrCreate<string>(KEY_CURRENT_BREAKPOINT, 'sm');
      AppStorage.setOrCreate<boolean>(KEY_IS_WIDE_PANE, false);
    });
  try {
    display.on('foldStatusChange', (data: display.FoldStatus): void => {
      AppStorage.setOrCreate<number>(KEY_FOLD_STATUS, Number(data));
    });
  } catch (e) {
    // 非折叠设备不支持该事件：忽略
  }
}
