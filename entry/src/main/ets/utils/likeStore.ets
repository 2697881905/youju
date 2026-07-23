// 全局点赞状态仓库（单例）
//
// 背景：点赞态此前只存在每个 PostCard / DetailPage 各自的 @State 里，首页卡片点赞后，
// 详情页、个人主页「我赞过」里的同一帖子副本完全不知道，导致跨页点赞数/已赞态不一致，
// 且「我赞过」列表在取消点赞后不会即时消失。
//
// 方案：用一个进程级单例保存 postId -> { liked, count }，所有展示帖子的组件在 aboutToAppear
// 时向仓库「注册并订阅」，点赞/取消时写入仓库并广播；订阅回调把最新值写回组件本地 @State，
// 触发重渲染。这是 ArkUI V1 严格模式下最稳的跨组件实时同步方式（不依赖 @Observed 深层观察）。

export class LikeInfo {
  liked: boolean = false;
  count: number = 0;

  constructor(liked: boolean, count: number) {
    this.liked = liked;
    this.count = count;
  }
}

type LikeListener = (postId: number) => void;

class LikeStoreImpl {
  private map: Map<number, LikeInfo> = new Map<number, LikeInfo>();
  private listeners: LikeListener[] = [];

  // 仅当仓库中尚无该帖子时灌入初始态（不覆盖本地已发生的点赞操作）
  ensure(postId: number, liked: boolean, count: number): void {
    if (!this.map.has(postId)) {
      this.map.set(postId, new LikeInfo(liked, count));
    }
  }

  get(postId: number): LikeInfo | undefined {
    return this.map.get(postId);
  }

  // 乐观更新（点赞/取消）。返回操作前的快照（LikeInfo 实例），便于请求失败时回滚。
  applyOptimistic(postId: number, willLike: boolean): LikeInfo {
    let info: LikeInfo | undefined = this.map.get(postId);
    if (!info) {
      info = new LikeInfo(false, 0);
      this.map.set(postId, info);
    }
    const prev: LikeInfo = new LikeInfo(info.liked, info.count);
    const delta: number = willLike ? 1 : (info.liked ? -1 : 0);
    info.liked = willLike;
    info.count = Math.max(0, info.count + delta);
    this.emit(postId);
    return prev;
  }

  // 请求失败回滚到操作前快照
  revert(postId: number, prev: LikeInfo): void {
    const info: LikeInfo | undefined = this.map.get(postId);
    if (info) {
      info.liked = prev.liked;
      info.count = prev.count;
      this.emit(postId);
    }
  }

  // 用服务器返回的绝对值覆盖（进入详情页 / 刷新列表后校准，避免与本地乐观值漂移）
  syncFromServer(postId: number, liked: boolean, count: number): void {
    let info: LikeInfo | undefined = this.map.get(postId);
    if (!info) {
      info = new LikeInfo(liked, count);
      this.map.set(postId, info);
    } else {
      info.liked = liked;
      info.count = count;
    }
    this.emit(postId);
  }

  // 订阅某帖子点赞态变化；返回取消订阅函数（组件 aboutToDisappear 时调用，防泄漏）
  subscribe(cb: LikeListener): () => void {
    this.listeners.push(cb);
    return (): void => {
      const idx: number = this.listeners.indexOf(cb);
      if (idx >= 0) {
        this.listeners.splice(idx, 1);
      }
    };
  }

  private emit(postId: number): void {
    for (const cb of this.listeners) {
      cb(postId);
    }
  }
}

export const likeStore: LikeStoreImpl = new LikeStoreImpl();
