// 教程步骤打卡：本地阅读进度，不上传后端。
//
// 为什么走 dataPreferences 而不是 AppStorage：打卡回答的是「我跟着这篇教程做到了第几步」，
// 只活一次进程的存储等于没有。dataPreferences 在本仓覆盖安装全流程中可靠（见 sessionStore 说明）。
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREF_NAME: string = 'youju_step_checks';

type StepCheckListener = (postId: number) => void;

class StepCheckStoreImpl {
  private ctx: common.ApplicationContext | null = null;
  private prefs: preferences.Preferences | null = null;
  private checked: Set<string> = new Set<string>();
  private listeners: StepCheckListener[] = [];

  // EntryAbility.onCreate 调用，早于任何详情页构建，首帧即可读到已存进度。
  init(ctx: common.ApplicationContext): void {
    this.ctx = ctx;
    this.load();
  }

  isChecked(postId: number, blockId: string, index: number): boolean {
    return this.checked.has(this.keyOf(postId, blockId, index));
  }

  setChecked(postId: number, blockId: string, index: number, value: boolean): void {
    const key: string = this.keyOf(postId, blockId, index);
    if (value) {
      this.checked.add(key);
    } else {
      this.checked.delete(key);
    }
    const prefs: preferences.Preferences | null = this.open();
    if (prefs !== null) {
      try {
        if (value) {
          prefs.putSync(key, true);
        } else {
          prefs.deleteSync(key);
        }
        prefs.flushSync();
      } catch (e) {
        // 内存态已经更新，写盘失败只影响下次启动的进度恢复，不打断当前打卡
      }
    }
    for (const listener of this.listeners) {
      listener(postId);
    }
  }

  subscribe(listener: StepCheckListener): () => void {
    this.listeners.push(listener);
    return (): void => {
      const index: number = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  private keyOf(postId: number, blockId: string, index: number): string {
    return String(postId) + '|' + blockId + '|' + String(index);
  }

  private open(): preferences.Preferences | null {
    if (this.prefs === null && this.ctx !== null) {
      try {
        this.prefs = preferences.getPreferencesSync(this.ctx, { name: PREF_NAME });
      } catch (e) {
        return null;
      }
    }
    return this.prefs;
  }

  private load(): void {
    const prefs: preferences.Preferences | null = this.open();
    if (prefs === null) {
      return;
    }
    try {
      // getAllSync 的返回类型是 Object，只能在这一处收窄成 Record：越界就早收，后面按普通字典读
      const all: Record<string, preferences.ValueType> =
        prefs.getAllSync() as Record<string, preferences.ValueType>;
      this.checked = new Set<string>();
      for (const key of Object.keys(all)) {
        if (all[key] === true) {
          this.checked.add(key);
        }
      }
    } catch (e) {
      // 读不到就当没有进度：打卡是锦上添花，不能因为它挡住正文
    }
  }
}

export const stepCheckStore: StepCheckStoreImpl = new StepCheckStoreImpl();
