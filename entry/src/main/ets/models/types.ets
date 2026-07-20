// 前端数据模型（字段可选，适配后端响应可能缺省）
export type Genre = 'review' | 'pitfall' | 'tutorial' | 'debate';

export interface User {
  id?: number;
  nickname?: string;
  avatar?: string;
  gender?: number;
  bio?: string;
  followTags?: string[];
  isAdmin?: boolean;
  deleted?: boolean; // 已注销（后端软删匿名化标记）
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
  // —— 当前登录用户对帖子的互动态（后端按 viewerId 计算返回，纯增量字段）——
  myUp?: boolean; // 我是否点赞
  myBookmark?: boolean; // 我是否收藏
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

// ===== 账号绑定 =====
// provider 枚举（与后端 accountBindingService 的 Provider 单一来源对齐）
export type Provider = 'harmony' | 'huawei' | 'wechat';

// 账号绑定列表项（后端返回已脱敏 externalId）
export interface BindingItem {
  provider: Provider; // 'harmony' | 'huawei' | 'wechat'
  externalId: string; // 已脱敏展示串，如 '****1234'
  boundAt: string; // ISO 时间串
  isPrimary: boolean; // true 仅鸿蒙主账号
  displayName: string; // 中文展示名：'鸿蒙账号' / '华为账号' / '微信'
  status: 'primary' | 'bound' | 'unbound'; // 主账号 / 已绑定 / 未绑定
}

// 绑定请求体（POST /v1/account/bindings，code 变体：前端传华为 authorizationCode）
export interface BindAccountBody {
  provider: Provider;
  code: string; // 华为授权页回调的 authorizationCode
}

// 解绑响应（DELETE /v1/account/bindings/:provider）
export interface UnbindResult {
  provider: Provider;
  unbound: boolean;
}

// ===== 消息通知 =====
// 通知类型（与后端 notificationService 的 NotificationType 单一来源对齐）
export type NotificationType = 'comment' | 'up' | 'bookmark' | 'follow' | 'system';

// 通知列表项（后端 Notification 返回；actor 可能为 null，如系统消息）
export interface NotificationItem {
  id?: number;
  type?: NotificationType;
  actor?: User | null;
  postId?: number | null;
  content?: string;
  read?: boolean;
  createdAt?: string;
}

// 未读总数响应（GET /v1/notifications/unread-count）
export interface UnreadCount {
  count: number;
}

// ===== 关注 / 他人主页 =====
// 他人/自己资料（GET /v1/users/:id 返回；isFollowing/isMutual 相对当前登录用户）
export interface UserProfile {
  id: number;
  nickname: string;
  avatar: string | null;
  bio: string | null;
  gender: number | null;
  postCount: number;
  followingCount: number;
  followerCount: number;
  isFollowing: boolean;
  isMutual: boolean;
  deleted?: boolean; // 已注销（后端软删匿名化标记）
}

// 关注/粉丝列表项（GET /v1/users/:id/following|followers 返回）
export interface FollowUser {
  id?: number;
  nickname: string;
  avatar: string | null;
  bio: string | null;
  isFollowing: boolean;
  deleted?: boolean; // 已注销（后端软删匿名化标记）
}

// 关注/粉丝列表响应
export interface FollowListResult {
  list: FollowUser[];
  pagination: Pagination;
}

// ===== 内容审核 & 举报系统 =====
// 举报理由枚举（与后端 ReportReason 单一来源对齐）
export type ReportReason = 'political' | 'pornographic' | 'personal_attack' |
  'gender_war' | 'advertisement' | 'spam' | 'other';

// 举报请求体（POST /v1/posts/:id/report、POST /v1/comments/:id/report）
export interface ReportBody {
  reason: ReportReason;
  description?: string;
}

// 举报目标类型
export type ReportTargetType = 'post' | 'comment';

// 举报人快照（GET /v1/admin/posts/pending 随 reports 返回）
export interface ReportReporter {
  nickname?: string;
}

// 举报记录项（GET /v1/admin/posts/pending 随待审帖子返回；reporter 昵称来自 include）
export interface ReportItem {
  id?: number;
  reporterId?: number;
  targetType?: ReportTargetType;
  targetId?: number;
  reason?: ReportReason;
  description?: string;
  status?: string;
  createdAt?: string;
  reporter?: ReportReporter;
}

// 待审帖子（继承 Post + 携带举报列表，供审核台决策）
export interface PendingPost extends Post {
  reports: ReportItem[];
  reportCount?: number;
}

// 审核动作
export type ModerateAction = 'approve' | 'reject';
