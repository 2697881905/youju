import { Genre, StructuredData } from '../models/types';

export type PublishDraftMode = 'photo' | 'text' | 'video';

export interface PublishDraft {
  // Preserve the chosen entry so an image-free photo post remains a photo post.
  mode?: PublishDraftMode;
  title: string;
  content: string;
  genre: Genre;
  tags: string[];
  structuredData: StructuredData;
  images: string[];
  videoUrl?: string;   // 视频地址（轻量单视频，与 images 互斥）
  videoCover?: string; // 视频封面（首帧抓取上传）
  videoAspectRatio?: number; // 视频真实宽/高，供预览与详情按原比例展示
  textPosterStyle?: string;
}

export function clonePublishDraft(draft: PublishDraft): PublishDraft {
  return {
    mode: draft.mode,
    title: draft.title,
    content: draft.content,
    genre: draft.genre,
    tags: [...draft.tags],
    structuredData: draft.structuredData,
    images: [...draft.images],
    videoUrl: draft.videoUrl,
    videoCover: draft.videoCover,
    videoAspectRatio: draft.videoAspectRatio,
    textPosterStyle: draft.textPosterStyle,
  };
}
