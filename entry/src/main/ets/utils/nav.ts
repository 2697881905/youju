// router.getParams() 在 API 24 不稳定。以下意图只在当前 EntryAbility 页面跳转期间存活，
// 与认证/偏好持久化隔离，读取后立即清除，避免旧参数在后续页面重建时串页。
export interface ChatIntent {
  peerId: number;
  peerName: string;
  peerAvatar: string;
}

export interface FollowListIntent {
  userId: number;
  mode: 'following' | 'followers';
}

// 独立视频播放器页意图：router 壳（pages/VideoPlayerPage）据此取播放参数。
// Navigation 壳走 pushPathByName('VideoPlayer', VideoPlayerNavParams)，不经此通道。
export interface VideoPlayerIntent {
  url: string;
  poster: string;
}

// 「一镜到底」意图：卡片进入详情页时携带的展示快照。
// cover 为 resolveDisplayImageUrl 后的展示 URL，空串 = 无媒体 → 详情页走原转场。
// aspect 为详情媒体目标展示比例（宽/高）；卡面源帧由实际组件矩形单独测量。
// isVideo = true 时关闭共享转场（视频真实比例与卡面裁切比例不一致，共享受扭/拉伸）。
export interface PostDetailIntent {
  cover: string;
  title: string;
  genre: string;
  tags: string[];
  authorName: string;
  authorAvatar: string;
  createdAt: string;
  // 阅读比例（宽/高）：转场结束后详情媒体框的展示比例（如 3:4）。
  aspect: number;
  // 一镜到底「飞行目标框」比例（宽/高）：飞行落点框的比例 = 卡面比例（如卡堆 4:3）。
  // 与 aspect（阅读比例）解耦：卡面 4:3 而阅读 3:4 时同一个值无法两全——
  // 用 4:3 当阅读比例会把竖向图片压成横屏（反复踩过）。未提供 / ≤0 → 回退 aspect。
  flightAspect?: number;
  isVideo: boolean;
}

let detailPostId: string = '';
let postDetailIntent: PostDetailIntent | null = null;
let targetUserId: number = 0;
let searchKeyword: string = '';
let circleDetailName: string = '';
let chatIntent: ChatIntent | null = null;
let followListIntent: FollowListIntent | null = null;
let videoPlayerIntent: VideoPlayerIntent | null = null;

export function openPostDetail(id: string, intent?: PostDetailIntent): void {
  detailPostId = id;
  postDetailIntent = intent ?? null;
}

export function takePostDetailId(): string {
  const id: string = detailPostId;
  detailPostId = '';
  return id;
}

export function takePostDetailIntent(): PostDetailIntent | null {
  const intent: PostDetailIntent | null = postDetailIntent;
  postDetailIntent = null;
  return intent;
}

export function openUserProfile(userId: number): void {
  targetUserId = userId;
}

export function takeUserProfileId(): number {
  const id: number = targetUserId;
  targetUserId = 0;
  return id;
}

export function openSearch(keyword: string): void {
  searchKeyword = keyword;
}

export function takeSearchKeyword(): string {
  const keyword: string = searchKeyword;
  searchKeyword = '';
  return keyword;
}

export function openCircleDetail(name: string): void {
  circleDetailName = name;
}

export function takeCircleDetailName(): string {
  const name: string = circleDetailName;
  circleDetailName = '';
  return name;
}

export function openChat(intent: ChatIntent): void {
  chatIntent = { peerId: intent.peerId, peerName: intent.peerName, peerAvatar: intent.peerAvatar };
}

export function takeChatIntent(): ChatIntent | null {
  const intent: ChatIntent | null = chatIntent;
  chatIntent = null;
  return intent;
}

export function openFollowList(intent: FollowListIntent): void {
  followListIntent = { userId: intent.userId, mode: intent.mode };
}

export function takeFollowListIntent(): FollowListIntent | null {
  const intent: FollowListIntent | null = followListIntent;
  followListIntent = null;
  return intent;
}

export function openVideoPlayer(url: string, poster: string): void {
  videoPlayerIntent = { url: url, poster: poster };
}

export function takeVideoPlayerIntent(): VideoPlayerIntent | null {
  const intent: VideoPlayerIntent | null = videoPlayerIntent;
  videoPlayerIntent = null;
  return intent;
}

export type AppTab = 0 | 1 | 2 | 3 | 4;
type TabListener = (target: AppTab) => void;

const tabListeners: TabListener[] = [];

// 跨 Tab 跳转是进程内短暂导航意图，不写入 AppStorage，避免旧信号在页面重建后被重复消费。
export function emitTabSwitch(target: AppTab): void {
  for (const listener of tabListeners) {
    listener(target);
  }
}

export function subscribeTabSwitch(listener: TabListener): () => void {
  tabListeners.push(listener);
  return (): void => {
    const index: number = tabListeners.indexOf(listener);
    if (index >= 0) {
      tabListeners.splice(index, 1);
    }
  };
}
