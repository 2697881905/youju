import { prisma } from '../prisma';
import { env } from '../config/env';

// ===== 行为数据留存与到期清理 =====
// 合规依据：《个人信息保护法》第 19 条——个人信息的保存期限应为实现处理目的所必需的
// 最短时间。浏览/互动埋点（PostEvent）与搜索历史（SearchHistory）属明细类行为数据，
// 超过留存窗口后对推荐与统计不再有价值，应按时删除。
//
// 取舍说明：当前曝光/点击等统计均为「按需 groupBy 聚合」，不依赖历史明细的长期保留；
// 删除窗口外的明细只会使远期统计精度下降，这是合规与统计之间已在隐私政策中告知的既定取舍。

const DAY_MS = 86400000;

export interface PurgeResult {
  cutoff: Date;
  retentionDays: number;
  postEvents: number;
  searchHistory: number;
}

/**
 * 删除早于留存窗口的行为明细，返回各表删除条数。
 * 仅删明细行，不触碰帖子/评论等用户内容。
 */
export async function purgeExpiredBehaviorData(
  now: Date = new Date(),
  retentionDays: number = env.behaviorRetentionDays,
): Promise<PurgeResult> {
  // 至少保留 1 天，避免误配 0/负数导致「刚写入就被删」
  const days = Math.max(1, Math.floor(retentionDays));
  const cutoff = new Date(now.getTime() - days * DAY_MS);

  const [postEvents, searchHistory] = await Promise.all([
    prisma.postEvent.deleteMany({ where: { createdAt: { lt: cutoff } } }),
    prisma.searchHistory.deleteMany({ where: { createdAt: { lt: cutoff } } }),
  ]);

  return {
    cutoff,
    retentionDays: days,
    postEvents: postEvents.count,
    searchHistory: searchHistory.count,
  };
}

/**
 * 行为数据到期清理任务：启动后先跑一次，此后每 24 小时一次。
 * 定时器已 unref，不阻塞进程退出（与 mediaDeletionService 的 worker 同范式）。
 */
export function startBehaviorRetentionWorker(): void {
  if (!env.behaviorRetentionEnabled) {
    console.log('[retention] 行为数据到期清理已关闭（BEHAVIOR_RETENTION_ENABLED=false）');
    return;
  }
  const run = (phase: string): void => {
    void purgeExpiredBehaviorData()
      .then((result) => {
        console.log(
          '[retention] ' + phase + ' 清理完成：留存 ' + result.retentionDays + ' 天，'
          + '截止 ' + result.cutoff.toISOString() + '，'
          + '删除 PostEvent ' + result.postEvents + ' 条、SearchHistory ' + result.searchHistory + ' 条',
        );
      })
      .catch((e) => console.warn('[retention] ' + phase + ' 清理失败：', (e as Error).message));
  };
  run('initial');
  const timer = setInterval(() => {
    run('scheduled');
  }, DAY_MS);
  timer.unref();
}
