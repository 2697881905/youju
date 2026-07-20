// 通用 LazyForEach 数据源，支持列表数据的懒加载渲染
// 替代 ForEach，在大量数据场景下显著提升性能

export class BasicDataSource<T> implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private dataArray: T[] = [];

  totalCount(): number {
    return this.dataArray.length;
  }

  getData(index: number): T {
    return this.dataArray[index] as T;
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos: number = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  // 通知数据变更（用于刷新场景）
  notifyDataReload(): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded();
    });
  }

  notifyDataAdd(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataAdd(index);
    });
  }

  notifyDataChange(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataChange(index);
    });
  }

  notifyDataDelete(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataDelete(index);
    });
  }

  // 清空数据并通知
  clearData(): void {
    this.dataArray = [];
    this.notifyDataReload();
  }

  // 获取数据长度（用于空状态判断）
  getLength(): number {
    return this.dataArray.length;
  }

  // 设置数据
  setData(data: T[]): void {
    this.dataArray = data;
    this.notifyDataReload();
  }

  // 追加数据
  appendData(data: T[]): void {
    for (let i = 0; i < data.length; i++) {
      this.dataArray.push(data[i]);
      this.notifyDataAdd(this.dataArray.length - 1);
    }
  }

  // 替换全部数据
  replaceData(data: T[]): void {
    this.dataArray = data;
  }

  // 获取原始数据（用于外部访问）
  getRawData(): T[] {
    return this.dataArray;
  }
}
