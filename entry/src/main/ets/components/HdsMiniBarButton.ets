// HdsMiniBarButton —— 浮动迷你栏按钮组件（源码集成本地化）。
//
// 来源：ohpm 三方包 hds_button@1.0.1（作者 SummerKaze，Apache-2.0）
//   https://ohpm.openharmony.cn/#/cn/detail/hds_button
//   https://gitcode.com/SummerKaze/HdsButton_Component
//
// ⚠️ 为什么不直接 ohpm 依赖：该 HAR 声明的 compatibleSdkVersion 高于本工程的
// 6.0.0(20)，hvigor 构建期 SDK 校验（00306004）直接拒绝。本页仅在 API 23+ 设备
// 进入（设置页入口已按 isImmersiveLightSenseSupported() 门禁），运行时安全由入口
// 保证，故将源码落库本地集成。除本头注释外代码与上游 1.0.1 一致。
//
// 原理：内部用「Row 包 HdsTabs」借悬浮态 barFloatingStyle 的官方材质渲染通道，
// 在任意容器里出真沉浸光感玻璃（磨砂/折射/高光）——普通组件挂 systemMaterial
// 在覆盖层不出图（§7.6.26），这是唯一能在覆盖层拿到玻璃质感的通道。

import { hdsMaterial, HdsTabs } from '@kit.UIDesignKit';

/**
 * HdsMiniBarButton 浮动迷你栏按钮组件
 * 基于 HdsTabs 的沉浸光感浮动按钮，支持全方位自定义配置
 */
@ComponentV2
export struct HdsMiniBarButton {
  // ==================== 尺寸参数 ====================

  /**
   * 按钮栏宽度
   * @default 50
   */
  @Param barWidth: number = 50;

  /**
   * 按钮栏高度
   * @default 50
   */
  @Param barHeight: number = 50;

  /**
   * 容器内边距（防止光效被裁切）
   * @default 8
   */
  @Param contentPadding: number = 8;

  /**
   * 容器尺寸，优先使用此值，未设置时自动计算
   * @default undefined
   */
  @Param containerSize: SizeOptions | undefined = undefined;

  // ==================== 图标参数 ====================

  /**
   * 图标资源（SymbolGlyph 资源类型）
   * @default $r('sys.symbol.plus')
   */
  @Param iconResource: Resource = $r('sys.symbol.plus');

  /**
   * 图标大小
   * @default 27
   */
  @Param iconSize: number = 27;

  /**
   * 图标颜色数组（支持渐变效果）
   * @default [Color.Gray]
   */
  @Param iconColor: ResourceColor[] = [Color.Gray];

  // ==================== 浮动样式参数 ====================

  /**
   * 遮罩颜色
   * @default Color.Transparent
   */
  @Param maskColor: ResourceColor = Color.Transparent;

  /**
   * 按钮栏底部边距
   * @default 8
   */
  @Param barBottomMargin: number = 8;

  /**
   * 材质类型（沉浸式效果）
   * @default hdsMaterial.MaterialType.IMMERSIVE
   */
  @Param materialType: hdsMaterial.MaterialType = hdsMaterial.MaterialType.IMMERSIVE;

  /**
   * 材质级别
   * @default hdsMaterial.MaterialLevel.ADAPTIVE
   */
  @Param materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;

  // ==================== 布局参数 ====================

  /**
   * 按钮栏位置
   * @default BarPosition.End
   */
  @Param barPosition: BarPosition = BarPosition.End;

  /**
   * 按钮栏是否与内容重叠
   * @default true
   */
  @Param barOverlap: boolean = true;

  // ==================== 事件回调 ====================

  /**
   * 按钮点击事件回调
   * @default undefined
   */
  @Param onButtonClick: (() => void) | undefined = undefined;

  // ==================== 构建函数 ====================

  /**
   * 默认按钮图标构建函数
   * 使用 SymbolGlyph 渲染默认图标
   */
  @Builder
  defaultButtonBuilder() {
    SymbolGlyph(this.iconResource)
      .fontSize(this.iconSize)
      .fontColor(this.iconColor)
  }

  /**
   * 自定义内容槽位
   * 默认使用图标构建函数，可通过尾随闭包自定义内容
   */
  @BuilderParam buttonContent: () => void = this.defaultButtonBuilder;

  // ==================== 私有方法 ====================

  /**
   * 计算容器尺寸
   * 如果已设置 containerSize 则直接使用，否则根据 barWidth、barHeight 和 padding 计算
   * @returns 容器尺寸配置
   */
  private getComputedContainerSize(): SizeOptions {
    if (this.containerSize !== undefined) {
      return this.containerSize;
    }
    return {
      width: this.barWidth + this.contentPadding * 4,
      height: this.barHeight + this.contentPadding * 4
    };
  }

  // ==================== UI 构建 ====================

  /**
   * 构建组件 UI
   * 使用 Row 包裹 HdsTabs 实现浮动按钮效果
   */
  build() {
    Row() {
      HdsTabs() {
        TabContent()
          .tabBar(this.buttonContent())
      }
      .barWidth(this.barWidth)
      .barHeight(this.barHeight)
      .barOverlap(this.barOverlap)
      .barPosition(this.barPosition)
      .barFloatingStyle({
        gradientMask: {
          maskColor: this.maskColor
        },
        barBottomMargin: this.barBottomMargin,
        systemMaterialEffect: {
          materialType: this.materialType,
          materialLevel: this.materialLevel
        }
      })
      .onTabBarClick(() => {
        if (this.onButtonClick) {
          this.onButtonClick();
        }
      })
    }
    .size(this.getComputedContainerSize())
    .padding(this.contentPadding)
  }
}
