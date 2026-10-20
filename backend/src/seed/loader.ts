// 内容库加载与总校验。
//
// 一次读全量再一次性报错。300 多条内容，逐条修最怕「改一条跑一次」，
// 所以这里把 schema、去 AI 味、近似查重、开头重复四类检查合并成一份 issue 列表。

import * as fs from 'fs';
import * as path from 'path';
import { CIRCLE_CATALOG, CIRCLE_BY_NAME } from './catalog';
import { validateAuthors, validateCoverage, validatePost, ValidationIssue } from './schema';
import { findSimilarPairs } from './similarity';
import { densityWarnings, findStyleViolations, sentenceLengthSpread } from './styleLint';
import {
  LoadedContent,
  SeedAuthorRecord,
  SeedAuthorsFile,
  SeedCircleFile,
  SeedPostRecord,
} from './types';

function readJson<T>(file: string): T {
  return JSON.parse(fs.readFileSync(file, 'utf8')) as T;
}

/** 去 AI 味检查覆盖到「会被读者看见的每一个字段」 */
function lintPost(post: SeedPostRecord, circleName: string, file: string): ValidationIssue[] {
  const issues: ValidationIssue[] = [];
  const texts: Array<{ field: string; text: string }> = [
    { field: 'title', text: post.title ?? '' },
    { field: 'content', text: post.content ?? '' },
  ];
  if (post.insight) texts.push({ field: 'insight', text: post.insight });
  if (post.posterLine) texts.push({ field: 'posterLine', text: post.posterLine });
  const structured = post.structured ?? {};
  for (const [key, value] of Object.entries(structured)) {
    if (typeof value === 'string') texts.push({ field: `structured.${key}`, text: value });
  }
  (post.blocks ?? []).forEach((block, index) => {
    const fields: Array<[string, string | undefined]> = [
      ['title', block.title],
      ['value', block.value],
      ['helper', block.helper],
      ['leftValue', block.leftValue],
      ['rightValue', block.rightValue],
    ];
    for (const [key, value] of fields) {
      if (value) texts.push({ field: `blocks[${index}].${key}`, text: value });
    }
    (block.items ?? []).forEach((item, itemIndex) => {
      texts.push({ field: `blocks[${index}].items[${itemIndex}]`, text: item });
    });
  });
  (post.comments ?? []).forEach((comment, index) => {
    texts.push({ field: `comments[${index}].text`, text: comment.text });
  });

  for (const item of texts) {
    for (const violation of findStyleViolations(item.text)) {
      issues.push({
        file,
        postId: post.id,
        field: item.field,
        message: `${violation.rule}「${violation.match}」`,
        severity: violation.severity === 'hard' ? 'error' : 'warn',
      });
    }
    for (const violation of densityWarnings(item.text)) {
      issues.push({
        file,
        postId: post.id,
        field: item.field,
        message: `${violation.rule}（${violation.match}）`,
        severity: 'warn',
      });
    }
  }

  const spread = sentenceLengthSpread(post.content ?? '');
  if (spread.count >= 8 && spread.stdDev < 3.5) {
    issues.push({
      file,
      postId: post.id,
      field: 'content',
      message: `句长过于均匀（标准差 ${spread.stdDev.toFixed(1)}），读起来像同一口气`,
      severity: 'warn',
    });
  }
  return issues;
}

/** 同一圈子里三篇帖子用同一句开头，是「批量生产」最明显的痕迹 */
function lintOpenings(posts: SeedPostRecord[], circleName: string): ValidationIssue[] {
  const issues: ValidationIssue[] = [];
  const buckets = new Map<string, string[]>();
  for (const post of posts) {
    const head = Array.from(post.content ?? '').slice(0, 4).join('');
    if (head.length < 3) continue;
    const list = buckets.get(head) ?? [];
    list.push(post.id);
    buckets.set(head, list);
  }
  for (const [head, ids] of buckets) {
    if (ids.length > 2) {
      issues.push({
        file: `${circleName}.json`,
        postId: ids[0],
        field: 'content',
        message: `开头「${head}」在 ${circleName} 出现 ${ids.length} 次（${ids.join(' ')}）`,
        severity: 'warn',
      });
    }
  }
  return issues;
}

export interface LoadResult {
  content: LoadedContent;
  issues: ValidationIssue[];
  similarPairs: ReturnType<typeof findSimilarPairs>;
}

export function loadContent(dir: string): LoadResult {
  const issues: ValidationIssue[] = [];
  const authorsFile = path.join(dir, 'authors.json');
  if (!fs.existsSync(authorsFile)) {
    throw new Error(`缺少作者文件 ${authorsFile}`);
  }
  const authorsPayload = readJson<SeedAuthorsFile>(authorsFile);
  const authors: SeedAuthorRecord[] = authorsPayload.authors ?? [];
  issues.push(...validateAuthors(authors, 'authors.json'));
  const authorsBySlug = new Map(authors.map((author) => [author.slug, author]));

  const circleFiles: SeedCircleFile[] = [];
  const circleOfPost = new Map<string, string>();
  for (const entry of CIRCLE_CATALOG) {
    const filePath = path.join(dir, 'circles', `${entry.slug}.json`);
    if (!fs.existsSync(filePath)) {
      issues.push({
        file: `${entry.slug}.json`,
        message: `缺少圈子文件，期望 ${entry.targetPosts} 条`,
        severity: 'error',
      });
      continue;
    }
    const payload = readJson<SeedCircleFile>(filePath);
    if (payload.circle !== entry.name) {
      issues.push({
        file: `${entry.slug}.json`,
        message: `circle 字段为 ${payload.circle}，与 ${entry.name} 不符`,
        severity: 'error',
      });
    }
    circleFiles.push(payload);
    for (const post of payload.posts) {
      circleOfPost.set(post.id, entry.name);
      if (post._topic !== undefined && post._topic.trim().length === 0) {
        issues.push({
          file: `${entry.slug}.json`,
          postId: post.id,
          field: '_topic',
          message: '主题留空等于放弃查重',
          severity: 'warn',
        });
      }
      issues.push(...validatePost(post, entry.name, `${entry.slug}.json`, authorsBySlug));
      issues.push(...lintPost(post, entry.name, `${entry.slug}.json`));
    }
    issues.push(...lintOpenings(payload.posts, entry.name));
  }

  validateCoverage(circleFiles, issues);

  const allPosts: SeedPostRecord[] = [];
  for (const file of circleFiles) {
    for (const post of file.posts) allPosts.push(post);
  }

  // 近似查重只比正文，标题相似不算重复（同一件事换个角度写标题是正常的）
  const similarPairs = findSimilarPairs(allPosts.map((post) => ({ id: post.id, text: post.content })));
  for (const hit of similarPairs) {
    if (hit.severity !== 'hard') continue;
    issues.push({
      file: 'circles',
      postId: hit.leftId,
      field: 'content',
      message: `与 ${hit.rightId} 高度相似（${hit.score}）`,
      severity: 'error',
    });
  }

  // 作者引用不到的情况 validatePost 已经报过，这里补一层「跨圈常驻」提示
  for (const post of allPosts) {
    const author = authorsBySlug.get(post.author);
    const circleName = circleOfPost.get(post.id) ?? '';
    if (author && !CIRCLE_BY_NAME.has(circleName)) continue;
    if (author && author.circles.indexOf(circleName) < 0) {
      issues.push({
        file: 'authors.json',
        postId: post.id,
        field: 'author',
        message: `${author.nickname} 未登记为 ${circleName} 常驻，跨圈串门请收敛`,
        severity: 'warn',
      });
    }
  }

  return {
    content: { authors, posts: allPosts, circleOfPost },
    issues,
    similarPairs,
  };
}
