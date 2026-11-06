// 发布执行器：把「预览页确认发布」的完整链路抽成可复用函数。
// 2026-11-07 结构化发布流改版：审稿弹层（StructuredReviewSheet）确认后直接发布，
// 不再经过独立预览页——预览页与审稿层共用本函数，避免两份发布逻辑漂移。
// 职责：结构化校验 → 登录 → 文字海报/视频处理 → createPost → completePublish。
// 进度与失败提示在本函数内 toast；调用方只按返回值决定路由（成功才 back）。
import { createPost } from '../services/api';
import { ensureLogin } from './auth';
import { publishFlowStore } from './publishFlowStore';
import { PublishDraft } from './publishDraft';
import { safeShowToast } from './toast';
import { UIContext } from '@kit.ArkUI';
import { StructuredDocument } from '../models/types';
import { collectStructuredDocument, structuredDocumentFromLegacy,
  structuredDocumentHasContent } from './structuredDocument';
import { publishGenreMeta } from './publishGenres';
import { withCoverOnlyTextPoster } from './structuredFields';
import { uploadTextPoster } from './poster/posterRender';
import { FALLBACK_VIDEO_ASPECT_RATIO, normalizeVideoAspectRatio } from './video';

const TEXT_POSTER_TIMEOUT: number = 20000;

export interface PublishOutcome {
  ok: boolean;
}

function documentOf(draft: PublishDraft): StructuredDocument {
  return draft.structuredDocument ?? structuredDocumentFromLegacy(draft.structuredData, draft.genre);
}

// 无图纯文字帖：生成文字海报作为信息流封面，带超时兜底（与预览页原实现同源）。
function uploadTextPosterWithTimeout(draft: PublishDraft): Promise<string> {
  return new Promise<string>((resolve: (url: string) => void, reject: (reason: Error) => void): void => {
    let settled: boolean = false;
    let timer: number = 0;
    const finish = (error?: Error, url?: string): void => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timer);
      if (error !== undefined) {
        reject(error);
      } else {
        resolve(url ?? '');
      }
    };
    timer = setTimeout((): void => {
      finish(new Error('文字海报生成超时'));
    }, TEXT_POSTER_TIMEOUT) as number;
    uploadTextPoster(draft.title, draft.content, draft.genre, draft.textPosterStyle)
      .then((url: string): void => { finish(undefined, url); })
      .catch((e: Error): void => { finish(e); });
  });
}

export async function executePublish(draft: PublishDraft, uiContext: UIContext): Promise<PublishOutcome> {
  // 结构化体裁必须至少有一个信息块：空壳结构化帖没有阅读价值（与旧预览页同一道闸）
  if (publishGenreMeta(draft.genre).structured && !structuredDocumentHasContent(documentOf(draft))) {
    safeShowToast(uiContext, { message: '请至少填写一个信息块（结论、清单、步骤或对比）' });
    return { ok: false };
  }
  let loggedIn: boolean = false;
  try {
    const user = await ensureLogin();
    loggedIn = user !== null;
  } catch (e) {
    const message: string = e instanceof Error && e.message.length > 0 ? e.message : '未知错误';
    safeShowToast(uiContext, { message: '登录失败：' + message });
    return { ok: false };
  }
  if (!loggedIn) {
    return { ok: false };
  }
  let images: string[] = draft.images;
  let coverImage: string | undefined = images.length > 0 ? images[0] : undefined;
  const coverOnlyTextPoster: boolean = draft.mode === 'photo' && images.length === 0;
  let videoUrl: string | undefined;
  let videoCover: string | undefined;
  let videoAspectRatio: number | undefined;
  if (draft.videoUrl && draft.videoUrl.length > 0) {
    // 视频模式：不生成文字海报，封面取首帧抓图
    videoUrl = draft.videoUrl;
    videoCover = draft.videoCover;
    videoAspectRatio = normalizeVideoAspectRatio(draft.videoAspectRatio ?? FALLBACK_VIDEO_ASPECT_RATIO);
    images = [];
  } else if (images.length === 0) {
    safeShowToast(uiContext, { message: '正在生成文字海报…' });
    try {
      const posterUrl: string = await uploadTextPosterWithTimeout(draft);
      if (posterUrl.length === 0) {
        throw new Error('文字海报地址为空');
      }
      // 生成的是信息流封面，不是详情媒体
      coverImage = posterUrl;
    } catch (e) {
      const message: string = e instanceof Error && e.message.length > 0 ? e.message : '未知错误';
      safeShowToast(uiContext, { message: '文字海报失败，已按纯文字发布：' + message });
    }
  }
  try {
    await createPost({
      title: draft.title,
      publishMode: draft.mode,
      content: draft.content,
      genre: draft.genre,
      tags: draft.tags,
      structuredData: withCoverOnlyTextPoster(draft.structuredData, coverOnlyTextPoster),
      structuredDocument: collectStructuredDocument(documentOf(draft)),
      mentions: draft.mentions,
      images: images,
      videoUrl: videoUrl,
      videoCover: videoCover,
      videoAspectRatio: videoAspectRatio,
      coverImage: videoCover && videoCover.length > 0 ? videoCover : coverImage,
    });
  } catch (e) {
    const message: string = e instanceof Error && e.message.length > 0 ? e.message : '未知错误';
    safeShowToast(uiContext, { message: '发布失败：' + message });
    return { ok: false };
  }
  publishFlowStore.completePublish();
  safeShowToast(uiContext, { message: '发布成功' });
  return { ok: true };
}
