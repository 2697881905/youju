// 内容库强校验。
//
// 设计上只做一件事：把「能写进数据库但会让页面变形」的输入挡在写库之前，并且
// 一次把所有问题都收集出来（不是撞到第一个就抛）。300 多条内容靠人肉逐条比对字段
// 不现实，报错信息必须能直接定位到「哪个文件、哪条帖子、哪个字段」。

import { validateStructuredData } from '../utils/structuredFields';
import { CIRCLE_BY_NAME, CIRCLE_BY_SLUG, CIRCLE_CATALOG } from './catalog';
import {
  Genre,
  SeedAuthorRecord,
  SeedBlockSpec,
  SeedCircleFile,
  SeedPostRecord,
  SeedTier,
  StructuredBlockType,
} from './types';

export interface ValidationIssue {
  file: string;
  postId?: string;
  field?: string;
  message: string;
  severity: 'error' | 'warn';
}

const GENRES: Genre[] = ['review', 'pitfall', 'tutorial', 'debate', 'share'];
const TIERS: SeedTier[] = ['hero', 'solid', 'normal', 'tail'];

// 与 entry/src/main/ets/utils/structuredDocument.ets 的 structuredBlockTypesForGenre 一致。
// 不同步就会出现「发布页能选、详情页被过滤掉」的空块。
export const BLOCK_TYPES_BY_GENRE: Record<Genre, StructuredBlockType[]> = {
  review: ['metric', 'insight', 'compare', 'list'],
  pitfall: ['insight', 'steps', 'list'],
  tutorial: ['steps', 'list', 'insight'],
  debate: ['compare', 'insight', 'metric'],
  share: [],
};

const TIER_AGE_RANGE: Record<SeedTier, [number, number]> = {
  hero: [4, 36],
  solid: [24, 120],
  normal: [120, 480],
  tail: [480, 1440],
};

const POSTER_STYLES = ['paper', 'film', 'kraft', 'sticky'];
const THEMES = ['editorial', 'warm', 'cool'];
const ID_PATTERN = /^[a-z]{3,12}-\d{4}$/;
const RATING_PATTERN = /^[0-5](\.\d)?$/;

function textLength(text: string): number {
  return Array.from(text).length;
}

function checkBlocks(
  post: SeedPostRecord,
  file: string,
  issues: ValidationIssue[],
): void {
  const blocks: SeedBlockSpec[] = post.blocks ?? [];
  const allowed = BLOCK_TYPES_BY_GENRE[post.genre] ?? [];
  if (post.genre === 'share') {
    if (blocks.length > 0) {
      issues.push({ file, postId: post.id, field: 'blocks', message: '分享体裁不允许结构化块', severity: 'error' });
    }
    return;
  }
  // blocks 留空是正常写法：derive 会按体裁自动装配并带骨架变化。
  // 只有作者显式写了 blocks 才逐块校验。
  if (blocks.length === 0) {
    return;
  }
  if (blocks.length > 8) {
    issues.push({ file, postId: post.id, field: 'blocks', message: '信息块最多 8 个', severity: 'error' });
  }
  blocks.forEach((block, index) => {
    const prefix = `blocks[${index}]`;
    if (allowed.indexOf(block.type) < 0) {
      issues.push({
        file,
        postId: post.id,
        field: prefix,
        message: `体裁 ${post.genre} 不支持 ${block.type} 块（允许 ${allowed.join('/')}）`,
        severity: 'error',
      });
    }
    if (!block.title || textLength(block.title) > 30) {
      issues.push({ file, postId: post.id, field: `${prefix}.title`, message: '标题需 1~30 字', severity: 'error' });
    }
    if (block.value !== undefined && textLength(block.value) > 300) {
      issues.push({ file, postId: post.id, field: `${prefix}.value`, message: '数值/正文最多 300 字', severity: 'error' });
    }
    if (block.unit !== undefined && textLength(block.unit) > 16) {
      issues.push({ file, postId: post.id, field: `${prefix}.unit`, message: '单位最多 16 字', severity: 'error' });
    }
    if (block.helper !== undefined && textLength(block.helper) > 80) {
      issues.push({ file, postId: post.id, field: `${prefix}.helper`, message: '说明最多 80 字', severity: 'error' });
    }
    if (block.items !== undefined) {
      if (block.items.length > 12) {
        issues.push({ file, postId: post.id, field: `${prefix}.items`, message: '条目最多 12 项', severity: 'error' });
      }
      block.items.forEach((item, itemIndex) => {
        if (textLength(item) > 120) {
          issues.push({
            file,
            postId: post.id,
            field: `${prefix}.items[${itemIndex}]`,
            message: '单项最多 120 字',
            severity: 'error',
          });
        }
      });
    }
    for (const key of ['leftLabel', 'rightLabel'] as const) {
      const value = block[key];
      if (value !== undefined && textLength(value) > 12) {
        issues.push({ file, postId: post.id, field: `${prefix}.${key}`, message: '标签最多 12 字', severity: 'error' });
      }
    }
    for (const key of ['leftValue', 'rightValue'] as const) {
      const value = block[key];
      if (value !== undefined && textLength(value) > 180) {
        issues.push({ file, postId: post.id, field: `${prefix}.${key}`, message: '对照内容最多 180 字', severity: 'error' });
      }
    }
    if (block.type === 'metric') {
      if (!block.value) {
        issues.push({ file, postId: post.id, field: `${prefix}.value`, message: '数字块必须有 value', severity: 'error' });
      }
      if (block.numberValue !== undefined && !Number.isFinite(block.numberValue)) {
        issues.push({ file, postId: post.id, field: `${prefix}.numberValue`, message: 'numberValue 必须是有限数值', severity: 'error' });
      }
    }
  });
  if (post.primaryBlockIndex !== undefined) {
    if (post.primaryBlockIndex < 0 || post.primaryBlockIndex >= blocks.length) {
      issues.push({ file, postId: post.id, field: 'primaryBlockIndex', message: '主视觉下标越界', severity: 'error' });
    }
  }
}

export function validatePost(
  post: SeedPostRecord,
  circleName: string,
  file: string,
  authorsBySlug: Map<string, SeedAuthorRecord>,
): ValidationIssue[] {
  const issues: ValidationIssue[] = [];
  const where = { file, postId: post.id };

  if (!ID_PATTERN.test(post.id ?? '')) {
    issues.push({ ...where, field: 'id', message: 'id 形如 shuma-0001（圈子 slug 加四位序号）', severity: 'error' });
  } else {
    const entry = CIRCLE_BY_SLUG.get(post.id.split('-')[0]);
    if (!entry) {
      issues.push({ ...where, field: 'id', message: `id 前缀 ${post.id.split('-')[0]} 不是已知圈子 slug`, severity: 'error' });
    } else if (entry.name !== circleName) {
      issues.push({ ...where, field: 'id', message: `id 前缀对应 ${entry.name}，与文件圈子 ${circleName} 不符`, severity: 'error' });
    }
  }

  const author = authorsBySlug.get(post.author);
  if (!author) {
    issues.push({ ...where, field: 'author', message: `作者 ${post.author} 不在 authors.json`, severity: 'error' });
  }

  if (!GENRES.includes(post.genre)) {
    issues.push({ ...where, field: 'genre', message: `未知体裁 ${post.genre}`, severity: 'error' });
  }

  const titleLength = textLength(post.title ?? '');
  if (titleLength < 4 || titleLength > 40) {
    issues.push({ ...where, field: 'title', message: `标题 ${titleLength} 字，需 4~40 字`, severity: 'error' });
  }

  const contentLength = textLength(post.content ?? '');
  const minContent = post.genre === 'share' ? 60 : 90;
  const maxContent = post.genre === 'share' ? 1200 : 1400;
  if (contentLength < minContent || contentLength > maxContent) {
    issues.push({
      ...where,
      field: 'content',
      message: `正文 ${contentLength} 字，需 ${minContent}~${maxContent} 字`,
      severity: 'error',
    });
  }
  const paragraphs = String(post.content ?? '').split('\n').filter((p) => p.trim().length > 0);
  if (paragraphs.length > 7) {
    issues.push({ ...where, field: 'content', message: '正文最多 7 段', severity: 'error' });
  }

  if (!Array.isArray(post.tags) || post.tags.length < 1 || post.tags.length > 3) {
    issues.push({ ...where, field: 'tags', message: '标签需 1~3 个', severity: 'error' });
  } else {
    post.tags.forEach((tag, index) => {
      if (!CIRCLE_BY_NAME.has(tag)) {
        issues.push({ ...where, field: `tags[${index}]`, message: `标签 ${tag} 不是现有圈子`, severity: 'error' });
      }
    });
    if (post.tags[0] !== circleName) {
      issues.push({ ...where, field: 'tags[0]', message: `首标签必须是本圈 ${circleName}`, severity: 'error' });
    }
    if (new Set(post.tags).size !== post.tags.length) {
      issues.push({ ...where, field: 'tags', message: '标签重复', severity: 'error' });
    }
  }

  if (!TIERS.includes(post.tier)) {
    issues.push({ ...where, field: 'tier', message: `未知档位 ${post.tier}`, severity: 'error' });
  } else {
    const [min, max] = TIER_AGE_RANGE[post.tier];
    if (!(post.ageHours >= min && post.ageHours <= max)) {
      issues.push({
        ...where,
        field: 'ageHours',
        message: `${post.tier} 档需 ${min}~${max} 小时，实际 ${post.ageHours}`,
        severity: 'error',
      });
    }
  }

  if (post.posterStyle !== undefined && POSTER_STYLES.indexOf(post.posterStyle) < 0) {
    issues.push({ ...where, field: 'posterStyle', message: '未知海报样式', severity: 'error' });
  }
  if (post.theme !== undefined && THEMES.indexOf(post.theme) < 0) {
    issues.push({ ...where, field: 'theme', message: '未知主题', severity: 'error' });
  }

  const structured = post.structured;
  if (post.genre !== 'share') {
    const insight = String(post.insight ?? '').trim();
    if (insight.length < 6 || insight.length > 60) {
      issues.push({ ...where, field: 'insight', message: '一句结论需 6~60 字', severity: 'error' });
    }
  }
  if (structured) {
    const error = validateStructuredData(structured, post.genre);
    if (error) {
      issues.push({ ...where, field: 'structured', message: error, severity: 'error' });
    }
    if (structured.rating !== undefined && !RATING_PATTERN.test(String(structured.rating))) {
      issues.push({ ...where, field: 'structured.rating', message: '推荐指数需 0~5 且最多一位小数', severity: 'error' });
    }
    if (post.genre === 'review') {
      for (const key of ['pros', 'cons'] as const) {
        if (!structured[key] || String(structured[key]).trim().length === 0) {
          issues.push({ ...where, field: `structured.${key}`, message: '测评必须写优点与缺点', severity: 'error' });
        }
      }
      if (structured.rating === undefined) {
        issues.push({ ...where, field: 'structured.rating', message: '测评必须给推荐指数', severity: 'error' });
      }
    }
    if (post.genre === 'pitfall') {
      for (const key of ['pitfallExperience', 'correctApproach'] as const) {
        if (!structured[key] || String(structured[key]).trim().length === 0) {
          issues.push({ ...where, field: `structured.${key}`, message: '避坑必须写踩坑经历与正确做法', severity: 'error' });
        }
      }
    }
    if (post.genre === 'tutorial' && !structured.steps) {
      issues.push({ ...where, field: 'structured.steps', message: '教程必须写步骤', severity: 'error' });
    }
    if (post.genre === 'debate') {
      for (const key of ['planA', 'planB'] as const) {
        if (!structured[key]) {
          issues.push({ ...where, field: `structured.${key}`, message: '辩论必须给两个方案', severity: 'error' });
        }
      }
    }
    if (post.genre === 'share') {
      issues.push({ ...where, field: 'structured', message: '分享体裁不写结构化字段', severity: 'error' });
    }
  } else if (post.genre !== 'share') {
    issues.push({ ...where, field: 'structured', message: '该体裁缺少结构化字段', severity: 'error' });
  }

  checkBlocks(post, file, issues);

  const comments = post.comments ?? [];
  if (comments.length > 12) {
    issues.push({ ...where, field: 'comments', message: '单帖评论最多 12 条', severity: 'error' });
  }
  comments.forEach((comment, index) => {
    const prefix = `comments[${index}]`;
    if (!authorsBySlug.has(comment.author)) {
      issues.push({ ...where, field: `${prefix}.author`, message: `评论作者 ${comment.author} 不存在`, severity: 'error' });
    }
    const length = textLength(comment.text ?? '');
    if (length < 4 || length > 90) {
      issues.push({ ...where, field: `${prefix}.text`, message: `评论 ${length} 字，需 4~90 字`, severity: 'error' });
    }
    const offset = comment.offsetMinutes;
    if (offset === undefined) {
      issues.push({ ...where, field: `${prefix}.offsetMinutes`, message: '评论必须给时间偏移', severity: 'error' });
    } else if (offset < 1 || offset >= post.ageHours * 60) {
      issues.push({ ...where, field: `${prefix}.offsetMinutes`, message: '偏移需在发帖后、导入前', severity: 'error' });
    }
    if (comment.replyToIndex !== undefined && comment.replyToIndex >= index) {
      issues.push({ ...where, field: `${prefix}.replyToIndex`, message: '只能回复更早的评论', severity: 'error' });
    }
  });

  return issues;
}

export function validateAuthors(authors: SeedAuthorRecord[], file: string): ValidationIssue[] {
  const issues: ValidationIssue[] = [];
  if (authors.length === 0) {
    issues.push({ file, message: 'authors.json 为空', severity: 'error' });
  }
  const seenSlug = new Set<string>();
  const seenNickname = new Set<string>();
  authors.forEach((author, index) => {
    const prefix = `authors[${index}]`;
    if (!/^[a-z][a-z0-9_]{2,20}$/.test(author.slug ?? '')) {
      issues.push({ file, field: `${prefix}.slug`, message: 'slug 需 3~21 位小写字母数字下划线', severity: 'error' });
    }
    if (seenSlug.has(author.slug)) {
      issues.push({ file, field: `${prefix}.slug`, message: `slug 重复 ${author.slug}`, severity: 'error' });
    }
    seenSlug.add(author.slug);
    if (!author.nickname || textLength(author.nickname) > 16) {
      issues.push({ file, field: `${prefix}.nickname`, message: '昵称需 1~16 字', severity: 'error' });
    }
    if (seenNickname.has(author.nickname)) {
      issues.push({ file, field: `${prefix}.nickname`, message: `昵称重复 ${author.nickname}`, severity: 'error' });
    }
    seenNickname.add(author.nickname);
    if (!author.bio || textLength(author.bio) > 60) {
      issues.push({ file, field: `${prefix}.bio`, message: '简介需 1~60 字', severity: 'error' });
    }
    if (author.gender !== 1 && author.gender !== 2) {
      issues.push({ file, field: `${prefix}.gender`, message: '性别只能是 1 或 2', severity: 'error' });
    }
    if (!Array.isArray(author.circles) || author.circles.length === 0) {
      issues.push({ file, field: `${prefix}.circles`, message: '至少归属一个圈子', severity: 'error' });
    } else {
      author.circles.forEach((circle) => {
        if (!CIRCLE_BY_NAME.has(circle)) {
          issues.push({ file, field: `${prefix}.circles`, message: `未知圈子 ${circle}`, severity: 'error' });
        }
      });
    }
    if (!/^#[0-9a-fA-F]{6}$/.test(author.avatarColor ?? '')) {
      issues.push({ file, field: `${prefix}.avatarColor`, message: '头像底色需 #RRGGBB', severity: 'error' });
    }
  });
  return issues;
}

/** 跨文件检查：圈子覆盖、条数、id/标题唯一 */
export function validateCoverage(
  files: SeedCircleFile[],
  issues: ValidationIssue[],
): void {
  const idSeen = new Map<string, string>();
  const titleSeen = new Map<string, string>();
  const perCircle = new Map<string, number>();

  for (const file of files) {
    const entry = CIRCLE_BY_NAME.get(file.circle);
    if (!entry) {
      issues.push({ file: `${file.circle}.json`, message: `未知圈子 ${file.circle}`, severity: 'error' });
      continue;
    }
    perCircle.set(file.circle, (perCircle.get(file.circle) ?? 0) + file.posts.length);
    for (const post of file.posts) {
      if (idSeen.has(post.id)) {
        issues.push({ file: file.circle, postId: post.id, field: 'id', message: 'id 重复', severity: 'error' });
      }
      idSeen.set(post.id, file.circle);
      if (titleSeen.has(post.title)) {
        issues.push({
          file: file.circle,
          postId: post.id,
          field: 'title',
          message: `标题与 ${titleSeen.get(post.title)} 重复`,
          severity: 'error',
        });
      }
      titleSeen.set(post.title, post.id);
    }
  }

  for (const entry of CIRCLE_CATALOG) {
    const actual = perCircle.get(entry.name) ?? 0;
    if (actual !== entry.targetPosts) {
      issues.push({
        file: 'catalog.ts',
        field: entry.slug,
        message: `${entry.name} 应有 ${entry.targetPosts} 条，实际 ${actual} 条`,
        severity: 'error',
      });
    }
  }
}
