// 帖子详情「一镜到底」发起器：首页信息流 / 每日一帖 / 「我的」四分段共用。
// 从 HomeTab.openDetailViaNav 抽取（2026-09-29，「我的」四分段接入时共享化），行为逐字保留：
// Navigation 就绪 → 量卡片屏幕帧 + 截飞行物图 → push PostDetail（自定义转场整页缩放展开）；
// 未就绪 / 量不到帧 → 兜底 router 整页（无飞行），**点击绝不吞掉**。

import { Post } from '../../models/types';
import { PostDetailIntent, openPostDetail } from '../nav';
import { cardRectOf, getMainNavStack, PostDetailNavParams, CardRect } from '../navigationTransition';
import { LongTakeParams } from './longTakeAnimationProperties';
import { resolveDisplayImageUrl } from '../../services/api';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';

// 帖子卡面展示图口径：与 PostCardMedia 展示一致（视频→视频封面||封面；图片→封面），
// 过 resolveDisplayImageUrl 归一化（cos:// → 展示直链）。
// 每日一帖卡堆的 DailyPost 类型不走这里（HomeTab.dailyDeckCover 自留，字段口径不同）。
export function postDetailCoverOf(p: Post): string {
  const coverRaw: string = typeof p.coverImage === 'string' ? p.coverImage : '';
  const vCover: string = typeof p.videoCover === 'string' ? p.videoCover : '';
  const vUrl: string = typeof p.videoUrl === 'string' ? p.videoUrl : '';
  const raw: string = vUrl.length > 0 ? (vCover.length > 0 ? vCover : coverRaw) : coverRaw;
  return raw.length > 0 ? resolveDisplayImageUrl(raw) : '';
}

// aspect = 阅读比例（转场结束后媒体框的展示比例）；flightAspect = 飞行目标框比例（= 卡面比例）。
// 两者通常相同；卡堆卡面 4:3、阅读 3:4，必须分开传（同一个值无法两全）。
export function buildPostDetailIntent(cover: string, p: Post, aspect: number, flightAspect: number): PostDetailIntent {
  return {
    cover: cover,
    title: p.title ?? '',
    genre: p.genre ?? '',
    tags: p.tags ?? [],
    authorName: p.user?.nickname ?? '',
    authorAvatar: p.user?.avatar ?? '',
    createdAt: p.createdAt ?? '',
    aspect: aspect,
    flightAspect: flightAspect,
    isVideo: ((p.videoUrl ?? '') as string).length > 0,
  };
}

// 卡片 → 详情：走 Navigation 的 PostDetail 目的地以启用自定义转场（一镜到底）；
// 变形由 PostDetailDestination 自身完成（官方范式：整页从飞行物帧缩放展开），
// 本处只负责「截飞行物图 + 量它的屏幕帧」并随参数传出。
// Navigation 未就绪时兜底走老路由整页（无飞行）。
// cardId：用于截图与测量起点的组件 id —— **调用方所在列表面的媒体块 id**，各列表面
// 必须用自己的前缀（首页 cardMedia-{id} / 卡堆 deckCardMedia-{id} / 「我的」profileMedia{seg}-{id}）：
// getRectangleById 全窗口按 id 查询不区分页面，跨面同 id 会量到别的面的节点
// （2026-09-29 实测：海报从屏幕外/错误起点起飞）。只飞媒体块、不飞整卡。
// cardRadius：飞行物自身的圆角（vp）—— 截图的起始圆角，飞行中过渡到详情媒体圆角。
// flightAspect：飞行目标框比例（卡面比例）；aspect 只作阅读比例（两者同源时传同一个值）。
export function openPostDetailViaNav(ui: UIContext, post: Post, aspect: number, cover: string,
  cardId: string, cardRadius: number, flightAspect: number): void {
  if (post.id === undefined) {
    return;
  }
  const nav: NavPathStack | null = getMainNavStack();
  if (nav === null) {
    openPostDetail(post.id.toString(), cover.length > 0 ? buildPostDetailIntent(cover, post, aspect, flightAspect) : undefined);
    ui.getRouter().pushUrl({ url: 'pages/DetailPage' });
    return;
  }
  const p: PostDetailNavParams = new PostDetailNavParams();
  p.postId = post.id;
  p.intent = cover.length > 0 ? buildPostDetailIntent(cover, post, aspect, flightAspect) : null;
  const rect: CardRect | null = cardRectOf(cardId);
  // 官方做法：先截飞行物图顶住首帧，再 push；截图失败则退化为纯布局变形（转场照走）
  const take: LongTakeParams = new LongTakeParams();
  take.cardId = cardId;
  take.cardRadius = cardRadius;
  if (rect !== null) {
    take.cardRect = rect;
  }
  p.longTake = take;
  // 量不到卡片帧：没有起点就没有飞行，但**点击绝不能被吞掉** —— 立刻推进去
  if (rect === null) {
    nav.pushPathByName('PostDetail', p);
    return;
  }
  // 截图是异步的，且 id 不存在时回调不保证触发（踩过：卡堆 id 少拼 post.id，
  // 结果 push 永远等不到回调，表现为「点了没反应」）。因此加一次性放行 + 超时兜底，
  // 保证任何异常路径下都会完成跳转（最差只是没有截图、退化为纯布局变形）。
  let pushed: boolean = false;
  const pushOnce: () => void = (): void => {
    if (pushed) {
      return;
    }
    pushed = true;
    nav.pushPathByName('PostDetail', p);
  };
  setTimeout(pushOnce, 100);
  try {
    // UIContext 形态（@since 12）：全局 componentSnapshot.get 自 API 18 起已废弃，
    // @useinstead 即此形态；官方示例同样走 UIContext。
    ui.getComponentSnapshot().get(cardId,
      (err: BusinessError, pixelMap: image.PixelMap): void => {
        if (!err && pixelMap !== undefined) {
          take.snapshot = pixelMap;
        }
        pushOnce();
      });
  } catch (e) {
    pushOnce();
  }
}
