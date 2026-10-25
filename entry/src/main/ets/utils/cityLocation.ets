// 同城维定位工具（星图子模式「降落地球」Phase 2）：
// 1) canIUse 门禁 SystemCapability.Map.Core —— 华为地图服务（HMS）只在真机可用，
//    模拟器/OpenHarmony 无该 syscap，调用点据此隐藏地图入口；
// 2) locateCity()：定位（geoLocationManager）→ 反解城市名（site.reverseGeocode）→
//    与城市白名单比对。任何一步失败都返回 null 安静降级（索引选城永远可用）。
// 权限：ohos.permission.APPROXIMATELY_LOCATION + LOCATION（module.json5 声明、
// 用时请求）；拒绝授权同样返回 null，不重复骚扰。
import geoLocationManager from '@ohos.geoLocationManager';
import site from '@hms.core.map.site';
import type { mapCommon } from '@kit.MapKit';
import { common } from '@kit.AbilityKit';
import { abilityAccessCtrl, bundleManager } from '@kit.AbilityKit';
import type { PermissionRequestResult } from '@ohos.abilityAccessCtrl';

import type { Permissions } from '@kit.AbilityKit';
const LOCATION_PERMISSIONS: Permissions[] = [
  'ohos.permission.APPROXIMATELY_LOCATION' as Permissions,
  'ohos.permission.LOCATION' as Permissions,
];

// 城市白名单（与后端 utils/cities.ts 同源的前端镜像：定位反解出的城市名只认这 30 座）
const CITY_NAMES: string[] = [
  '北京', '上海', '广州', '深圳', '天津', '重庆', '杭州', '成都', '武汉', '西安',
  '南京', '长沙', '郑州', '济南', '青岛', '苏州', '大连', '厦门', '合肥', '福州',
  '昆明', '贵阳', '沈阳', '长春', '哈尔滨', '石家庄', '太原', '南宁', '兰州', '乌鲁木齐',
];

// 华为地图服务是否可用（进程级缓存，同步确定值）
let mapCapable: boolean | null = null;

export function isMapKitAvailable(): boolean {
  if (mapCapable === null) {
    try {
      mapCapable = canIUse('SystemCapability.Map.Core');
    } catch (e) {
      mapCapable = false;
    }
  }
  return mapCapable;
}

// 反解城市名 → 白名单城市名（未命中返回 null：定位在白名单之外的城市不强行匹配）
function matchCityName(raw: string | undefined | null): string | null {
  if (raw === undefined || raw === null) {
    return null;
  }
  const n: string = raw.replace(/\s/g, '').replace(/(市)$/, '');
  return CITY_NAMES.includes(n) ? n : null;
}

export interface LocatedCity {
  cityName: string;
  lng: number;
  lat: number;
}

// 定位并反解城市。需要 UIContext 弹权限请求；失败/拒绝/未命中白名单 → null。
// 定位权限（user_grant）：已授权直通；未授权弹一次系统授权（拒绝后系统记忆，
// 后续返回拒绝——安静降级为手动选城，不重复骚扰）。
async function ensureLocationPermission(ctx: common.UIAbilityContext): Promise<boolean> {
  const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  try {
    const bundleInfo: bundleManager.BundleInfo = await bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    const statuses: number[] = await Promise.all(LOCATION_PERMISSIONS.map(async (perm: Permissions): Promise<number> => {
      const st: abilityAccessCtrl.GrantStatus = await atManager.checkAccessToken(
        bundleInfo.appInfo.accessTokenId, perm);
      return st;
    }));
    if (statuses.every((st: number): boolean => st === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED)) {
      return true;
    }
  } catch (e) {
    // 查询失败不阻断：继续走申请弹窗
  }
  try {
    const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(ctx, LOCATION_PERMISSIONS);
    return result.authResults.length > 0
      && result.authResults.every((r: number): boolean => r === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED);
  } catch (e) {
    return false;
  }
}

export async function locateCurrentCity(context: common.UIAbilityContext): Promise<LocatedCity | null> {
  if (!isMapKitAvailable()) {
    return null; // 无地图 syscap 的环境（模拟器）也没有 HMS 定位链路
  }
  const granted: boolean = await ensureLocationPermission(context);
  if (!granted) {
    return null;
  }
  try {
    const request: geoLocationManager.CurrentLocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.ACCURACY,
      timeoutMs: 8000,
    };
    const loc: geoLocationManager.Location = await geoLocationManager.getCurrentLocation(request);
    // 反解：坐标 → 城市（Petal Maps Site Kit，GCJ-02 与定位一致）
    const params: site.ReverseGeocodeParams = {
      location: { longitude: loc.longitude, latitude: loc.latitude } as mapCommon.LatLng,
      language: 'zh',
    };
    const result: site.ReverseGeocodeResult = await site.reverseGeocode(params);
    // 城市名取 addressComponent：adminLevel2=地级市、locality=直辖市/县级行政区，先后比对
    const comp: site.AddressComponent | undefined = result.addressComponent;
    const name: string | null = matchCityName(comp?.adminLevel2) ?? matchCityName(comp?.locality);
    if (name === null) {
      return null;
    }
    return { cityName: name, lng: loc.longitude, lat: loc.latitude };
  } catch (e) {
    return null;
  }
}
