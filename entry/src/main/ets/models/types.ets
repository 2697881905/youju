// 前端数据模型（字段可选，适配后端响应可能缺省）
export type Genre = 'review' | 'pitfall' | 'tutorial' | 'debate' | 'share';

export interface User {
  id?: number;
  nickname?: string;
  avatar?: string;
  profileBackground?: string;
  gender?: number;
  bio?: string;
  followTags?: string[];
  isAdmin?: boolean;
  status?: number; // 账号状态（0=封禁）；仅管理侧接口（待审列表等）返回，用于显示「已封禁」/解封
  deleted?: boolean; // 已注销（后端软删匿名化标记）
  privacyPolicyVersion?: string; // 已同意的隐私政策版本（服务端留存）
  privacyAgreedAt?: string; // 同意时间（ISO 字符串）
  privacyRequired?: boolean; // 当前版本高于已同意版本，需重新弹窗
}

export interface Tag {
  id?: number;
  name?: string;
  emoji?: string;
  category?: string;
  useCount?: number;
  followCount?: number;
  // 星图 Live 三期：一句话简介（服务端新增列，历史数据为 null）与星等（近14天衰减热度）
  description?: string | null;
  activeScore?: number;
  // 同城维（星图子模式「降落地球」）：null=全球兴趣圈；有值=挂靠城市 code（如 bj）
  cityCode?: string | null;
  // 创建者 id：null=预置/同城圈；有值=用户自建圈（仅创建者可删除空圈）
  creatorId?: number | null;
}

// 结构化字段（按体裁不同，字段不同；自由 JSON，前端按已知键渲染）
export interface StructuredData {
  // Image-free photo posts use the generated text poster as a cover only.
  coverOnlyTextPoster?: boolean;
  pros?: string;
  cons?: string;
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

// 结构化帖子 V2：体裁不再决定字段，作者可自由组合并排序通用信息块。
// 字段保持扁平且显式，兼容 ArkTS V1，也便于后端对每一种块做严格校验。
// V3 在其上追加证据链与数值类型（下方三个可选槽位），V2 形态照常有效。
export type StructuredBlockType = 'metric' | 'insight' | 'list' | 'steps' | 'compare';
export type StructuredDocumentTheme = 'editorial' | 'warm' | 'cool';

// 客户端提交用的协议版本。后端接受 {2,3}（见 backend/src/utils/structuredDocument.ts），
// 因此老客户端发的 V2 与新客户端发的 V3 可以并存，部署顺序是后端先行。
export const STRUCTURED_SCHEMA_VERSION: number = 3;

// V3 证据链：每个信息块可挂若干条依据，兑现「有据」这个名字——结论旁边摆得下出处。
// image 走本系统上传体系（后端按帖图同一条媒体白名单校验，外链会被拒）；
// source 存出处文字或 http(s) 链接，只作为文本展示，不会被任何人自动加载。
export type StructuredEvidenceType = 'image' | 'source';

export interface StructuredEvidence {
  type: StructuredEvidenceType;
  // image：cos:// 或 /uploads/ 引用；source：出处文本或链接。
  ref: string;
  // 一句话说明这条证据证明了什么，如「实测续航 7h12m」
  note: string;
}

// V3 数值类型：让数字块从「一串自由文本」变成可比较、可排序、可聚合的量。
// 迁移期只有 metric 块声明它，其余块保持缺省（plain / 不下发）。
export type StructuredMetricKind = 'score' | 'amount' | 'duration' | 'percent' | 'count' | 'plain';

// V3 的三个字段一律可选：V2 存量帖子（以及后端历史 Json）根本不带这些键，
// 读出来是 undefined 而不是空值——类型上如实标可选，才会在编译期逼调用方判空，
// 避免出现「改了类型却运行时读 null」那类已经踩过的坑（见 Post.structuredData 注释）。
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
  kind?: StructuredMetricKind | null;
  numberValue?: number | null;
  evidence?: StructuredEvidence[] | null;
}

export interface StructuredDocument {
  schemaVersion: number;
  primaryBlockId: string;
  theme: StructuredDocumentTheme;
  blocks: StructuredBlock[];
}

// 正文 @提及 解析结果（后端入库，前端点击跳转用户主页）
export interface MentionRef {
  name: string;
  userId: number;
}

// 发帖 @提及候选（发帖编辑器选择列表 / GET /v1/search/users 返回项）
export interface MentionCandidate {
  id: number;
  nickname: string;
  avatar?: string | null;
  bio?: string | null;
}

export interface Post {
  id?: number;
  userId?: number;
  title?: string;
  content?: string;
  coverImage?: string;
  videoUrl?: string; // 视频地址（轻量单视频方案，最多一段）
  videoCover?: string; // 视频封面（首帧抓取上传）
  videoAspectRatio?: number; // 视频真实宽/高
  images?: string[];
  genre?: Genre;
  tags?: string[];
  // 结构化内容：后端 JSON 把缺失字段序列化成 null（不是 undefined），故类型必须含 null ——
  // 只写 `?: T` 会让「读属性」看起来安全，运行时却撞 null（分享卡片曾因此整条链路失败）。
  structuredData?: StructuredData | null;
  structuredDocument?: StructuredDocument | null;
  // 正文 @提及 解析结果（后端入库，前端点击跳转用户主页）
  mentions?: MentionRef[];
  upCount?: number;
  bookmarkCount?: number;
  commentCount?: number;
  viewCount?: number; // 详情浏览次数（创作者数据面板基础）
  // —— 社区评分（2026-10-29 替代作者主观推荐指数）——
  // ratingAvg=均星（一位小数，无人打分为 null）；ratingCount=人数；myRating=我的评分（半星×2 整数 2..10，未打为 null）
  ratingAvg?: number | null;
  ratingCount?: number;
  myRating?: number | null;
  hotScore?: number; // 热度综合分（推荐/热榜排序信号，只读展示用）
  // —— 帖子主数字（后端从 metric 块抽出的派生列；没有可比数字时后端给 null）——
  // 跨帖对比表按它排序；后端 JSON 的 null 不等于 undefined，可空性必须写进类型。
  metricValue?: number | null;
  metricKind?: string | null; // score | amount | duration | percent | count | plain
  metricLabel?: string | null; // 在比什么：推荐指数 / 到手价 / 耗时
  metricText?: string | null; // 作者原样的展示串："4.6 分" / "1,299 元"
  // —— 当前登录用户对帖子的互动态（后端按 viewerId 计算返回，纯增量字段）——
  myUp?: boolean; // 我是否点赞
  myBookmark?: boolean; // 我是否收藏
  myVote?: string; // 我的辩论投票选项 'A' | 'B' | ''（后端按 viewerId 计算返回）
  status?: number;
  deletedAt?: string;
  createdAt?: string;
  user?: User;
}

// 每日一帖在普通帖子基础上补充与当前兴趣的命中标签。
export interface DailyPost extends Post {
  matchedTags?: string[];
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
  // 楼中楼：该评论下的直接子回复（后端组装，一级评论携带）
  replies?: Comment[];
  // 该评论显式选择的 @提及 [{name, userId}]：展示态点「@昵称」据此精确跳主页。
  // 可选：后端该列是后来加的，历史评论为 null。
  mentions?: MentionRef[];
}

export interface Pagination {
  page: number;
  limit: number;
  total: number;
}

// ===== 收藏夹（专辑）=====
export interface BookmarkFolderCover {
  postId: number;
  title: string;
  image: string;
  genre: string;
}

export interface BookmarkFolderItem {
  id: number;
  name: string;
  count: number;
  cover: BookmarkFolderCover | null;
}

// ===== 账号绑定 =====
// provider 枚举（与后端 accountBindingService 的 Provider 单一来源对齐）
// ⚠️ v1 单一登录方式：有据只用华为账号（unionID）登录，早期并列的「鸿蒙账号（openId）」已废弃——
//    生产禁用开放 openId 登录，新用户 openId 恒为 null，故列表主账号项由 unionID 合成。
export type Provider = 'huawei' | 'wechat';

// 账号绑定列表项（后端返回已脱敏 externalId）
export interface BindingItem {
  provider: Provider; // 'huawei' | 'wechat'
  externalId: string; // 已脱敏展示串，如 '****1234'
  boundAt: string; // ISO 时间串
  isPrimary: boolean; // true 仅华为账号主账号
  displayName: string; // 中文展示名：'华为账号' / '微信'
  status: 'primary' | 'bound' | 'unbound'; // 主账号 / 已绑定 / 未绑定
}

// 绑定请求体（POST /v1/account/bindings，code 变体：前端传第三方 authorizationCode）
export interface BindAccountBody {
  provider: Provider;
  code: string; // 授权页回调的 authorizationCode
}

// 解绑响应（DELETE /v1/account/bindings/:provider）
export interface UnbindResult {
  provider: Provider;
  unbound: boolean;
}

// ===== 消息通知 =====
// 通知类型（与后端 notificationService 的 NotificationType 单一来源对齐）
export type NotificationType = 'comment' | 'up' | 'bookmark' | 'follow' | 'mention' | 'system';

// 通知列表项（后端 Notification 返回；actor 可能为 null，如系统消息）
export interface NotificationItem {
  id?: number;
  type?: NotificationType;
  actor?: User | null;
  postId?: number | null;
  // 关联评论（@提及通知点开时定位到该评论；其余类型 / 历史数据为 null → 只打开帖子）
  commentId?: number | null;
  content?: string;
  read?: boolean;
  pinned?: boolean; // 置顶（举报受理/审核等系统消息恒在列表最前）
  createdAt?: string;
}

// 未读总数响应（GET /v1/notifications/unread-count）
export interface UnreadCount {
  count: number;
  // 按类型未读分布（六类恒有键，缺省 0）：消息页三类快捷筛选红点的数据源。
  // 旧后端无此字段（可选），缺省时红点退化为不显示。
  byType?: UnreadByType;
}

export interface UnreadByType {
  comment: number;
  up: number;
  bookmark: number;
  follow: number;
  mention: number;
  system: number;
}

// ===== 关注 / 他人主页 =====
// 他人/自己资料（GET /v1/users/:id 返回；isFollowing/isMutual 相对当前登录用户）
export interface UserProfile {
  id: number;
  nickname: string;
  avatar: string | null;
  profileBackground: string | null;
  bio: string | null;
  gender: number | null;
  postCount: number;
  followingCount: number;
  followerCount: number;
  totalLikes: number; // 获赞总数（该用户全部已发布帖的点赞计数之和）
  isFollowing: boolean;
  isMutual: boolean;
  isBlocked?: boolean; // viewer 是否已拉黑该作者（用于他人主页"更多"菜单 toggle 态）
  isDisliked?: boolean; // viewer 是否已"不喜欢"该作者（减少推送 toggle 态）
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
export type ReportTargetType = 'post' | 'comment' | 'user';

// 举报人快照（admin 台账随举报记录返回，仅昵称）
export interface AdminReporter {
  nickname?: string | null;
}

// 举报中心台账项（GET /v1/admin/reports，唯一处置台渲染）
// 后端附带：举报人昵称 + 目标摘要（帖子标题/评论内容/用户昵称）+ 目标内容状态 + 作者信息
export interface AdminReportItem {
  id: number;
  reporterId: number;
  targetType: ReportTargetType;
  targetId: number;
  reason: ReportReason;
  description?: string | null;
  status: 'pending' | 'resolved' | 'dismissed';
  createdAt: string;
  reporter?: AdminReporter | null;
  postTitle?: string | null;
  commentContent?: string | null;
  targetNickname?: string | null;
  targetBanned?: boolean | null;
  targetPostId?: number | null; // 目标所属帖子 id（post 目标=自身；comment 目标=所属帖；user 目标=null）
  // 目标内容当前状态（post/comment 的 status：0 下架 / 1 发布；user 目标 = null）
  targetStatus?: number | null;
  // 内容作者（user 目标 = 自身；post/comment = 内容作者；作者已注销时可能为 null）
  authorId?: number | null;
  authorNickname?: string | null;
  authorAvatar?: string | null;
  authorBanned?: boolean | null;
}

// 处置动作（POST /v1/admin/reports/resolve）：成立并下架 / 驳回举报（并恢复内容）/ 改判恢复
export type ReportAction = 'resolved' | 'dismissed' | 'restore';

// 待处理举报按类型分类计数（GET /v1/admin/reports/summary）
// 举报中心三个板块（帖子/评论/用户）的待处理数；与置顶通知文案同一份口径。
export interface PendingReportSummary {
  total: number;
  post: number;
  comment: number;
  user: number;
}

// ===== 通知偏好 =====
// 通知偏好（对应后端 GET/PUT /v1/me/notification-prefs）
export interface NotificationPrefs {
  comment: boolean;
  up: boolean;
  bookmark: boolean;
  follow: boolean;
  system: boolean;
}

// ===== 拉黑管理 =====
// 拉黑列表项（对应后端 GET /v1/me/blocklist）
export interface BlockUser {
  id: number;
  nickname: string;
  avatar: string | null;
  blockedAt: string;
}

// ===== 隐私设置 =====
// 隐私设置（对应后端 GET/PUT /v1/me/privacy）
export interface PrivacySettingsData {
  postVisibility: string; // 'public' | 'followers' | 'private'
  allowFollow: boolean;
  dmPolicy: string; // 'all' | 'mutual' | 'followers'（谁可给我发私信）
  // 是否接收个性化推荐：关闭后「每日一贴」按热度/时间排序，不再依据浏览与互动记录
  personalizedRecommendation: boolean;
}

// ===== 私信 =====
// 会话中的对端用户（对应后端 Conversation.peer）
export interface DmPeer {
  id: number;
  nickname: string;
  avatar: string | null;
  deleted?: boolean;
}

// 会话列表项（对应后端 Conversation）
export interface Conversation {
  peer: DmPeer;
  lastType: string;
  lastContent: string;
  lastSenderId: number;
  lastAt: string; // ISO
  unreadCount: number;
}

// 单条私信（对应后端 DmMessage）
export interface DmMessage {
  id: number;
  senderId: number;
  receiverId: number;
  type: string; // text | image | video | share
  content: string; // text 为文本；image/video 为媒体 viewUrl；share 为 DmSharePayload 的 JSON 串
  read: boolean;
  recalled?: boolean; // 已撤回（双方均不可见正文，前端展示占位文案）
  // 该条私信显式选择的 @提及 [{name, userId}]：展示态点「@昵称」据此精确跳主页。
  // 可选：后端该列是后来加的，历史消息为 null。
  mentions?: MentionRef[];
  createdAt: string; // ISO
}

// 分享到私信的帖子摘要负载（序列化后存入 DmMessage.content，type='share'）
export interface DmSharePayload {
  postId: number; // 原帖 id（点击跳转详情用）
  title: string; // 帖子标题
  summary: string; // 正文片段（前端截断）
  coverImage: string; // 封面/首图展示 URL（已 resolveDisplayImageUrl）；空串表示无封面
  authorName: string; // 原帖作者昵称
  authorId: number; // 原帖作者 id
  authorAvatar?: string; // 原帖作者头像；旧分享消息缺省时使用中性占位圆
  categoryLabel?: string; // 分享卡顶部的栏目/体裁标签
  commentCount?: number; // 分享时快照的评论数
  upCount?: number; // 分享时快照的点赞数
}

// ===== 数据导出 =====
// 导出数据（对应后端 GET /v1/me/export），结构由后端定义
export interface UserExportData {
  exportedAt: string;
  profile: Record<string, Object>;
  postsCount: number;
  commentsCount: number;
  bookmarksCount: number;
  followingsCount: number;
  followersCount: number;
}

// ===== 辩论投票 =====
// 辩论投票结果（对应后端 POST /v1/posts/:id/vote）
export interface DebateVoteResult {
  voted: boolean;
  choice: string;  // 'A' | 'B'
  planAVotes: number;
  planBVotes: number;
}
