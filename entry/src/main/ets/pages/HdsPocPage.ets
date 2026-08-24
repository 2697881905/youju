// HDS 沉浸光感最小 POC：验证 HarmonyOS 6 沉浸光感材质在当前运行环境的可用性。
// 1) hdsMaterial.getSystemMaterialTypes() —— 设备支持的材质类型（决定沉浸光感是否可用）
// 2) HdsVisualComponent 的双流光场景（DUAL_EDGE_FLOW_LIGHT_WITH_BACKGROUND_MASK）是否真正渲染

import { hdsMaterial, HdsVisualComponent, HdsSceneController, HdsSceneType } from '@kit.UIDesignKit';
import { hdsEffect } from '@hms.hds.hdsBaseComponent';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct HdsPocPage {
  @State supportedTypes: string = '读取中…';
  @State sceneMsg: string = '点击启动光感场景';
  private controller: HdsSceneController = new HdsSceneController();

  aboutToAppear(): void {
    this.probeMaterial();
    this.configScene();
  }

  // 探测设备支持的沉浸光感材质类型
  private probeMaterial(): void {
    try {
      const types: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
      const names: string[] = types.map((t: hdsMaterial.MaterialType): string => this.materialName(t));
      this.supportedTypes = names.length > 0 ? names.join(' / ') : '(空)';
    } catch (e) {
      this.supportedTypes = '异常: ' + ((e as Error).message ?? String(e));
    }
  }

  private materialName(t: hdsMaterial.MaterialType): string {
    if (t === hdsMaterial.MaterialType.IMMERSIVE) {
      return 'IMMERSIVE(101)';
    }
    if (t === hdsMaterial.MaterialType.ADAPTIVE) {
      return 'ADAPTIVE(100)';
    }
    return 'NONE(0)';
  }

  // 配置双边缘流光场景
  private configScene(): void {
    const flow: hdsEffect.EdgeFlowLightParam = {
      startPos: 0.2,
      endPos: 0.8,
      color: '#33FF4777',
    };
    const dual: hdsEffect.DualEdgeFlowLightParam = {
      firstEdgeFlowLight: flow,
      secondEdgeFlowLight: flow,
    };
    this.controller.setSceneParams({
      backgroundMaskColors: ['#00000000', '#33000000', '#00FFFFFF'],
      firstEdgeFlowLight: dual.firstEdgeFlowLight,
      secondEdgeFlowLight: dual.secondEdgeFlowLight,
    });
  }

  build() {
    Column({ space: 16 }) {
      Text('HDS 沉浸光感 POC')
        .fontSize(20).fontWeight(700).margin({ top: 20 })

      // 光感场景容器：HdsVisualComponent 作为宿主包裹流光内容
      HdsVisualComponent() {
        Column() {
          Text('沉浸光感容器')
            .fontSize(16).fontColor('#333333')
          Text('点击触发流光')
            .fontSize(13).fontColor('#888888').margin({ top: 6 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%').height(200)
      .borderRadius(24)
      .clip(true)
      .backgroundColor('#22FFFFFF')
      .scene(HdsSceneType.DUAL_EDGE_FLOW_LIGHT_WITH_BACKGROUND_MASK, this.controller)
      .onClick(() => { this.startScene(); })

      Text('点击上方容器启动/停止流光')
        .fontSize(14).fontColor('#888888')

      // 诊断结果卡片
      Column({ space: 12 }) {
        Text('设备支持的沉浸光感类型：')
          .fontSize(14).fontColor('#666666').width('100%')
        Text(this.supportedTypes)
          .fontSize(16).fontWeight(600).fontColor('#111111').width('100%')
      }
      .padding(16)
      .backgroundColor('#F4F6FB')
      .borderRadius(16)
      .width('100%')

      Row({ space: 12 }) {
        Button('启动光感')
          .fontSize(15)
          .onClick(() => { this.startScene(); })
        Button('停止光感')
          .fontSize(15)
          .onClick(() => {
            try {
              this.controller.stop();
              this.sceneMsg = '已调用 stop()';
            } catch (e) {
              this.sceneMsg = 'stop 异常: ' + ((e as Error).message ?? String(e));
            }
          })
      }

      Text(this.sceneMsg)
        .fontSize(14).fontColor('#888888')

      Button('返回首页')
        .onClick(() => {
          router.back();
        })
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .backgroundColor('#FFFFFF')
  }

  private startScene(): void {
    try {
      this.controller.start();
      this.sceneMsg = '已调用 start()';
    } catch (e) {
      this.sceneMsg = 'start 异常: ' + ((e as Error).message ?? String(e));
    }
  }
}