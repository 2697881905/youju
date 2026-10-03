// 搜索页「一镜到底」发起器：首页搜索按钮 → 搜索面板（Navigation 壳）。
// 与 openPostDetailViaNav 同范式：量按钮屏幕帧 → push SearchPanel
// （自定义转场整页从按钮帧缩放展开）；未就绪 / 量不到帧 → 兜底 router 整页
// （无飞行），**点击绝不吞掉**。
// 与 PostDetail 的差异：无截图层——搜索面板标题栏（搜索框）是同步内容，
// 展开首帧即真实页面，不存在「异步数据未就绪需截图顶帧」的问题。

import { cardRectOf, getMainNavStack, CardRect } from '../navigationTransition';
import { LongTakeParams } from './longTakeAnimationProperties';
import { RadiusTokens } from '../../design/tokens/radius';

// 首页搜索入口的组件 id（Index.ets 首页标题栏的图标按钮），供量帧定位
export const SEARCH_ENTRY_ID: string = 'homeSearchEntry';

export function openSearchPanelViaNav(ui: UIContext): void {
  const nav: NavPathStack | null = getMainNavStack();
  if (nav === null) {
    // Navigation 未就绪：兜底 router 独立搜索页（无一镜到底），点击绝不吞掉
    ui.getRouter().pushUrl({ url: 'pages/SearchPanelPage' });
    return;
  }
  const p: LongTakeParams = new LongTakeParams();
  p.cardId = SEARCH_ENTRY_ID;
  const rect: CardRect | null = cardRectOf(SEARCH_ENTRY_ID);
  if (rect !== null) {
    p.cardRect = rect;
    // 飞行起点圆角 = 搜索按钮自身的圆角（展开途中过渡到页面圆角，收尾归 0）
    p.cardRadius = RadiusTokens.lg;
  }
  // 量不到按钮帧：没有起点就没有飞行，但点击绝不能被吞掉——直接推
  // （目的地将按 geometryValid=false 落终态，页面直接呈现，功能完整）
  nav.pushPathByName('SearchPanel', p);
}
