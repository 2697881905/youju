// 同城维城市白名单（星图子模式「降落地球」）。
// code 与华为地图 Site Kit 的城市名对应（前端做坐标/定位映射用）；列表按
// 直辖市 → 省会/首府 → 计划单列 → 热门城市的直觉序排布，供热门城市格直接渲染。
export interface CityItem {
  code: string;
  name: string;
  province: string;
  // 地图选城/定位反解用的参考坐标（GCJ-02，与 MapKit 一致）
  lng: number;
  lat: number;
}

export const SUPPORTED_CITIES: CityItem[] = [
  { code: 'bj', name: '北京', province: '北京', lng: 116.407, lat: 39.904 },
  { code: 'sh', name: '上海', province: '上海', lng: 121.473, lat: 31.230 },
  { code: 'gz', name: '广州', province: '广东', lng: 113.264, lat: 23.129 },
  { code: 'sz', name: '深圳', province: '广东', lng: 114.058, lat: 22.543 },
  { code: 'tj', name: '天津', province: '天津', lng: 117.190, lat: 39.125 },
  { code: 'cq', name: '重庆', province: '重庆', lng: 106.551, lat: 29.563 },
  { code: 'hz', name: '杭州', province: '浙江', lng: 120.155, lat: 30.274 },
  { code: 'cd', name: '成都', province: '四川', lng: 104.066, lat: 30.572 },
  { code: 'wh', name: '武汉', province: '湖北', lng: 114.305, lat: 30.593 },
  { code: 'xa', name: '西安', province: '陕西', lng: 108.940, lat: 34.341 },
  { code: 'nj', name: '南京', province: '江苏', lng: 118.796, lat: 32.060 },
  { code: 'csa', name: '长沙', province: '湖南', lng: 112.938, lat: 28.228 },
  { code: 'zz', name: '郑州', province: '河南', lng: 113.625, lat: 34.746 },
  { code: 'jn', name: '济南', province: '山东', lng: 117.120, lat: 36.651 },
  { code: 'qingdao', name: '青岛', province: '山东', lng: 120.382, lat: 36.067 },
  { code: 'suzhou', name: '苏州', province: '江苏', lng: 120.585, lat: 31.299 },
  { code: 'dl', name: '大连', province: '辽宁', lng: 121.614, lat: 38.907 },
  { code: 'xm', name: '厦门', province: '福建', lng: 118.089, lat: 24.479 },
  { code: 'hefei', name: '合肥', province: '安徽', lng: 117.227, lat: 31.820 },
  { code: 'fz', name: '福州', province: '福建', lng: 119.296, lat: 26.074 },
  { code: 'km', name: '昆明', province: '云南', lng: 102.832, lat: 24.880 },
  { code: 'gy', name: '贵阳', province: '贵州', lng: 106.630, lat: 26.647 },
  { code: 'sy', name: '沈阳', province: '辽宁', lng: 123.431, lat: 41.805 },
  { code: 'changchun', name: '长春', province: '吉林', lng: 125.324, lat: 43.886 },
  { code: 'hrb', name: '哈尔滨', province: '黑龙江', lng: 126.642, lat: 45.756 },
  { code: 'shijiazhuang', name: '石家庄', province: '河北', lng: 114.514, lat: 38.042 },
  { code: 'taiyuan', name: '太原', province: '山西', lng: 112.548, lat: 37.869 },
  { code: 'nanning', name: '南宁', province: '广西', lng: 108.366, lat: 22.817 },
  { code: 'lanzhou', name: '兰州', province: '甘肃', lng: 103.834, lat: 36.061 },
  { code: 'urumqi', name: '乌鲁木齐', province: '新疆', lng: 87.616, lat: 43.825 },
];

const BY_CODE = new Map(SUPPORTED_CITIES.map((c) => [c.code, c]));

export function findCity(code: string | null | undefined): CityItem | undefined {
  if (!code) {
    return undefined;
  }
  return BY_CODE.get(code);
}

// 按城市名（如「北京」）查 code —— 定位反解 / 地图点选后的映射用
export function findCityByName(name: string): CityItem | undefined {
  const n = name.replace(/\s|(市)$/g, '');
  return SUPPORTED_CITIES.find((c) => c.name === n);
}
