import { http } from '@kit.NetworkKit';
import { Post, Comment, Tag, User, Pagination, Genre, Provider, BindingItem, BindAccountBody, UnbindResult, NotificationItem, UnreadCount, UserProfile, FollowUser, FollowListResult, ReportBody, PendingPost, ModerateAction, NotificationPrefs, BlockUser, PrivacySettingsData, UserExportData, DebateVoteResult, Conversation, DmMessage } from '../models/types';

// 本地后端地址（按运行环境替换）：
// - 模拟器/真机本地开发：用 hdc 反向端口转发，连 127.0.0.1:3000 即可，无需关心电脑 IP（IP 变了也不用改这里）
//   设置命令：hdc rport tcp:3000 tcp:3000  （模拟器每次重启后重跑一次即可）
// - 真机/同局域网直连：'http://<你电脑局域网IP>:3000'
// - 上架后：'https://api.bigbluebook.com'
export const BASE_URL = 'http://127.0.0.1:3000';

// token 由 utils/auth.ts 统一管理（PersistentStorage 持久化），request 直接从 AppStorage 读取。

export interface ApiResult<T> {
  code: number;
  data: T;
  message: string;
}

// 判断错误是否为网络连接类失败（后端未启动 / hdc rport 未建立 / 超时等）
function isNetworkConnectionError(message: string): boolean {
  const m: string = message.toLowerCase();
  return m.includes('connect') || m.includes('refused') || m.includes('econnrefused') ||
    m.includes('unreachable') || m.includes('timed out') || m.includes('network');
}

async function request<T>(method: http.RequestMethod, path: string, body?: Object): Promise<T> {
  const url = BASE_URL + path;
  const req = http.createHttp();
  const token: string = (AppStorage.get<string>('authToken') ?? '') as string;
  const header: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) {
    header['Authorization'] = 'Bearer ' + token;
  }
  try {
    const resp = await req.request(url, {
      method,
      header,
      extraData: body ? JSON.stringify(body) : undefined,
      expectDataType: http.HttpDataType.OBJECT,
      connectTimeout: 10000,
      readTimeout: 10000,
    });
    // 先尝试解析 body 中的业务错误（后端 400/409/404 等返回 {code, message}）
    // 让后端业务错误 message 透传到前端 catch 块（如"内容含敏感词"、"你已举报过该内容"）
    const result = resp.result as ApiResult<T>;
    if (result && typeof result.code === 'number') {
      if (result.code !== 0) {
        throw new Error(result.message || '请求失败');
      }
      return result.data;
    }
    // fallback：非 JSON 响应或无 code 字段
    if (resp.responseCode !== 200) {
      throw new Error('HTTP ' + resp.responseCode);
    }
    throw new Error('请求失败');
  } catch (e) {
    const err: Error = e as Error;
    const rawMsg: string = err.message ? err.message : '请求发生未知错误';
    // 连接失败（ECONNREFUSED 等）给出可操作提示，避免直接透传系统底层错误
    if (isNetworkConnectionError(rawMsg)) {
      throw new Error('无法连接后端服务，请确认后端已启动且 hdc rport 已建立（模拟器重启后需重跑 rport）');
    }
    throw new Error(rawMsg);
  } finally {
    req.destroy();
  }
}

interface ApiClient {
  get: <T>(path: string) => Promise<T>;
  post: <T>(path: string, body?: Object) => Promise<T>;
  put: <T>(path: string, body?: Object) => Promise<T>;
  del: <T>(path: string) => Promise<T>;
}

export const api: ApiClient = {
  get: <T>(path: string): Promise<T> => request<T>(http.RequestMethod.GET, path),
  post: <T>(path: string, body?: Object): Promise<T> => request<T>(http.RequestMethod.POST, path, body),
  put: <T>(path: string, body?: Object): Promise<T> => request<T>(http.RequestMethod.PUT, path, body),
  del: <T>(path: string): Promise<T> => request<T>(http.RequestMethod.DELETE, path),
};

// ===== 领域类型 =====
export type SortType = 'hot' | 'latest' | 'recommend';

export interface ListResult<T> {
  list: T[];
  pagination: Pagination;
}

// 详情接口返回的帖子自带 comments（后端 getPost include comments）
export interface PostWithComments extends Post {
  comments?: Comment[];
}

export interface ListPostsParams {
  page?: number;
  limit?: number;
  sort?: SortType;
  tag?: string;
  author?: number;
}

export interface SearchPostsParams {
  keyword: string;
  page?: number;
  pageSize?: number;
  sort?: SortType;
}

export interface CreatePostBody {
  title: string;
  content?: string;
  coverImage?: string;
  images?: string[];
  genre: Genre;
  tags: string[];
  structuredData?: Object;
}

export interface CreateCommentBody {
  content: string;
  parentId?: number;
  isFact?: boolean;
}

export interface LoginBody {
  openId: string;
  nickname?: string;
  avatar?: string;
}

export interface LoginResult {
  token: string;
  user: User;
}

// 华为账号登录：用 Authorization Code 换取登录态
export interface HuaweiExchangeBody {
  code: string;
}

// 腾讯云 COS 直传签名：后端签发预签名 PUT URL，前端直传二进制
export interface UploadSignature {
  url: string; // 预签名 PUT URL（前端直传目标）
  key: string; // 对象 Key
  cdnUrl: string; // 直传后公开可读时访问的 URL
  viewUrl: string; // GET 预签名可读链接（私有桶也能加载，展示与存储一律用这个）
  contentType: string; // 前端 PUT 必须带上的 Content-Type（需与签名一致）
}

// 拼接 query string（跳过 undefined/null/空串）
function toQuery(fields: Array<[string, string | number | undefined]>): string {
  const parts: string[] = [];
  for (const f of fields) {
    const v = f[1];
    if (v !== undefined && v !== null && v !== '') {
      parts.push(f[0] + '=' + encodeURIComponent(String(v)));
    }
  }
  return parts.length > 0 ? '?' + parts.join('&') : '';
}

// ===== 帖子 =====
// GET /v1/posts?page=&limit=&sort=hot|latest|recommend&tag=&author=
export function listPosts(params: ListPostsParams = {}): Promise<ListResult<Post>> {
  const path = '/v1/posts' + toQuery([
    ['page', params.page],
    ['limit', params.limit],
    ['sort', params.sort],
    ['tag', params.tag],
    ['author', params.author],
  ]);
  return api.get<ListResult<Post>>(path);
}

// GET /v1/posts/hotspot?windowHours=&page=&limit=&tag=
// 时窗加权热帖（综合点赞/评论/收藏，按时效衰减）
export interface HotPostsParams {
  windowHours?: number;
  page?: number;
  limit?: number;
  tag?: string;
}

export function listHotPosts(params: HotPostsParams = {}): Promise<ListResult<Post>> {
  const path: string = '/v1/posts/hotspot' + toQuery([
    ['windowHours', params.windowHours],
    ['page', params.page],
    ['limit', params.limit],
    ['tag', params.tag],
  ]);
  return api.get<ListResult<Post>>(path);
}

// GET /v1/posts/:id（含 comments）
export function getPost(id: number): Promise<PostWithComments> {
  return api.get<PostWithComments>('/v1/posts/' + id);
}

// GET /v1/posts/following?page=&limit=&sort=hot|latest|recommend&tag=
// 关注流：仅当前用户关注的人的公开帖（需登录，request 自动带 Bearer）
export function listFollowingPosts(params: ListPostsParams = {}): Promise<ListResult<Post>> {
  const path: string = '/v1/posts/following' + toQuery([
    ['page', params.page],
    ['limit', params.limit],
    ['sort', params.sort],
    ['tag', params.tag],
  ]);
  return api.get<ListResult<Post>>(path);
}

// GET /v1/posts?keyword=&page=&limit=&sort=  （复用 /v1/posts 端点，keyword 选填）
export function searchPosts(params: SearchPostsParams): Promise<ListResult<Post>> {
  const path = '/v1/posts' + toQuery([
    ['keyword', params.keyword],
    ['page', params.page],
    ['limit', params.pageSize],
    ['sort', params.sort],
  ]);
  return api.get<ListResult<Post>>(path);
}

// POST /v1/posts（MVP 直接发布）
export function createPost(body: CreatePostBody): Promise<Post> {
  return api.post<Post>('/v1/posts', body);
}

// 编辑帖子（仅本人）：PUT /v1/posts/:id
export interface UpdatePostBody {
  title?: string;
  content?: string;
  coverImage?: string;
  images?: string[];
  tags?: string[];
  structuredData?: Object;
}

export function updatePost(id: number, body: UpdatePostBody): Promise<Post> {
  return api.put<Post>('/v1/posts/' + id, body);
}

// DELETE /v1/posts/:id（仅本人）
export async function deletePost(id: number): Promise<void> {
  await api.del<null>('/v1/posts/' + id);
}

// ===== 评论 =====
// GET /v1/posts/:id/comments?page=
export function listComments(postId: number, page?: number): Promise<ListResult<Comment>> {
  const path = '/v1/posts/' + postId + '/comments' + toQuery([['page', page]]);
  return api.get<ListResult<Comment>>(path);
}

// POST /v1/posts/:id/comments
export function createComment(postId: number, body: CreateCommentBody): Promise<Comment> {
  return api.post<Comment>('/v1/posts/' + postId + '/comments', body);
}

// DELETE /v1/comments/:id（仅本人）
export async function deleteComment(id: number): Promise<void> {
  await api.del<null>('/v1/comments/' + id);
}

// POST /v1/comments/:id/up（评论点赞，幂等）
export async function upComment(id: number): Promise<void> {
  await api.post<null>('/v1/comments/' + id + '/up');
}

// DELETE /v1/comments/:id/up（取消评论点赞，幂等）
export async function cancelUpComment(id: number): Promise<void> {
  await api.del<null>('/v1/comments/' + id + '/up');
}

// ===== 互动 =====
// POST/DELETE /v1/posts/:id/up
export async function upPost(id: number): Promise<void> {
  await api.post<null>('/v1/posts/' + id + '/up');
}

export async function cancelUpPost(id: number): Promise<void> {
  await api.del<null>('/v1/posts/' + id + '/up');
}

// POST/DELETE /v1/posts/:id/bookmark
export async function bookmarkPost(id: number): Promise<void> {
  await api.post<null>('/v1/posts/' + id + '/bookmark');
}

export async function cancelBookmarkPost(id: number): Promise<void> {
  await api.del<null>('/v1/posts/' + id + '/bookmark');
}

// ===== 标签 =====
// GET /v1/tags
export function listTags(): Promise<Tag[]> {
  return api.get<Tag[]>('/v1/tags');
}

// 关注标签（加入圈子）
// POST /v1/tags/:name/follow
export async function followTag(name: string): Promise<Tag> {
  return api.post<Tag>('/v1/tags/' + encodeURIComponent(name) + '/follow');
}

// 取消关注标签（退出圈子）
// DELETE /v1/tags/:name/follow
export async function unfollowTag(name: string): Promise<Tag> {
  return api.del<Tag>('/v1/tags/' + encodeURIComponent(name) + '/follow');
}

// 当前用户关注的标签名列表（圈子已加入）
// GET /v1/auth/me/followed-tags
export function listFollowedTags(): Promise<string[]> {
  return api.get<string[]>('/v1/auth/me/followed-tags');
}

// ===== 用户 / 鉴权 =====
// POST /v1/auth/login（成功后由调用方 auth.ts 统一持久化 session）
export function login(body: LoginBody): Promise<LoginResult> {
  return api.post<LoginResult>('/v1/auth/login', body);
}

// POST /v1/auth/huawei/exchange（华为 Authorization Code 换登录态；返回结构与 login 一致，前端零改解析）
export function exchangeHuaweiCode(body: HuaweiExchangeBody): Promise<LoginResult> {
  return api.post<LoginResult>('/v1/auth/huawei/exchange', body);
}

// GET /v1/auth/me
export function getMe(): Promise<User> {
  return api.get<User>('/v1/auth/me');
}

// PUT /v1/auth/me
export interface UpdateMeBody {
  nickname?: string;
  avatar?: string;
  bio?: string;
  gender?: number;
}

export function updateMe(body: UpdateMeBody): Promise<User> {
  return api.put<User>('/v1/auth/me', body);
}

// 账号注销（软删）：POST /v1/auth/me/deactivate，无参，自动带 Bearer。
// 成功后前端自行清 token（见 SettingsPage 的 doDeactivate）。
export function deactivateAccount(): Promise<void> {
  return api.post<void>('/v1/auth/me/deactivate');
}

// GET /v1/auth/me/bookmarks?page=&limit=（我的收藏帖子列表，分页）
export function listMyBookmarks(page: number = 1, limit: number = 20): Promise<ListResult<Post>> {
  const path = '/v1/auth/me/bookmarks' + toQuery([['page', page], ['limit', limit]]);
  return api.get<ListResult<Post>>(path);
}

// GET /v1/auth/me/likes?page=&limit=（我赞过的帖子列表，分页）
export function listMyLikedPosts(page: number = 1, limit: number = 20): Promise<ListResult<Post>> {
  const path = '/v1/auth/me/likes' + toQuery([['page', page], ['limit', limit]]);
  return api.get<ListResult<Post>>(path);
}

// GET /v1/auth/me/commented?page=&limit=（我评论过的帖子列表，分页）
export function listMyCommentedPosts(page: number = 1, limit: number = 20): Promise<ListResult<Post>> {
  const path = '/v1/auth/me/commented' + toQuery([['page', page], ['limit', limit]]);
  return api.get<ListResult<Post>>(path);
}

// ===== 账号绑定管理 =====
// GET /v1/account/bindings（当前用户全部绑定，harmony 主账号置顶）
export function listBindings(): Promise<BindingItem[]> {
  return api.get<BindingItem[]>('/v1/account/bindings');
}

// POST /v1/account/bindings（绑定第三方，code 变体）
export function bindAccount(provider: Provider, code: string): Promise<BindingItem> {
  const body: BindAccountBody = { provider, code };
  return api.post<BindingItem>('/v1/account/bindings', body);
}

// DELETE /v1/account/bindings/:provider（解绑第三方，harmony 不可解绑）
export function unbindAccount(provider: Provider): Promise<UnbindResult> {
  return api.del<UnbindResult>('/v1/account/bindings/' + provider);
}

// ===== 消息通知 =====
// GET /v1/notifications?page=&limit=（当前用户通知列表，分页）
export function listNotifications(page: number = 1, limit: number = 20): Promise<ListResult<NotificationItem>> {
  const path = '/v1/notifications' + toQuery([['page', page], ['limit', limit]]);
  return api.get<ListResult<NotificationItem>>(path);
}

// GET /v1/notifications/unread-count（未读总数，用于 Tab 红点）
export function getUnreadCount(): Promise<UnreadCount> {
  return api.get<UnreadCount>('/v1/notifications/unread-count');
}

// POST /v1/notifications/:id/read（标记单条已读）
export async function markNotificationRead(id: number): Promise<void> {
  await api.post<null>('/v1/notifications/' + id + '/read');
}

// POST /v1/notifications/read-all（全部已读）
export async function markAllRead(): Promise<void> {
  await api.post<null>('/v1/notifications/read-all');
}

// ===== 上传 =====
// POST /v1/upload/token → 返回腾讯云 COS 预签名 PUT URL（前端直传）
export interface UploadSignatureBody {
  contentType?: string;
}

export function getUploadSignature(contentType: string = 'image/jpeg'): Promise<UploadSignature> {
  const body: UploadSignatureBody = { contentType };
  return api.post<UploadSignature>('/v1/upload/token', body);
}

// ===== 搜索历史 / 热搜词 =====

// 搜索历史项（后端返回）
export interface SearchHistoryItem {
  id: number;
  keyword: string;
  createdAt: string;
}

// 热搜词项（后端返回）
export interface HotKeywordItem {
  keyword: string;
  count: number;
}

// 搜索历史列表响应
export interface SearchHistoryResult {
  list: SearchHistoryItem[];
}

// 热搜词列表响应
export interface HotKeywordResult {
  list: HotKeywordItem[];
}

// 记录搜索历史的请求体
export interface RecordSearchHistoryBody {
  keyword: string;
}

// POST /v1/search/history  记录搜索历史（前端搜索成功后调用）
export async function recordSearchHistory(keyword: string): Promise<void> {
  const body: RecordSearchHistoryBody = { keyword: keyword };
  await api.post<null>('/v1/search/history', body);
}

// GET /v1/search/history  搜索历史列表（返回关键词数组，按时间倒序）
export async function listSearchHistory(): Promise<string[]> {
  const res: SearchHistoryResult = await api.get<SearchHistoryResult>('/v1/search/history');
  const items: SearchHistoryItem[] = res.list;
  const keywords: string[] = [];
  for (let i = 0; i < items.length; i++) {
    keywords.push(items[i].keyword);
  }
  return keywords;
}

// DELETE /v1/search/history  清除搜索历史
export async function clearSearchHistory(): Promise<void> {
  await api.del<null>('/v1/search/history');
}

// GET /v1/search/hot?limit=10  热搜词列表（返回关键词数组，按搜索次数降序）
export async function listHotKeywords(limit?: number): Promise<string[]> {
  const path: string = '/v1/search/hot' + toQuery([['limit', limit]]);
  const res: HotKeywordResult = await api.get<HotKeywordResult>(path);
  const items: HotKeywordItem[] = res.list;
  const keywords: string[] = [];
  for (let i = 0; i < items.length; i++) {
    keywords.push(items[i].keyword);
  }
  return keywords;
}

// ===== 关注 / 他人主页 =====
// GET /v1/users/:id（他人/自己资料，含聚合计数与关系态）
// 注意：不要传 'me'——'me' 会被 /v1/users 下的 authRouter 抢先命中返回原始 user（缺计数），务必传数字 id。
export function getUserProfile(id: number): Promise<UserProfile> {
  return api.get<UserProfile>('/v1/users/' + id);
}

// POST /v1/users/:id/follow（关注，幂等；后端校验不可自关）
export async function followUser(id: number): Promise<void> {
  await api.post<null>('/v1/users/' + id + '/follow');
}

// DELETE /v1/users/:id/follow（取消关注，幂等）
export async function unfollowUser(id: number): Promise<void> {
  await api.del<null>('/v1/users/' + id + '/follow');
}

// GET /v1/users/:id/following?page=&limit=（关注列表，分页）
export function listFollowing(id: number, page: number = 1, limit: number = 20): Promise<FollowListResult> {
  const path = '/v1/users/' + id + '/following' + toQuery([['page', page], ['limit', limit]]);
  return api.get<FollowListResult>(path);
}

// GET /v1/users/:id/followers?page=&limit=（粉丝列表，分页）
export function listFollowers(id: number, page: number = 1, limit: number = 20): Promise<FollowListResult> {
  const path = '/v1/users/' + id + '/followers' + toQuery([['page', page], ['limit', limit]]);
  return api.get<FollowListResult>(path);
}

// ===== 举报 =====
// POST /v1/posts/:id/report（举报帖子）
export async function reportPost(id: number, body: ReportBody): Promise<void> {
  await api.post<null>('/v1/posts/' + id + '/report', body);
}

// POST /v1/comments/:id/report（举报评论）
export async function reportComment(id: number, body: ReportBody): Promise<void> {
  await api.post<null>('/v1/comments/' + id + '/report', body);
}

// ===== 内容审核（admin） =====
// GET /v1/admin/posts/pending?page=&limit= 待审核帖子列表（含举报记录）
export function getPendingPosts(page: number = 1, limit: number = 20): Promise<ListResult<PendingPost>> {
  const path: string = '/v1/admin/posts/pending' + toQuery([['page', page], ['limit', limit]]);
  return api.get<ListResult<PendingPost>>(path);
}

// POST /v1/admin/posts/:id/moderate 请求体
export interface ModerateBody {
  action: ModerateAction;
  reason?: string;
}

// POST /v1/admin/posts/:id/moderate {action: approve|reject, reason?}
export async function moderatePost(id: number, action: ModerateAction, reason?: string): Promise<void> {
  const body: ModerateBody = { action, reason };
  await api.post<null>('/v1/admin/posts/' + id + '/moderate', body);
}

// ===== 通知偏好 =====
// GET /v1/me/notification-prefs
export function getNotificationPrefs(): Promise<NotificationPrefs> {
  return api.get<NotificationPrefs>('/v1/me/notification-prefs');
}

// PUT /v1/me/notification-prefs
export function updateNotificationPrefs(body: NotificationPrefs): Promise<NotificationPrefs> {
  return api.put<NotificationPrefs>('/v1/me/notification-prefs', body);
}

// ===== 拉黑管理 =====
// GET /v1/me/blocklist?page=&limit=
export function listBlocked(page: number = 1, limit: number = 20): Promise<ListResult<BlockUser>> {
  const path: string = '/v1/me/blocklist' + toQuery([['page', page], ['limit', limit]]);
  return api.get<ListResult<BlockUser>>(path);
}

// POST /v1/me/block/:blockedId
export async function blockUser(blockedId: number): Promise<void> {
  await api.post<null>('/v1/me/block/' + blockedId);
}

// DELETE /v1/me/block/:blockedId
export async function unblockUser(blockedId: number): Promise<void> {
  await api.del<null>('/v1/me/block/' + blockedId);
}

// ===== 隐私设置 =====
// GET /v1/me/privacy
export function getPrivacySettings(): Promise<PrivacySettingsData> {
  return api.get<PrivacySettingsData>('/v1/me/privacy');
}

// PUT /v1/me/privacy
export function updatePrivacySettings(body: PrivacySettingsData): Promise<PrivacySettingsData> {
  return api.put<PrivacySettingsData>('/v1/me/privacy', body);
}

// ===== 私信 =====
// GET /v1/messages/conversations —— 会话列表
export function getConversations(): Promise<{ list: Conversation[] }> {
  return api.get<{ list: Conversation[] }>('/v1/messages/conversations');
}

// GET /v1/messages/unread —— 私信未读总数
export function getDmUnreadCount(): Promise<{ count: number }> {
  return api.get<{ count: number }>('/v1/messages/unread');
}

// GET /v1/messages/:userId?page= —— 与某用户私信历史（旧→新）
export function getMessages(userId: number, page: number = 1): Promise<{ list: DmMessage[] }> {
  return api.get<{ list: DmMessage[] }>('/v1/messages/' + userId + '?page=' + page);
}

// POST /v1/messages/:userId/read —— 标记与该用户私信已读
export async function markMessagesRead(userId: number): Promise<void> {
  await api.post<null>('/v1/messages/' + userId + '/read');
}

// POST /v1/messages { receiverId, content } —— 发送私信
interface SendMessageBody {
  receiverId: number;
  content: string;
}
export async function sendMessage(receiverId: number, content: string): Promise<DmMessage> {
  return api.post<DmMessage>('/v1/messages', { receiverId, content } as SendMessageBody);
}

// ===== 辩论投票 =====
// POST /v1/posts/:id/vote { choice: 'A' | 'B' }
interface VoteDebateBody {
  choice: string;
}

export function voteDebate(postId: number, choice: string): Promise<DebateVoteResult> {
  const body: VoteDebateBody = { choice: choice };
  return api.post<DebateVoteResult>('/v1/posts/' + postId + '/vote', body);
}

// ===== 数据导出 =====
// GET /v1/me/export
export function exportUserData(): Promise<UserExportData> {
  return api.get<UserExportData>('/v1/me/export');
}
