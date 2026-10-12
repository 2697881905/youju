// 一次性回填：把存量帖子的主数字补进 Post 的 metricValue/metricKind/metricLabel/metricText 四列。
//
// 背景：四列是 upgrade-add-post-metric.sql 之后才有的，迁移本身不猜 JSON（主视觉块与首个
// 数字块的取舍、单位判类都写在服务端 util 里，SQL 复刻一遍既难读又难回滚）。
// 发布/编辑路径已经自动写入，本脚本只负责把「加列之前发的帖子」补齐，可重复执行。
//
// 放在 src/ 下（而非 backend/scripts/）是为了能被 tsc 编进 dist：生产镜像用
// `npm ci --omit=dev` 装依赖，没有 tsx，只能跑编译产物。
// 运行（本地）：npx tsx src/scripts/backfill-post-metric.ts [--all]
// 运行（生产）：docker exec youju-backend node dist/scripts/backfill-post-metric.js [--all]
import { Prisma } from '@prisma/client';
import { prisma } from '../prisma';
import { buildPostMetricPatch } from '../utils/postMetric';

async function main(): Promise<void> {
  const rebuildAll = process.argv.indexOf('--all') >= 0;
  const posts = await prisma.post.findMany({
    where: {
      // Json 列的「库里没有值」在 Prisma 5 里是 DbNull，写 null 会被类型挡下
      structuredDocument: { not: Prisma.DbNull },
      // 默认只补空列；--all 连已写过的行一起重算（改了判类口径后用）
      ...(rebuildAll ? {} : { metricValue: null }),
    },
    select: { id: true, structuredDocument: true, metricValue: true, metricKind: true, metricLabel: true, metricText: true },
  });
  let changed = 0;
  for (const post of posts) {
    const patch = buildPostMetricPatch(post.structuredDocument);
    const unchanged = patch.metricValue === post.metricValue
      && patch.metricKind === post.metricKind
      && patch.metricLabel === post.metricLabel
      && patch.metricText === post.metricText;
    if (unchanged) continue;
    await prisma.post.update({ where: { id: post.id }, data: patch });
    changed += 1;
    console.log(`post ${post.id}: ${patch.metricValue ?? '—'} ${patch.metricKind ?? ''} ${patch.metricText ?? ''}`);
  }
  console.log(`回填完成：扫描 ${posts.length} 篇，更新 ${changed} 篇`);
}

main()
  .catch((e: unknown) => {
    console.error('回填失败：', e);
    process.exitCode = 1;
  })
  .finally(() => void prisma.$disconnect());
