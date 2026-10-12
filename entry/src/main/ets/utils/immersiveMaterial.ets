// 沉浸光感 / 系统玻璃材质统一入口（替换项目内手工 backdropBlur 模拟玻璃）。
//
// ⚠️ 兼容性铁律（AGC 审核问题①：API 6.0.2(22) 无法启动的根因）：
// hdsMaterial 命名空间与 HdsTabs.barFloatingStyle 均 @since 6.1.0(23)。
// API 22 及以下设备的运行时里不存在 @hms.hds.hdsMaterial 模块——
// 本文件（以及任何启动路径文件）绝不能静态 import hdsMaterial，
// 也不能在模块顶层求值 hdsMaterial.*（两者都会在 API 22 上加载即崩，
// 表现为应用无法启动）。改用 deviceInfo.sdkApiVersion + canIUse 同步探测。
//
// 替换策略：
// - 通用组件（Column/Row/Stack/Button 等）使用系统官方 backgroundBlurStyle(BlurStyle)，
//   替代手工「半透明底色 + backdropBlur」组合，由系统统一控制模糊半径与降级。
// - 华为真机（HarmonyOS 6.1.0 / API 23+）支持 HDS 沉浸光感材质时，
//   组件底色用透明 + 系统材质档位 IMMERSIVE，让系统按设备性能自适应。
// - API 22 及以下、模拟器（OpenHarmony 无 HMS syscap）自动回退到
//   backgroundBlurStyle 材质，绝不让 UI 白屏或崩溃。
//
// 数值对照（来自 SDK @hms.hds.hdsMaterial.d.ets，@since 6.1.0(23)）：
//   hdsMaterial.MaterialType: NONE=0, ADAPTIVE=100, IMMERSIVE=101
//   hdsMaterial.MaterialLevel: EXQUISITE=0, GENTLE=1, SMOOTH=2, ADAPTIVE=10
// 使用处直接传数值字面量（枚举类型在 TS 5.x 下是数值字面量联合，字面量可直接赋值），
// 避免为了枚举值而静态 import 缺失模块。

import deviceInfo from '@ohos.deviceInfo';
import { uiMaterial } from '@kit.ArkUI';

// HDS 沉浸光感相关 API（hdsMaterial / HdsTabs.barFloatingStyle）自 HarmonyOS 6.1.0（API 23）起提供。
const HDS_IMMERSIVE_MIN_API: number = 23;
// canIUse 探测的 HMS 系统能力：HDS 组件核心（HdsTabs/HdsVisualComponent/hdsMaterial 同属此 syscap）。
const HDS_SYSCAP: string = 'SystemCapability.UIDesign.HDSComponent.Core';

// 沉浸光感支持态：true=系统材质（真机 API 23+），false=回退普通背景模糊。
// 进程级缓存：探测一次（同步、确定值，不会在运行期翻转），避免每次 build 都查询。
let immersiveSupported: boolean | null = null;

/**
 * 探测当前设备是否支持 HDS 沉浸光感材质。
 * 同步、确定、进程内缓存；探测异常时返回 false，不抛出。
 * 判定条件（同时满足）：
 * 1) 设备 API 级别 >= 23（hdsMaterial / barFloatingStyle 的 @since）；
 * 2) 设备声明 HDS 组件 syscap（模拟器/OpenHarmony 环境为 false，自动降级）。
 */
export function isImmersiveLightSenseSupported(): boolean {
  if (immersiveSupported === null) {
    try {
      immersiveSupported = deviceInfo.sdkApiVersion >= HDS_IMMERSIVE_MIN_API
        && canIUse(HDS_SYSCAP);
    } catch (e) {
      immersiveSupported = false;
    }
  }
  return immersiveSupported;
}

// 沉浸光感档位：一律交给系统自适应（ADAPTIVE=10），禁止在低端设备写死 EXQUISITE。
export const HDS_MATERIAL_LEVEL_ADAPTIVE: number = 10;
// hdsMaterial.MaterialType.IMMERSIVE=101（数值与 SDK 枚举一致，见文件头对照表）。
export const HDS_MATERIAL_TYPE_IMMERSIVE: number = 101;

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

// —— 通用属性 systemMaterial（@since 26.0.0）：普通组件版的沉浸光感 ——
// 与上面的 HDS 轨（hdsMaterial / HdsTabs，API 23+）不同，本轨由 ArkUI 通用属性承载：
//   Row() { ... }.attributeModifier(new TopButtonMaterialModifier())
// 低版本设备上 systemMaterial 属性方法不存在，必须做版本门禁：按官方《ArkTS API 兼容性保护》
// 的示例二/三（Scroll 缩放、Text 跑马灯），把新属性放进 AttributeModifier.applyNormalAttribute
// 的 apiAvailable 分支内调用 —— 门禁不通过就完全不触碰 uiMaterial。
// 门禁写作字面量 deviceInfo.apiAvailable('26.0.0')：编译期由 ets-loader 降级为设备版本比较，
// 低版本设备（API < 26）运行期不会因调用不存在的接口而崩溃。
//
// 档位规范（沉浸光感设计指南 · 场景规范；数值与 uiMaterial.ImmersiveStyle 一致）：
//   顶部悬浮 → ULTRA_THIN(0)；底部悬浮 → THIN(1)；任意位置弹出 → THICK(3)；半模态/弹框 → ULTRA_THICK(4)。

// 材质实例进程级缓存：只会在门禁内创建，低版本设备永不执行构造。
let topButtonMaterial: uiMaterial.Material | null = null;

// 通用属性 systemMaterial（uiMaterial 轨）是否实际生效：与下面的修饰器门禁同源
// （deviceInfo.apiAvailable('26.0.0')，编译期由 ets-loader 降级为设备版本比较）。
// 供使用处在材质生效时撤掉自绘兜底：背景模糊会遮挡材质效果（官方 FAQ），
// 自绘阴影会与材质自带阴影叠加，都必须让位给系统材质。
let systemMaterialActive: boolean | null = null;

export function isSystemMaterialActive(): boolean {
  if (systemMaterialActive === null) {
    try {
      systemMaterialActive = deviceInfo.apiAvailable('26.0.0');
    } catch (e) {
      systemMaterialActive = false;
    }
  }
  return systemMaterialActive;
}

function getTopButtonMaterial(): uiMaterial.Material {
  if (topButtonMaterial === null) {
    topButtonMaterial = new uiMaterial.ImmersiveMaterial({
      // 顶部常驻按钮：ULTRA_THIN（极强通透），与顶栏区域的光感规范一致。
      style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
      // 按压交互形变：指尖触控牵引材质形变，强化 Z 轴空间反馈。
      interactive: true,
      // 投影关闭（API 26 默认 true，真机实证）：ImmersiveMaterial 的投影画在组件外圈，
      // 而挂材质的控件都在 HdsNavigation 标题栏的行内——bottomBuilder 行（BottomCustomNode）
      // clip=true 且只比控件高 4vp，投影被拦腰裁死在「标题区/内容区」交界处，
      // 渲染成一条硬边灰带（比 canvas 暗 8~14 级），正是「分段栏下方图层颜色不一致」的根因。
      // 材质只在标题栏官方生效区内渲染，内容区的同材质实例本就不出图，所以此处关闭
      // 不影响任何内容区按钮；半模态材质（getSheetImmersiveMaterial）保留默认投影。
      applyShadow: false,
    });
  }
  return topButtonMaterial;
}

/**
 * 顶部常驻按钮的沉浸光感修饰器（通用属性 systemMaterial）。
 * 低版本设备（API < 26）门禁不通过：不设置材质，组件保留自身的背景/边框/阴影，视觉零变化。
 */
export class TopButtonMaterialModifier implements AttributeModifier<CommonAttribute> {
  applyNormalAttribute(instance: CommonAttribute): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      instance.systemMaterial(getTopButtonMaterial());
    }
  }
}

// 半模态/弹框材质实例进程级缓存：只在门禁内创建，低版本设备永不执行构造。
let sheetImmersiveMaterial: uiMaterial.Material | null = null;

/**
 * 半模态（bindSheet）沉浸光感材质工厂。**载体纠正**（本次「面板全透明」根因）：
 * HarmonyOS 7（API 26）起，把 systemMaterial 挂在普通内容组件（如 bindSheet builder 内的
 * Column）属于生效范围外，完全不渲染——之前既把材质挂在内容 Column、又把卡片
 * backgroundColor 置为 Color.Transparent，两者叠加后面板只剩遮罩底层 → 全透明。
 * 官方文档明确：「半模态转场」属弹窗类接口，沉浸光感可在全页面生效，且通过
 * options 参数中的 systemMaterial 字段设置（本 SDK 已声明 SheetOptions.systemMaterial
 * @since 26.0.0）——这才是半模态的唯一正确载体。
 *
 * @returns API ≥ 26（门禁通过）返回 ULTRA_THICK 沉浸光感材质，供 SheetOptions.systemMaterial 使用；
 *          API < 26 / 模拟器 / OpenHarmony 返回 undefined，使用处按 isSystemMaterialActive() 回退
 *          elevated 实色底，且绝不触碰 uiMaterial 构造（避免低版本加载即崩）。
 */
export function getSheetImmersiveMaterial(): uiMaterial.Material | undefined {
  if (!deviceInfo.apiAvailable('26.0.0')) {
    return undefined;
  }
  if (sheetImmersiveMaterial === null) {
    sheetImmersiveMaterial = new uiMaterial.ImmersiveMaterial({
      // 沉浸光感设计指南 · 场景规范：半模态 / 弹框 → ULTRA_THICK（极强模糊）。
      style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
      // 面板为静态承载容器，非按压控件，关闭触控形变。
      interactive: false,
    });
  }
  return sheetImmersiveMaterial;
}
