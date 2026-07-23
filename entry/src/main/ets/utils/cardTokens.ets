// 卡片设计令牌：统一全应用所有「卡片」场景的圆角 / 内边距 / 阴影 / 网格间距
// 用途：消除 PostCard、圈子卡片等多处重复且不一致的样式数值，确保视觉一致
// 接入页面：PostCard、CircleTab、HomeTab、ProfilePage、SearchResultPage

// 卡片圆角（Apple 风格大圆角）
export const CARD_RADIUS: number = 16;

// 卡片内边距（比旧值 14 略收紧，更紧凑但保留呼吸感）
export const CARD_PADDING: number = 12;

// 卡片内封面图圆角（内嵌于卡片，比卡片圆角略小）
export const CARD_COVER_RADIUS: number = 10;

// 卡片统一投影：浅色模式淡灰、深色模式同样适用（颜色含透明度，深浅模式自动过渡）
export const CARD_SHADOW: ShadowOptions = {
  radius: 12,
  color: '#0D000000',
  offsetY: 2
};

// 网格列间距 / 行间距（再收紧一档，让卡片排布更紧凑）
export const GRID_GAP: number = 6;

// 网格外边距（再收紧一档）
export const GRID_PADDING: number = 8;

// 卡片内部元素纵向间距（标题↔作者↔互动行的间距，比旧值 10 收紧）
export const CARD_INNER_GAP: number = 8;
