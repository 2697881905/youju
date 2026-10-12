import { Genre } from '../models/types';
// 仅取类型：避免 publishGenres 运行时依赖 SegmentedControl（发布页与预览页都静态依赖本文件）。
import type { SegmentedItem } from '../design/components/SegmentedControl';

export interface PublishGenreItem {
  key: Genre;
  label: string;
  hint: string;
  iconRes: Resource;
  // 发布页是否提供「结构化信息流」编辑区。
  // 分享是轻量图文（经验见闻与心得），不承载结构化信息块 —— 选了分享就不该出现该区块；
  // 其余四个体裁（测评/避坑/教程/辩论）都以结构化信息为表达骨架，保持开启。
  structured: boolean;
}

export const PUBLISH_GENRES: PublishGenreItem[] = [
  { key: 'review', label: '测评', hint: '优缺点与推荐指数', iconRes: $r('app.media.genre_review'), structured: true },
  { key: 'pitfall', label: '避坑', hint: '踩坑经历与正确做法', iconRes: $r('app.media.genre_pitfall'), structured: true },
  { key: 'tutorial', label: '教程', hint: '工具与步骤拆解', iconRes: $r('app.media.genre_tutorial'), structured: true },
  { key: 'debate', label: '辩论', hint: 'A/B 方案投票', iconRes: $r('app.media.genre_debate'), structured: true },
  { key: 'share', label: '分享', hint: '经验见闻与心得', iconRes: $r('app.media.genre_share'), structured: false },
];

// 体裁 → 分段栏数据源：三个发布页共用同一份顺序，选中的就是列表里看到的那一个。
export const PUBLISH_GENRE_SEGMENTS: SegmentedItem[] = PUBLISH_GENRES.map(
  (item: PublishGenreItem): SegmentedItem => {
    return { key: item.key, label: item.label };
  });

export function publishGenreMeta(genre: Genre): PublishGenreItem {
  for (const item of PUBLISH_GENRES) {
    if (item.key === genre) {
      return item;
    }
  }
  return PUBLISH_GENRES[0];
}
