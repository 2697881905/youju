// 发布预选圈子意图：从圈子详情空态「去发布」进入发布流时，记住当前圈子。
// 只在当前进程存活；发布页在「新建草稿」重置时消费一次，避免后续新帖被旧意图污染。
let pendingPublishCircle: string = '';

export function setPendingPublishCircle(name: string): void {
  pendingPublishCircle = name;
}

export function consumePendingPublishCircle(): string {
  const name: string = pendingPublishCircle;
  pendingPublishCircle = '';
  return name;
}
