// 地图选城（星图子模式「降落地球」Phase 2）：
// 华为地图 MapComponent 全屏交互图 + 30 座白名单城市 marker，点 marker 即选城。
// syscap 门禁（SystemCapability.Map.Core）：模拟器/OpenHarmony 无 HMS 地图——
// 由宿主（CityLayer）用 isMapKitAvailable() 决定是否给入口，本组件假定可用。
// ⚠️ 真机出图还需 AGC 控制台「开通地图服务」（client_id 已随账号 Kit 配好）；
// 未开通时地图区域空白但城市列表/索引选城不受影响（降级路径天然存在）。
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { CitySummary } from '../services/api';
import { IconButton } from '../design/components/IconButton';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 悬浮在浅色地图上的操作件墨色：固定深色，不随深浅模式翻转（浅玻璃底 + 白字不可读）
const MAP_OVERLAY_INK: string = '#2B2B2B';

@Component
export struct MapCityPicker {
  cities: CitySummary[] = [];
  onPick: (city: CitySummary) => void = (_city: CitySummary): void => {};
  onClose: () => void = (): void => {};
  // 状态栏高度（Index 启动时写入 AppStorage）：全屏覆盖层自管状态栏避让
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  private mapController: map.MapComponentController | null = null;
  // marker id → 城市：marker 点击回调只给 id，靠这张表换回城市对象
  private markerCity: Map<string, CitySummary> = new Map();

  // 地图就绪：铺城市 marker（白名单即支持城市——地图上「亮着的点」都是可降落的城）
  private onMapReady(err: Error, controller: map.MapComponentController): void {
    if (err) {
      return;
    }
    this.mapController = controller;
    controller.on('markerClick', (marker: map.Marker): void => {
      const city: CitySummary | undefined = this.markerCity.get(String(marker.getId()));
      if (city !== undefined) {
        this.onPick(city);
      }
    });
    for (const c of this.cities) {
      controller.addMarker({
        position: { latitude: c.lat, longitude: c.lng },
        title: c.name,
        clickable: true,
      } as mapCommon.MarkerOptions).then((m: map.Marker): void => {
        this.markerCity.set(String(m.getId()), c);
      }).catch((): void => {
        // 单个 marker 失败不影响其余城市
      });
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      MapComponent({
        mapOptions: {
          position: {
            // 中国几何中心附近的初始镜头（纬 34.3 / 经 108.9，缩放 4 看全国）
            target: { latitude: 34.3, longitude: 108.9 } as mapCommon.LatLng,
            zoom: 4,
          },
        } as mapCommon.MapOptions,
        mapCallback: (err: Error, controller: map.MapComponentController): void => {
          this.onMapReady(err, controller);
        },
      })
        .width('100%')
        .height('100%')

      // 顶行：提示 + 关闭（地图全屏沉浸，操作件悬浮其上；覆盖层自管状态栏避让）。
      // 悬浮件墨色固定深色不随主题翻转：glassWhite 是浅玻璃，深色模式下 primary=白字压白珠不可读
      Row() {
        Text('点亮的城市均可降落 · 点标记选城')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(MAP_OVERLAY_INK)
          .height(36)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
          .backgroundColor(ColorTokens.glassWhite)
          .borderRadius(RadiusTokens.pill)
          .alignSelf(ItemAlign.Start)
        Blank()
        // 关闭珠走 IconButton bead 档（浅玻璃珠 + 固定深墨，配方收在模板内）
        IconButton({ icon: 'close', bead: true, a11yText: '关闭', action: (): void => { this.onClose(); } })
      }
      .width('100%')
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: this.statusBarHeight + SpaceTokens.base })
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .height('100%')
  }
}
