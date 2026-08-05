import { Genre, StructuredData } from '../models/types';

export interface PublishDraft {
  title: string;
  content: string;
  genre: Genre;
  tags: string[];
  structuredData: StructuredData;
  images: string[];
  videoUrl?: string;   // 视频地址（轻量单视频，与 images 互斥）
  videoCover?: string; // 视频封面（首帧抓取上传）
  textPosterStyle?: string;
}

export function clonePublishDraft(draft: PublishDraft): PublishDraft {
  return {
    title: draft.title,
    content: draft.content,
    genre: draft.genre,
    tags: [...draft.tags],
    structuredData: draft.structuredData,
    images: [...draft.images],
    videoUrl: draft.videoUrl,
    videoCover: draft.videoCover,
    textPosterStyle: draft.textPosterStyle,
  };
}
