// 全局辩论投票状态仓库。
//
// ArkUI V1 对跨组件深层对象变更的刷新并不稳定。这里沿用 likeStore 的模式：
// 组件订阅后把变化复制进自身 @State，从而可靠刷新票数、进度和选中态。

export class DebateVoteInfo {
  planAVotes: number;
  planBVotes: number;
  choice: string;

  constructor(planAVotes: number, planBVotes: number, choice: string) {
    this.planAVotes = planAVotes;
    this.planBVotes = planBVotes;
    this.choice = choice;
  }
}

type DebateVoteListener = (postId: number) => void;

class DebateVoteStoreImpl {
  private votes: Map<number, DebateVoteInfo> = new Map<number, DebateVoteInfo>();
  private listeners: DebateVoteListener[] = [];

  get(postId: number): DebateVoteInfo | undefined {
    return this.votes.get(postId);
  }

  // 详情加载完成时，以服务端快照校准本帖当前投票态。
  syncFromServer(postId: number, planAVotes: number, planBVotes: number, choice: string): void {
    this.votes.set(postId, new DebateVoteInfo(planAVotes, planBVotes, choice));
    this.emit(postId);
  }

  // 返回改票前快照，失败时可精确回滚。
  applyOptimistic(postId: number, choice: string): DebateVoteInfo {
    const current: DebateVoteInfo = this.votes.get(postId) ?? new DebateVoteInfo(0, 0, '');
    const previous: DebateVoteInfo = new DebateVoteInfo(
      current.planAVotes,
      current.planBVotes,
      current.choice,
    );
    let nextA: number = current.planAVotes;
    let nextB: number = current.planBVotes;
    if (current.choice === 'A') {
      nextA = Math.max(0, nextA - 1);
    } else if (current.choice === 'B') {
      nextB = Math.max(0, nextB - 1);
    }
    if (choice === 'A') {
      nextA += 1;
    } else {
      nextB += 1;
    }
    this.votes.set(postId, new DebateVoteInfo(nextA, nextB, choice));
    this.emit(postId);
    return previous;
  }

  revert(postId: number, previous: DebateVoteInfo): void {
    this.votes.set(postId, new DebateVoteInfo(
      previous.planAVotes,
      previous.planBVotes,
      previous.choice,
    ));
    this.emit(postId);
  }

  subscribe(listener: DebateVoteListener): () => void {
    this.listeners.push(listener);
    return (): void => {
      const index: number = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  private emit(postId: number): void {
    for (const listener of this.listeners) {
      listener(postId);
    }
  }
}

export const debateVoteStore: DebateVoteStoreImpl = new DebateVoteStoreImpl();
