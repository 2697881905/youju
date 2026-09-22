import { Post } from '../models/types';

// 信息流懒加载数据源（WaterFlow + LazyForEach 专用）。
// 现状（Scroll + ForEach）会把已加载的每一张卡片全部常驻挂载；换成 WaterFlow 后
// 由 LazyForEach 按可视区按需创建并回收划出屏外的卡片，内存与滚动性能不再随页数线性恶化。
//
// 与 HomeTab 的 @State posts 并存：posts 仍是唯一业务数据源（缓存/删除/统计都基于它），
// 本类只做「按需迭代 + 增量通知」，在 fetch 的赋值点同步调用 replaceAll / append。
export class FeedDataSource implements IDataSource {
  private items: Post[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): Post {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const i: number = this.listeners.indexOf(listener);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }

  // 首屏/切流/刷新：整表替换
  replaceAll(next: Post[]): void {
    this.items = next;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }

  // 加载更多：逐条通知新增，避免整表重建（保住已挂载卡片的滚动位置）
  append(next: Post[]): void {
    const start: number = this.items.length;
    this.items = this.items.concat(next);
    for (const l of this.listeners) {
      for (let i: number = 0; i < next.length; i++) {
        l.onDataAdd(start + i);
      }
    }
  }
}
