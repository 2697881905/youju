// 沉浸光感 / 系统玻璃材质统一入口（替换项目内手工 backdropBlur 模拟玻璃）。
//
// 替换策略：
// - 通用组件（Column/Row/Stack/Button 等）使用系统官方 backgroundBlurStyle(BlurStyle)，
//   替代手工「半透明底色 + backdropBlur」组合，由系统统一控制模糊半径与降级。
// - 华为真机（HarmonyOS 6.0.0.328 SP52+ / API 23+）支持 HDS 沉浸光感材质时，
//   通过 hdsMaterial.getSystemMaterialTypes() 探测，优先使用 IMMERSIVE + ADAPTIVE 档位，
//   让系统按设备性能自动匹配最强/均衡/弱光感。
// - 模拟器（OpenHarmony，实测 getSystemMaterialTypes() 返回空）与低端机自动回退到
//   backgroundBlurStyle 材质，绝不让 UI 白屏或崩溃。

import { hdsMaterial } from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

// 沉浸光感支持态：true=系统材质（真机 hdsMaterial 可用），false=回退普通背景模糊。
// 进程级缓存：探测一次，避免每次 build 都查询系统能力。
let immersiveSupported: boolean | null = null;

/**
 * 探测当前设备是否支持 HDS 沉浸光感材质。
 * 结果进程内缓存；探测失败（模拟器/异常）返回 false，不抛出。
 */
export function isImmersiveLightSenseSupported(): boolean {
  if (immersiveSupported !== null) {
    return immersiveSupported;
  }
  try {
    const types: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    // 支持 IMMERSIVE（沉浸光感）即认为可用；仅有 ADAPTIVE/NONE 时按不完整光感处理。
    immersiveSupported = types.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;
    hilog.info(0xFF00, 'YouJuImmersive', 'real probe len=%{public}d immersive=%{public}d',
      types.length, immersiveSupported ? 1 : 0);
  } catch (e) {
    immersiveSupported = false;
    hilog.error(0xFF00, 'YouJuImmersive', 'probe failed: %{public}s', (e as Error).message);
  }
  return immersiveSupported;
}

// 沉浸光感档位：一律交给系统自适应（ADAPTIVE），禁止在低端设备写死 EXQUISITE。
export const IMMERSIVE_MATERIAL_LEVEL: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;

/**
 * 沉浸光感材质类型：支持时用 IMMERSIVE，否则 NONE（配合 backgroundBlurStyle 降级）。
 */
export function immersiveMaterialType(): hdsMaterial.MaterialType {
  return isImmersiveLightSenseSupported()
    ? hdsMaterial.MaterialType.IMMERSIVE
    : hdsMaterial.MaterialType.NONE;
}

// 通用组件系统材质档位映射（backgroundBlurStyle），按原手工玻璃的“厚度”对应：
// - 悬浮栏 / 底部导航 / 弹层（原 barSurface+blur24）→ BACKGROUND_THICK（通透厚玻璃）
// - 内容卡片（原 elevated）→ BACKGROUND_REGULAR（中等模糊）
// - 按压按钮 / 分隔浅底 → BACKGROUND_THIN
// 注：BlurStyle BACKGROUND_* 与 COMPONENT_* 系列自带系统着色与半透明，backgroundBlurStyle 由系统统一降级。
export class GlassBlurStyle {
  // 悬浮栏/底部导航/弹层：最接近原「barSurface + blur24」的通透厚玻璃。
  static readonly Floating: BlurStyle = BlurStyle.BACKGROUND_THICK;
  // 内容卡片 / 半透明信息区：中等模糊，保留文字可读性。
  static readonly Card: BlurStyle = BlurStyle.BACKGROUND_REGULAR;
  // 按压态 / 浅色块：轻量模糊，避免过重光感。
  static readonly Press: BlurStyle = BlurStyle.BACKGROUND_THIN;
  // 高强调对话框（隐私弹窗等）：更强玻璃感。
  static readonly Dialog: BlurStyle = BlurStyle.BACKGROUND_THICK;
}