/**
 * 手动执行「行为明细数据到期清理」（PIPL 第 19 条：保存期限应为实现目的所必需的最短时间）。
 * 删除早于留存窗口的 PostEvent（浏览/互动埋点）与 SearchHistory（搜索历史）明细行。
 *
 * 用法：
 *   npm run data:purge-behavior
 *   BEHAVIOR_RETENTION_DAYS=90 npm run data:purge-behavior   # 临时覆盖留存天数
 *
 * 说明：服务启动后本清理已由后台任务每 24 小时自动执行一次，此脚本用于运维手动触发/核对。
 */
import { prisma } from '../src/prisma';
import { env } from '../src/config/env';
import { purgeExpiredBehaviorData } from '../src/services/retentionService';

async function main(): Promise<void> {
  console.log('[purge] 留存窗口 = ' + env.behaviorRetentionDays + ' 天，开始清理行为明细…');
  const result = await purgeExpiredBehaviorData();
  console.log(
    '[purge] 完成：截止 ' + result.cutoff.toISOString()
    + '，删除 PostEvent ' + result.postEvents + ' 条、SearchHistory ' + result.searchHistory + ' 条',
  );
}

main()
  .catch((e) => {
    console.error('[purge] 失败：', (e as Error).message);
    process.exitCode = 1;
  })
  .finally(() => {
    void prisma.$disconnect();
  });
