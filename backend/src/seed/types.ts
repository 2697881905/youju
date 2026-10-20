// 冷启动内容库的类型定义。
//
// 内容库是 JSON，写入前要过 schema.ts 的强校验；这里的类型只描述「作者怎么写」，
// 不描述「库里最终长什么样」——块 id、document.theme、metric 四列、createdAt 都是
// 写入阶段由 derive/planner 生成的派生值，作者不需要也不应该手写。
//
// 结构化块协议在这里另立一份：后端没有对应的 TS 类型（协议只在 ArkTS 侧定义），
// 从 entry/ 里 import 会把前端源码拖进 Node 构建，所以只照抄字段名与取值。

export type Genre = 'review' | 'pitfall' | 'tutorial' | 'debate' | 'share';

export type StructuredBlockType = 'metric' | 'insight' | 'list' | 'steps' | 'compare';

export type StructuredMetricKind = 'score' | 'amount' | 'duration' | 'percent' | 'count' | 'plain';

export interface StructuredBlock {
  id: string;
  type: StructuredBlockType;
  title: string;
  value: string;
  unit: string;
  helper: string;
  items: string[];
  leftLabel: string;
  leftValue: string;
  rightLabel: string;
  rightValue: string;
  kind?: StructuredMetricKind;
  numberValue?: number;
}

export interface StructuredDocument {
  schemaVersion: number;
  primaryBlockId: string;
  theme: 'editorial' | 'warm' | 'cool';
  blocks: StructuredBlock[];
}

export type SeedTier = 'hero' | 'solid' | 'normal' | 'tail';

export interface SeedAuthorRecord {
  slug: string;
  nickname: string;
  bio: string;
  gender: 1 | 2;
  /** 常驻圈子（圈子中文名），影响帖子的默认归属与评论串门范围 */
  circles: string[];
  /** 头像底色，十六进制；渲染脚本按它生成纯色底单字头像 */
  avatarColor: string;
}

export interface SeedAuthorsFile {
  schemaVersion: number;
  authors: SeedAuthorRecord[];
}

/** 各体裁的结构化字段，键名与后端 validateStructuredData 的白名单一致 */
export interface SeedStructuredFields {
  pros?: string;
  cons?: string;
  rating?: number;
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

/**
 * 作者手写的信息块。id 由 derive 按「帖子 id + 序号」生成，
 * 因此这里没有 id 字段——写死 id 会让「改一个块顺序」变成改两处。
 */
export interface SeedBlockSpec {
  type: StructuredBlockType;
  title: string;
  value?: string;
  unit?: string;
  helper?: string;
  items?: string[];
  leftLabel?: string;
  leftValue?: string;
  rightLabel?: string;
  rightValue?: string;
  kind?: StructuredMetricKind;
  numberValue?: number;
}

export interface SeedCommentSpec {
  author: string;
  text: string;
  isFact?: 0 | 1;
  upCount?: number;
  /** 相对发帖时间的分钟偏移，必须小于帖子年龄 */
  offsetMinutes?: number;
  /** 指向本数组里更早的评论下标，落库时转成 parentId */
  replyToIndex?: number;
}

export interface SeedPostRecord {
  id: string;
  author: string;
  genre: Genre;
  title: string;
  content: string;
  tags: string[];
  tier: SeedTier;
  /** 距导入时刻的小时数，planner 会按档位做区间校验 */
  ageHours: number;
  posterStyle?: 'paper' | 'film' | 'kraft' | 'sticky';
  /** 海报上正文摘要的第一句，留空则由渲染脚本从 content 里截 */
  posterLine?: string;
  /** 一句话结论，喂给详情页的「结论」块；非 share 体裁必填 */
  insight?: string;
  structured?: SeedStructuredFields;
  blocks?: SeedBlockSpec[];
  primaryBlockIndex?: number;
  theme?: 'editorial' | 'warm' | 'cool';
  /** 辩论票数，仅 debate 体裁使用 */
  planAVotes?: number;
  planBVotes?: number;
  comments?: SeedCommentSpec[];
  /** 只用于查重与人工评审，不落库 */
  _topic?: string;
}

export interface SeedCircleFile {
  schemaVersion: number;
  circle: string;
  posts: SeedPostRecord[];
}

export interface SeedIndexEntry {
  slug: string;
  name: string;
  expectedPosts: number;
  file: string;
}

export interface SeedIndexFile {
  schemaVersion: number;
  circles: SeedIndexEntry[];
}

export interface LoadedContent {
  authors: SeedAuthorRecord[];
  posts: SeedPostRecord[];
  /** 帖子 id → 所属圈子中文名 */
  circleOfPost: Map<string, string>;
}
