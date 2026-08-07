import { Genre } from '../models/types';

export interface PublishGenreItem {
  key: Genre;
  label: string;
  hint: string;
  iconRes: Resource;
}

export const PUBLISH_GENRES: PublishGenreItem[] = [
  { key: 'review', label: '测评', hint: '优缺点与推荐指数', iconRes: $r('app.media.genre_review') },
  { key: 'pitfall', label: '避坑', hint: '踩坑经历与正确做法', iconRes: $r('app.media.genre_pitfall') },
  { key: 'tutorial', label: '教程', hint: '工具与步骤拆解', iconRes: $r('app.media.genre_tutorial') },
  { key: 'debate', label: '辩论', hint: 'A/B 方案投票', iconRes: $r('app.media.genre_debate') },
  { key: 'share', label: '分享', hint: '经验见闻与心得', iconRes: $r('app.media.genre_share') },
];

export function publishGenreMeta(genre: Genre): PublishGenreItem {
  for (const item of PUBLISH_GENRES) {
    if (item.key === genre) {
      return item;
    }
  }
  return PUBLISH_GENRES[0];
}
