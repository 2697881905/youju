// GlassTokens —— 玻璃材质共享令牌。
// 历史上 GlowInput 与 SegmentedControl 各自维护同值常量（SEGMENT_GLASS_* / IMMERSIVE_*），
// 存在漂移风险，2026-09-29 统一上收到此（两处消费方已改为从这里导入）。

import { ColorTokens } from './color';

export class GlassTokens {
  // segmentStyle 玻璃材质（与分段栏共享）：半透明白底 + backdropBlur + 1px 高光描边
  static readonly SEGMENT_BG: ResourceColor = '#20FFFFFF';
  static readonly SEGMENT_BLUR: number = 20;
  static readonly SEGMENT_BORDER: ResourceColor = '#30FFFFFF';
  // 普通模式底色（非分段玻璃时 GlowInput 的系统玻璃方案底色）
  static readonly NORMAL_BG: ResourceColor = ColorTokens.barSurface;
  // —— API 26+ 搜索框规范尺寸 ——
  static readonly SEARCH_HEIGHT: number = 40;
  static readonly SEARCH_RADIUS: number = 18;
}
