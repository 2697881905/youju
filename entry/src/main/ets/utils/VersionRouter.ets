// VersionRouter —— 按设备 API 版本给出搜索面板的实现版本。
// systemMaterial（动态模糊融合）@since API 26；HdsTabs 浮动样式借用 @since 6.1.0(23)；
// 其余版本走 GlowInput 手工玻璃。
// 版本判断用 deviceInfo.sdkApiVersion 直接比较（apiAvailable 编译期校验上限 25，26 过不了）。

import { deviceInfo } from '@kit.BasicServicesKit';

export enum SearchPanelVersion {
  API_26 = 'api26', // API 26+：Search.systemMaterial 系统材质
  API_23 = 'api23', // API 23-25：H7 观感定制（无描边胶囊 + 柔和投影）
  LEGACY = 'legacy' // API 22 及以下：segmentStyle 手工玻璃
}

export function getSearchPanelVersion(): SearchPanelVersion {
  // ⚠️ 不用 deviceInfo.apiAvailable(26)：本工具链的编译期校验只放行 1~25，26 会被判非法。
  // 直接比 sdkApiVersion（运行时数值比较，无编译校验问题）。
  const api: number = deviceInfo.sdkApiVersion;
  if (api >= 26) {
    return SearchPanelVersion.API_26;
  }
  if (api >= 23) {
    return SearchPanelVersion.API_23;
  }
  return SearchPanelVersion.LEGACY;
}
