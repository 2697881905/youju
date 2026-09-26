// 文字海报 · 设计令牌（唯一事实源）
//
// 设计宪法（改这里之前先读 docs 与 .workbuddy/memory）：
//  C1 字号最多 3 级：主视觉 / 小标签 / 落款
//  C2 层级不倒挂：相邻两级差 ≥ 1.25 倍（104 / 34 / 26 → 3.06× / 1.31×）
//  C3 负空间守卫：文字不越出画布 15% 边距（1080×15%=162 / 1440×15%=216）
//  C4 配色克制度：每款 ≤ 3 色（底 / 墨 / 强调），强调色面积 < 3%
//  C5 零/非物质：每款只允许 1 个材质记忆点；禁渐变、禁纹理、禁模糊阴影、禁旋转
//  C6 缩略图守则：主视觉 ≥ 72px（信息流缩到 330px 宽后 ≥ 22px）
//  C7 细节不承重：抹掉所有细线/微标签后，块面关系与层级仍成立
//
// 结构约定：interface 全部扁平（不用嵌套对象字面量），ArkTS 严格模式下最稳。
export const POSTER_WIDTH: number = 1080;
export const POSTER_HEIGHT: number = 1440;
export const TEXT_POSTER_ASPECT_RATIO: number = POSTER_WIDTH / POSTER_HEIGHT;

// 15% 安全边距（C3）
export const POSTER_SAFE_X: number = Math.round(POSTER_WIDTH * 0.15);
export const POSTER_SAFE_Y: number = Math.round(POSTER_HEIGHT * 0.15);

// 落款：唯一品牌锚点，固定位置固定尺寸，永不放大（C1/C2）
export const POSTER_FOOT_TEXT: string = '有据';
export const POSTER_FOOT_SIZE: number = 26;
export const POSTER_FOOT_BASELINE: number = POSTER_HEIGHT - POSTER_SAFE_Y;

// 小标签：只用于「居中短句档」，排 title
export const POSTER_LABEL_SIZE: number = 34;
export const POSTER_LABEL_BASELINE_OFFSET: number = 4;
export const POSTER_LABEL_RESERVE: number = POSTER_LABEL_SIZE + 34;

// 段间距 = lineHeight × 该比例（仅左对齐的长文档生效）
export const POSTER_PARA_GAP_RATIO: number = 0.6;

// 截断省略号（弯引号同级：用真正的排版字形，不用 ASCII 三个点）
export const POSTER_ELLIPSIS: string = '…';

// 预览/缩略图的绘制倍率。发布路径恒为 1，保证「预览即发布产物」。
// 缩略图取 0.22（238×317）：再小会让 1px 记忆点细线彻底消失、连块面都糊。
export const POSTER_THUMB_SCALE: number = 0.22;

export type TextPosterStyle = 'film' | 'kraft' | 'sticky' | 'paper';
export type TextPosterTexture = 'film' | 'kraft' | 'sticky' | 'paper';
export type PosterAlign = 'center' | 'left';

export interface TextPosterStyleOption {
  key: TextPosterStyle;
  label: string;
  texture: TextPosterTexture;
  // 选择器 UI 与占位块用（也是缩略图渲染前的兜底色）
  background: string;
  accent: string;
  ink: string;
  backgroundRgb: number[];
  accentRgb: number[];
  inkRgb: number[];
  // 落款透明度：4 款统一「安静」但不低于 3:1 对比度
  footOpacity: number;
  // 文字区（绝对坐标），全部落在 15% 边距内
  boxLeft: number;
  boxRight: number;
  boxTop: number;
  boxBottom: number;
}

export const TEXT_POSTER_STYLES: TextPosterStyleOption[] = [
  {
    key: 'paper', label: '素纸', texture: 'paper',
    background: '#EFE9DC', accent: '#8A6548', ink: '#241D12',
    backgroundRgb: [239, 233, 220], accentRgb: [138, 101, 72], inkRgb: [36, 29, 18],
    footOpacity: 0.55,
    boxLeft: 200, boxRight: 880, boxTop: 300, boxBottom: 1120,
  },
  {
    key: 'film', label: '胶片', texture: 'film',
    background: '#111214', accent: '#C8A96A', ink: '#F2EDE3',
    backgroundRgb: [17, 18, 20], accentRgb: [200, 169, 106], inkRgb: [242, 237, 227],
    footOpacity: 0.5,
    boxLeft: 200, boxRight: 896, boxTop: 320, boxBottom: 1140,
  },
  {
    key: 'kraft', label: '牛皮纸', texture: 'kraft',
    background: '#C7A379', accent: '#5A3C1C', ink: '#2A1C0C',
    backgroundRgb: [199, 163, 121], accentRgb: [90, 60, 28], inkRgb: [42, 28, 12],
    footOpacity: 0.55,
    boxLeft: 184, boxRight: 896, boxTop: 316, boxBottom: 1120,
  },
  {
    key: 'sticky', label: '便利贴', texture: 'sticky',
    // 去拟物化：低饱和暖黄纯色片 + 一条 4px 左侧强调条，不倾斜、无胶带、无折角。
    // 备选色（改成一行即可）：蓝 #D6E2EA / 绿 #D8E4D4 / 粉 #EBD9D6 / 灰 #E2DED4
    background: '#F2E2A8', accent: '#C9A94E', ink: '#2A2410',
    backgroundRgb: [242, 226, 168], accentRgb: [201, 169, 78], inkRgb: [42, 36, 16],
    footOpacity: 0.55,
    boxLeft: 216, boxRight: 896, boxTop: 316, boxBottom: 1108,
  },
];

// 未知值一律回退到「素纸」——它是默认款，也是最保守的版式。
export function resolveTextPosterStyle(value?: string): TextPosterStyleOption {
  for (const style of TEXT_POSTER_STYLES) {
    if (style.key === value) {
      return style;
    }
  }
  return TEXT_POSTER_STYLES[0];
}

export interface PosterTier {
  hero: number;      // 主视觉字号
  lineRatio: number; // 行高 = hero × lineRatio（用比例而非「字号 + 常数」，避免行距随字号跳变）
  align: PosterAlign;
}

// 字号阶梯。全部档位 hero ≥ 72（C6）—— 低于 72 的档位已被刻意移除：
// 长文档宁可截断加 …，也不要把主文字压到缩略图里看不清。
export const POSTER_TIERS: PosterTier[] = [
  { hero: 140, lineRatio: 1.34, align: 'center' },
  { hero: 120, lineRatio: 1.38, align: 'center' },
  { hero: 104, lineRatio: 1.46, align: 'center' },
  { hero: 88, lineRatio: 1.50, align: 'left' },
  { hero: 76, lineRatio: 1.52, align: 'left' },
];

// 分档参照样式：只用于「正文长度 → 档位」的变更检测（缩略图是否需要重绘），
// 不参与真实排版（真实排版按各样式自己的 box 折行）。
export const POSTER_REFERENCE_STYLE: TextPosterStyle = 'paper';

// 判定「正文能否在海报里完整显示」时的最保守参照样式。
// 各样式 box 容量不同（sticky 最小，仅约 48 字），用最小的那个作判据 →
// 只会「多显示一次正文」，绝不会把没排进去的内容藏起来。
export const POSTER_CONSERVATIVE_STYLE: TextPosterStyle = 'sticky';

// 单档在某文字区内能容纳的全角字数（按每个字占 1 个字号的保守估算）
export function posterTierCapacity(boxWidth: number, boxHeight: number, tier: PosterTier): number {
  const perLine: number = Math.max(1, Math.floor(boxWidth / tier.hero));
  const maxLines: number = Math.max(1, Math.floor(boxHeight / (tier.hero * tier.lineRatio)));
  return perLine * maxLines;
}

// 样式的文字区容量（按档位）
export function posterStyleCapacity(style: TextPosterStyleOption, tier: PosterTier): number {
  return posterTierCapacity(style.boxRight - style.boxLeft, style.boxBottom - style.boxTop, tier);
}

// 正文长度（按码点计数，emoji 只算 1）。用代理对检测，不依赖 codePointAt。
export function posterTextLength(text: string): number {
  let i: number = 0;
  let n: number = 0;
  while (i < text.length) {
    const first: number = text.charCodeAt(i);
    i += (first >= 0xD800 && first <= 0xDBFF && i + 1 < text.length) ? 2 : 1;
    n += 1;
  }
  return n;
}

/**
 * 正文长度 → 档位下标。
 * 返回 0..POSTER_TIERS.length-1 表示落在该档；返回 POSTER_TIERS.length 表示
 * 连最小档都装不下（会被截断加 …）。该值只依赖长度，不依赖字体度量，
 * 因此可安全用于 UI 侧的「是否需要重绘缩略图」判断。
 */
export function posterBucketOf(content: string): number {
  const style: TextPosterStyleOption = resolveTextPosterStyle(POSTER_REFERENCE_STYLE);
  const length: number = posterTextLength(content);
  for (let i: number = 0; i < POSTER_TIERS.length; i++) {
    if (length <= posterStyleCapacity(style, POSTER_TIERS[i])) {
      return i;
    }
  }
  return POSTER_TIERS.length;
}
