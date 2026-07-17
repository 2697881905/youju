// 前端数据模型（字段可选，适配后端响应可能缺省）
export type Genre = 'review' | 'pitfall' | 'tutorial' | 'debate';

export interface User {
  id?: number;
  nickname?: string;
  avatar?: string;
  gender?: number;
  followTags?: string[];
}

export interface Tag {
  id?: number;
  name?: string;
  emoji?: string;
  category?: string;
  useCount?: number;
  followCount?: number;
}

// 结构化字段（按体裁不同，字段不同；自由 JSON，前端按已知键渲染）
export interface StructuredData {
  pros?: string;
  cons?: string;
  rating?: number | string;
  targetAudience?: string;
  pitfallExperience?: string;
  lossAmount?: string;
  correctApproach?: string;
  tools?: string;
  steps?: string;
  timeDifficulty?: string;
  planA?: string;
  planB?: string;
}

export interface Post {
  id?: number;
  userId?: number;
  title?: string;
  content?: string;
  coverImage?: string;
  images?: string[];
  genre?: Genre;
  tags?: string[];
  structuredData?: StructuredData;
  upCount?: number;
  bookmarkCount?: number;
  commentCount?: number;
  status?: number;
  createdAt?: string;
  user?: User;
}

export interface Comment {
  id?: number;
  postId?: number;
  userId?: number;
  parentId?: number | null;
  content?: string;
  isFact?: number;
  upCount?: number;
  createdAt?: string;
  user?: User;
}

export interface Pagination {
  page: number;
  limit: number;
  total: number;
}
