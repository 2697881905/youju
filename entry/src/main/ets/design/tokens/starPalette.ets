// 星图双调色板（星图 Live 四期）：星环画布与圈子宇宙共用的深浅两套「星空」色板。
// 深色=「墨空星图」：夜空底、弧线微光、行星光晕；浅色=「纸上星图」：白底、墨细线轨道。
// 同一结构换色板，两套观感对应原型评审页的深浅双方案。

// 背景星尘单元（百分比坐标铺满全屏画布）。
export interface StarDot {
  x: number;
  y: number;
  size: number;
  // 闪烁分组：0=不闪（锚定星） 1=A 组快闪 2=B 组慢闪
  tw: number;
}

export interface StarPalette {
  ink: string;        // 星名文字
  ring: string;       // 轨道线
  glow: string;       // 泛光核心
  halo: string;       // 呼吸光环
  star: string;       // 背景星点
  discFill: string;   // 行星盘底
  discStroke: string; // 行星盘描边
  gold: string;       // 成员金环
  icon: string;       // 图标/涟漪/选中强调
  seedBlue: string;   // 星子（普通新帖）
  seedGold: string;   // 星子（每日一帖级）
  badge: string;      // 未读角标底
  bgTop: string;      // 画布渐变顶
  bgMid: string;
  bgBottom: string;
}

// M3 色板收敛：去掉海军蓝/霓虹蓝，回到「墨空 / 纸上」两套暖中性色。
// 语义固定：金=已加入，红=未读/新帖，蓝=可交互/选中，灰=冷圈。
export const DARK_PALETTE: StarPalette = {
  ink: '#ECE6DA', ring: '#24ECE6DA', glow: '#26D9A441', halo: '#33D9A441',
  star: '#B8AFA0', discFill: '#17171A', discStroke: '#2EECE6DA', gold: '#D9A441',
  icon: '#8FAFC9', seedBlue: '#C86B5A', seedGold: '#D9A441', badge: '#B4453A',
  bgTop: '#111110', bgMid: '#151513', bgBottom: '#1B1A17',
};

export const PAPER_PALETTE: StarPalette = {
  ink: '#1F1C18', ring: '#3D1F1C18', glow: '#1FA06400', halo: '#26A06400',
  star: '#9A8E7E', discFill: '#FFFDF9', discStroke: '#D9D0C0', gold: '#A06400',
  icon: '#4F6B85', seedBlue: '#B4453A', seedGold: '#A06400', badge: '#B4453A',
  bgTop: '#FBF8F2', bgMid: '#F7F2E9', bgBottom: '#F2ECDF',
};

// 取当前主题色板（组件内 pal() 的共享实现）。
export function starPalette(dark: boolean): StarPalette {
  return dark ? DARK_PALETTE : PAPER_PALETTE;
}

// 背景星尘场（40 颗；tw 分组驱动两档闪烁相位）。星环画布与圈子宇宙共用。
export const STAR_DOTS: StarDot[] = [
  { x: 5, y: 8, size: 2, tw: 1 }, { x: 14, y: 4, size: 1, tw: 0 }, { x: 22, y: 12, size: 2, tw: 2 },
  { x: 31, y: 6, size: 1, tw: 1 }, { x: 43, y: 3, size: 2, tw: 0 }, { x: 55, y: 9, size: 1, tw: 2 },
  { x: 66, y: 5, size: 2, tw: 1 }, { x: 77, y: 11, size: 1, tw: 0 }, { x: 88, y: 6, size: 2, tw: 2 },
  { x: 95, y: 13, size: 1, tw: 1 }, { x: 3, y: 22, size: 1, tw: 2 }, { x: 12, y: 28, size: 2, tw: 0 },
  { x: 26, y: 24, size: 1, tw: 1 }, { x: 37, y: 30, size: 2, tw: 2 }, { x: 49, y: 26, size: 1, tw: 0 },
  { x: 61, y: 31, size: 2, tw: 1 }, { x: 73, y: 25, size: 1, tw: 2 }, { x: 84, y: 29, size: 2, tw: 0 },
  { x: 94, y: 34, size: 1, tw: 1 }, { x: 7, y: 42, size: 2, tw: 2 }, { x: 18, y: 48, size: 1, tw: 0 },
  { x: 30, y: 44, size: 2, tw: 1 }, { x: 44, y: 50, size: 1, tw: 2 }, { x: 57, y: 45, size: 2, tw: 0 },
  { x: 69, y: 51, size: 1, tw: 1 }, { x: 81, y: 46, size: 2, tw: 2 }, { x: 92, y: 52, size: 1, tw: 0 },
  { x: 4, y: 60, size: 2, tw: 1 }, { x: 15, y: 67, size: 1, tw: 2 }, { x: 27, y: 62, size: 2, tw: 0 },
  { x: 40, y: 69, size: 1, tw: 1 }, { x: 53, y: 64, size: 2, tw: 2 }, { x: 65, y: 70, size: 1, tw: 0 },
  { x: 77, y: 65, size: 2, tw: 1 }, { x: 89, y: 71, size: 1, tw: 2 }, { x: 9, y: 80, size: 2, tw: 0 },
  { x: 21, y: 87, size: 1, tw: 1 }, { x: 35, y: 82, size: 2, tw: 2 }, { x: 50, y: 89, size: 1, tw: 0 },
  { x: 64, y: 84, size: 2, tw: 1 }, { x: 78, y: 91, size: 1, tw: 2 }, { x: 91, y: 86, size: 2, tw: 0 },
  // 深空加层：细碎小星填补上半部（标题区）与环带空隙，让底色不只是一层均匀噪点。
  { x: 9, y: 14, size: 1, tw: 2 }, { x: 18, y: 9, size: 1, tw: 1 }, { x: 27, y: 17, size: 1, tw: 0 },
  { x: 36, y: 8, size: 1, tw: 2 }, { x: 47, y: 14, size: 1, tw: 1 }, { x: 58, y: 18, size: 1, tw: 0 },
  { x: 68, y: 12, size: 1, tw: 2 }, { x: 79, y: 19, size: 1, tw: 1 }, { x: 90, y: 11, size: 1, tw: 0 },
  { x: 6, y: 33, size: 1, tw: 1 }, { x: 20, y: 35, size: 1, tw: 2 }, { x: 33, y: 38, size: 1, tw: 0 },
  { x: 46, y: 34, size: 1, tw: 1 }, { x: 60, y: 39, size: 1, tw: 2 }, { x: 74, y: 36, size: 1, tw: 0 },
  { x: 86, y: 40, size: 1, tw: 1 }, { x: 96, y: 45, size: 1, tw: 2 },
  { x: 3, y: 52, size: 1, tw: 0 }, { x: 13, y: 55, size: 1, tw: 1 }, { x: 24, y: 58, size: 1, tw: 2 },
  { x: 38, y: 54, size: 1, tw: 0 }, { x: 52, y: 59, size: 1, tw: 1 }, { x: 66, y: 56, size: 1, tw: 2 },
  { x: 80, y: 60, size: 1, tw: 0 },
];
