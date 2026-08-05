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

let detailPostId: string = '';
let targetUserId: number = 0;
let searchKeyword: string = '';
let circleDetailName: string = '';
let chatIntent: ChatIntent | null = null;
let followListIntent: FollowListIntent | null = null;

export function openPostDetail(id: string): void {
  detailPostId = id;
}

export function takePostDetailId(): string {
  const id: string = detailPostId;
  detailPostId = '';
  return id;
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
