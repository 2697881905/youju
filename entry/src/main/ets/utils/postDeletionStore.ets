// 全局帖子删除事件仓库（单例）
//
// 背景：详情页删除帖子成功后 router.back 返回列表页，但列表宿主（首页 HomeTab、
// 个人主页 ProfilePage、他人主页 UserProfilePage）多为 TabContent 常驻页，
// back 返回时 aboutToAppear / @Watch 不触发，内存中仍保留已删帖子，界面不即时移除。
//
// 方案：进程级单例广播「帖子已删除」事件，所有帖子列表宿主在 aboutToAppear 订阅、
// aboutToDisappear 退订，收到事件后从本地 @State 数组即时移除对应项。与 likeStore
// 同模式，是 ArkUI V1 严格模式下最稳的跨组件实时同步方式。

type DeletionListener = (postId: number) => void;

class PostDeletionStoreImpl {
  private listeners: DeletionListener[] = [];

  // 删除成功后广播（幂等：同一 postId 可被多次通知，列表 filter 天然去重）
  notifyDeleted(postId: number): void {
    for (const cb of this.listeners) {
      cb(postId);
    }
  }

  // 订阅删除事件；返回取消订阅函数（组件 aboutToDisappear 时调用，防泄漏）
  subscribe(cb: DeletionListener): () => void {
    this.listeners.push(cb);
    return (): void => {
      const idx: number = this.listeners.indexOf(cb);
      if (idx >= 0) {
        this.listeners.splice(idx, 1);
      }
    };
  }
}

export const postDeletionStore: PostDeletionStoreImpl = new PostDeletionStoreImpl();
