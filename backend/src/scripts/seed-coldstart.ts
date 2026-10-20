// 冷启动造数 CLI。
//
// 默认什么都不写，只把「这批数据落库后会变成什么样」摊开给人看：
// 条数、每圈时间分布、体裁配比、热榜前十、错误与警告清单。
// 写库必须显式 --apply；回滚必须 --wipe 加 --apply 两道。
//
// 用法（容器内）
//   node dist/scripts/seed-coldstart.js --content /tmp/seed-content
//   node dist/scripts/seed-coldstart.js --content /tmp/seed-content --apply
//   node dist/scripts/seed-coldstart.js --wipe
//   node dist/scripts/seed-coldstart.js --wipe --apply
//   node dist/scripts/seed-coldstart.js --verify

import * as fs from 'fs';
import * as path from 'path';
import { CIRCLE_BY_SLUG } from '../seed/catalog';
import { loadContent } from '../seed/loader';
import { assertPlan, planContent, plannedMediaKeys, summarize } from '../seed/planner';
import { ValidationIssue } from '../seed/schema';

interface Args {
  content: string;
  apply: boolean;
  wipe: boolean;
  update: boolean;
  verify: boolean;
  only: string | null;
  limit: number;
  mediaReport: string | null;
}

const DEFAULT_CONTENT_DIR = path.resolve(__dirname, '../../prisma/seed-data/coldstart');

function parseArgs(argv: string[]): Args {
  const args: Args = {
    content: DEFAULT_CONTENT_DIR,
    apply: false,
    wipe: false,
    update: false,
    verify: false,
    only: null,
    limit: 0,
    mediaReport: null,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--apply') args.apply = true;
    else if (token === '--wipe') args.wipe = true;
    else if (token === '--update') args.update = true;
    else if (token === '--verify') args.verify = true;
    else if (token === '--content') args.content = path.resolve(argv[++i] ?? '');
    else if (token === '--only') args.only = argv[++i] ?? null;
    else if (token === '--limit') args.limit = Number(argv[++i] ?? 0);
    else if (token === '--media-report') args.mediaReport = argv[++i] ?? null;
    else if (token === '--help' || token === '-h') {
      console.log('参数：--content <dir> --only <slug> --limit <n> --apply --update --wipe --verify --media-report <file>');
      process.exit(0);
    } else {
      console.error(`未知参数 ${token}`);
      process.exit(2);
    }
  }
  return args;
}

function printSection(title: string): void {
  console.log(`\n== ${title} ==`);
}

function printIssues(issues: ValidationIssue[]): void {
  const errors = issues.filter((issue) => issue.severity === 'error');
  const warns = issues.filter((issue) => issue.severity === 'warn');
  printSection('校验');
  console.log(`错误 ${errors.length} 条，提醒 ${warns.length} 条`);
  const preview = errors.concat(warns).slice(0, 60);
  for (const issue of preview) {
    const where = issue.postId ? `${issue.file}/${issue.postId}` : issue.file;
    const field = issue.field ? `.${issue.field}` : '';
    console.log(`  [${issue.severity === 'error' ? 'x' : '!'}] ${where}${field} ${issue.message}`);
  }
  if (errors.length + warns.length > preview.length) {
    console.log(`  …还有 ${errors.length + warns.length - preview.length} 条未显示`);
  }
}

function readMediaReport(file: string): Set<string> {
  const payload = JSON.parse(fs.readFileSync(file, 'utf8')) as { keys?: string[] };
  return new Set(payload.keys ?? []);
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));

  if (args.verify) {
    const { verifySeedData } = await import('../seed/writer');
    const result = await verifySeedData();
    printSection('线上核对');
    console.log(`种子帖 ${result.seedPosts} 条`);
    console.log(`评论数不一致 ${result.commentCountMismatch} 条`);
    console.log(`测评/辩论缺主数字 ${result.metricMissing} 条`);
    console.log(`封面引用异常 ${result.coverMissing} 条`);
    console.log(`标题重复 ${result.duplicateTitles} 条`);
    process.exit(result.commentCountMismatch + result.metricMissing + result.coverMissing + result.duplicateTitles > 0 ? 1 : 0);
  }

  if (args.wipe) {
    const { wipeSeedData } = await import('../seed/writer');
    const summary = await wipeSeedData(args.apply, (line) => console.log(`  ${line}`));
    printSection(args.apply ? '清理完成' : '清理预演（加 --apply 才执行）');
    console.log(`账号 ${summary.users}，帖子 ${summary.posts}，评论 ${summary.comments}`);
    process.exit(0);
  }

  const { content, issues, similarPairs } = loadContent(args.content);
  printIssues(issues);
  const errors = issues.filter((issue) => issue.severity === 'error');
  if (errors.length > 0) {
    console.error('\n存在错误，已中止。修完再跑。');
    process.exit(1);
  }

  const now = new Date();
  const fullPlan = planContent(content, now);
  const failures = assertPlan(fullPlan);
  if (failures.length > 0) {
    printSection('系统性断言未通过');
    for (const line of failures) console.log(`  [x] ${line}`);
    process.exit(1);
  }

  let plan = fullPlan;
  if (args.only) {
    const entry = CIRCLE_BY_SLUG.get(args.only);
    if (!entry) {
      console.error(`--only ${args.only} 不是已知圈子 slug`);
      process.exit(2);
    }
    plan = plan.filter((item) => item.circleName === entry.name);
  }
  if (args.limit > 0) plan = plan.slice(0, args.limit);

  const report = summarize(fullPlan);
  printSection('总览');
  console.log(`计划 ${report.total} 条，本次处理 ${plan.length} 条，作者 ${content.authors.length} 人`);
  console.log(`体裁 ${report.byGenre.map((row) => `${row.genre} ${row.count}`).join(' / ')}`);
  console.log(`近似重复对 ${similarPairs.length} 组（硬重复已在上面拦掉）`);

  printSection('每圈分布');
  for (const row of report.byCircle) {
    console.log(`  ${row.circle.padEnd(6, '　')} ${String(row.count).padStart(2)} 条，72 小时内 ${row.within72h}，7 天内 ${row.within7d}`);
  }

  printSection('热榜前十（落库后）');
  for (const row of report.topPosts) {
    console.log(`  ${row.hotScore.toFixed(1).padStart(6)}  ${row.tier.padEnd(6)} ${row.id}  ${row.title}`);
  }

  if (args.mediaReport) {
    const uploaded = readMediaReport(args.mediaReport);
    const needed = plannedMediaKeys(plan);
    const missing = needed.filter((key) => !uploaded.has(key));
    printSection('素材核对');
    console.log(`需要 ${needed.length} 张，已上传 ${needed.length - missing.length} 张`);
    if (missing.length > 0) {
      for (const key of missing.slice(0, 10)) console.log(`  [x] 缺 ${key}`);
      console.error('素材不全，已中止。先跑 seed-upload-media。');
      process.exit(3);
    }
  }

  if (!args.apply) {
    printSection('预演结束');
    console.log('加 --apply 才会写库');
    process.exit(0);
  }

  const { recountTags, upsertAuthors, writePosts } = await import('../seed/writer');
  const usedSlugs = new Set(plan.map((item) => item.record.author));
  const userMap = await upsertAuthors(content.authors, usedSlugs, now, (line) => console.log(`  ${line}`));
  const result = await writePosts(plan, userMap, { update: args.update, log: (line) => console.log(`  ${line}`) });
  printSection(`写入完成（${args.update ? '允许覆盖正文' : '已存在则跳过'}）`);
  console.log(`新建 ${result.created} 条，跳过 ${result.skipped} 条，评论 ${result.comments} 条`);
  await recountTags((line) => console.log(`  ${line}`));
  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
