// ImmersiveSurface —— 沉浸光感表面容器（统一替换项目内面板级毛玻璃）。
//
// 实现：在子内容下方叠加一层 HDS「双边流光」视效（HdsVisualComponent +
// DUAL_EDGE_FLOW_LIGHT_WITH_BACKGROUND_MASK），透过上层半透明系统玻璃
// 透出动态光晕，呈现华为 HarmonyOS 6 沉浸光感视觉。
//
// 降级策略：仅当设备支持 IMMERSIVE 材质（hdsMaterial.getSystemMaterialTypes() 命中）
// 时才渲染流光层；模拟器 / 低端机自动跳过流光，仅保留原有的 backgroundBlurStyle 系统玻璃，
// 视觉零变化、绝不白屏。
//
// 用法（保持表面自身全部样式、事件与布局不变）：
//   ImmersiveSurface({ radius: RadiusTokens.floatingBar }) {
//     Row() { ... }
//     .backgroundBlurStyle(GlassBlurStyle.Floating)
//     .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
//     .border(...).borderRadius(...).shadow(...)
//   }
// 若表面使用 .position() 绝对定位，请把 .position 移到 ImmersiveSurface 外层（语义不变）。

import { HdsSceneController, HdsSceneType, HdsVisualComponent } from '@kit.UIDesignKit';
import { isImmersiveLightSenseSupported } from '../../utils/immersiveMaterial';

@Component
export struct ImmersiveSurface {
  @BuilderParam content: () => void = this.emptyContent;
  // 流光层圆角：需与表面内容的 borderRadius 保持一致，流光才贴合边缘。
  @Prop radius: number = 16;
  // 可选：显式控制外层 Stack 尺寸；默认跟随内容自动包裹。
  @Prop surfaceWidth: Length = 'auto';
  @Prop surfaceHeight: Length = 'auto';
  // 流光自带背景蒙层颜色：透过玻璃呈现环境光色。透明度宜克制（约 10%~14%），
  // 避免盖过页面主色；数组内按渐变起止顺序排列（透出后呈柔和环境色）。
  @Prop maskColors: Array<ResourceColor> = ['#1EFFFFFF', '#1E86CFFF'];
  // 两条边流光颜色：窄表面（搜索框 44vp）光带细，需要较高亮度才明显；
  // 大面板边缘同样适用，配合 ADAPTIVE 光感不刺眼。
  @Prop edgeColor: ResourceColor = '#C4FFFFFF';
  @Prop edgeColor2: ResourceColor = '#8FC8EFFF';
  // 强制定尺寸（px/vp 数值）：测量不可靠的弹性场景（layoutWeight 拉伸）直接指定实际宽高，
  // 同时作用于外层 Stack 与流光层，避免流光按未拉伸尺寸绘制。
  @Prop explicitWidth: number = 0;
  @Prop explicitHeight: number = 0;

  // HdsSceneController @since 6.0.2(22)：API 20/21 上构造函数不存在。
  // 惰性创建，且仅在 isImmersiveLightSenseSupported()（API 23+）分支内使用——
  // 低版本设备永远不会触碰构造，避免字段初始化即崩。
  private sceneController: HdsSceneController | null = null;
  // 流光层实际像素尺寸：由内容 onAreaChange 实测驱动。
  // 不用 width/height('100%')——百分比会在自动尺寸 Stack 中按父约束解析，
  // 在对话框场景会撑满整屏（发布弹窗全屏发光的根因）。
  @State glowWidth: number = 0;
  @State glowHeight: number = 0;

  @Builder
  emptyContent(): void {}

  // 流光/光感框优先使用 explicit 尺寸（弹性场景直接指定真实宽高），否则回退根 Stack 实测值。
  private glowW(): number {
    return this.explicitWidth > 0 ? this.explicitWidth : this.glowWidth;
  }

  private glowH(): number {
    return this.explicitHeight > 0 ? this.explicitHeight : this.glowHeight;
  }

  // 惰性获取控制器：仅在 API 23+（isImmersiveLightSenseSupported）路径下调用，
  // 保证 new HdsSceneController()（@since 22）只在存在该类的设备上执行。
  private getSceneController(): HdsSceneController {
    if (this.sceneController === null) {
      this.sceneController = new HdsSceneController();
    }
    return this.sceneController;
  }

  aboutToAppear(): void {
    if (isImmersiveLightSenseSupported()) {
      this.getSceneController().setSceneParams({
        backgroundMaskColors: this.maskColors,
        firstEdgeFlowLight: { startPos: 0, endPos: 0.5, color: this.edgeColor },
        secondEdgeFlowLight: { startPos: 0, endPos: -0.5, color: this.edgeColor2 },
      });
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.content()
      }

      // 流光层置于表面最上层（部分真机 backgroundBlurStyle 渲染为不透明面板，
      // 放底层会被完全遮住）。尺寸由 explicit/实测数据驱动，绝不撑满父容器；
      // 触摸透传，不拦截表面交互。
      if (isImmersiveLightSenseSupported() && this.glowW() > 0 && this.glowH() > 0) {
        HdsVisualComponent()
          .scene(HdsSceneType.DUAL_EDGE_FLOW_LIGHT_WITH_BACKGROUND_MASK, this.getSceneController())
          .width(this.glowW())
          .height(this.glowH())
          .borderRadius(this.radius)
          .clip(true)
          .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    // explicit 数值同时约束外层 Stack 尺寸（Length 兼容 number）
    .width(this.explicitWidth > 0 ? this.explicitWidth : this.surfaceWidth)
    .height(this.explicitHeight > 0 ? this.explicitHeight : this.surfaceHeight)
    // 测量根 Stack：flex 拉伸（layoutWeight）时组件根节点拿到最终分配尺寸，
    // 内层自动宽度 Column 会测到未拉伸的小值（搜索框流光“尺寸太小”的根因）。
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      const w: number = parseFloat(String(newValue.width));
      const h: number = parseFloat(String(newValue.height));
      if (w > 0 && h > 0 && (w !== this.glowWidth || h !== this.glowHeight)) {
        this.glowWidth = w;
        this.glowHeight = h;
      }
    })
  }
}