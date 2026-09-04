// 账号绑定页品牌标识映射：第三方/系统账号 → 彩色品牌 Logo + 浅色品牌底。
// Logo 自带品牌色（SVG 内多色，勿用 fillColor 染色）；底块用品牌色低透明度，
// 与 actionIcons 同风格：Map<string, Resource> + 字面量 $r() 编译期校验资源存在。
import { Provider } from '../models/types';

const BRAND_ICONS: Map<string, Resource> = new Map<string, Resource>([
  ['harmony', $r('app.media.brand_harmony')],
  ['huawei', $r('app.media.brand_huawei')],
  ['wechat', $r('app.media.brand_wechat')],
]);

// 解析账号类型对应的彩色品牌 Logo 资源；未命中回退鸿蒙（主账号）标识。
export function brandIconRes(provider: Provider): Resource {
  const found: Resource | undefined = BRAND_ICONS.get(provider);
  if (found !== undefined) {
    return found;
  }
  return $r('app.media.brand_harmony');
}

// 品牌 Logo 底块色（品牌色低透明度，适配浅/深色卡片背景）。
export function brandTileTint(provider: Provider): ResourceColor {
  switch (provider) {
    case 'huawei':
      return '#14E8112D';
    case 'wechat':
      return '#1407C160';
    default:
      return '#1A1677FF';
  }
}
