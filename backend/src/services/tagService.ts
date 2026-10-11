import { prisma } from '../prisma';
import { Tag } from '@prisma/client';
import { sensitiveWordService } from './sensitiveWordService';
import { SensitiveWordError, ValidationError } from '../utils/errors';

// 星图 Live 三期：分类白名单（与客户端 CIRCLE_META 的五大类一致）
export const TAG_CATEGORIES: string[] = ['消费选购', '动手改造', '职场与收入', '生活与家庭', '兴趣休闲'];

// 获取所有标签（按使用次数降序）
export async function listTags() {
  return prisma.tag.findMany({ orderBy: { useCount: 'desc' } });
}

// 深空目录全量：可按关键词过滤（名字/分类/简介），供 GET /v1/tags?all=1&keyword=
export async function searchTags(keyword?: string): Promise<Tag[]> {
  const kw = keyword?.trim();
  const where = kw
    ? {
        OR: [
          { name: { contains: kw } },
          { category: { contains: kw } },
          { description: { contains: kw } },
        ],
      }
    : {};
  return prisma.tag.findMany({ where, orderBy: [{ activeScore: 'desc' }, { followCount: 'desc' }] });
}

// 创建圈子（点亮新星）：名称唯一 + 敏感词 + 分类白名单；创建者自动关注并计入 followCount。
export async function createTag(userId: number, name: string, category: string, description: string): Promise<Tag> {
  const trimmed = name.trim();
  if (trimmed.length < 2 || trimmed.length > 8) {
    throw new ValidationError('圈子名字需 2~8 个字');
  }
  if (!TAG_CATEGORIES.includes(category)) {
    throw new ValidationError('分类无效');
  }
  const desc = description.trim();
  if (desc.length === 0 || desc.length > 24) {
    throw new ValidationError('一句话简介需 1~24 字');
  }
  if (sensitiveWordService.checkText(trimmed) || sensitiveWordService.checkText(desc)) {
    throw new SensitiveWordError('名称或简介含敏感词');
  }
  const existing = await prisma.tag.findUnique({ where: { name: trimmed } });
  if (existing) {
    throw new ValidationError('已有同名圈子');
  }
  const created = await prisma.tag.create({
    data: { name: trimmed, category, description: desc, emoji: '🌟' },
  });
  // 创建者自动加入（复用 followTag 的幂等 +1 逻辑）
  await followTag(userId, trimmed);
  const final = await prisma.tag.findUnique({ where: { name: trimmed } });
  return final ?? created;
}

// 星等刷新：近 14 天发帖按时间衰减累加。activeScore>阈值即亮星。
// 由启动 + 定时 worker 调用；帖子量级小，逐标签 count 可接受。
export async function recomputeActiveScores(): Promise<number> {
  const WINDOW_DAYS = 14;
  const start = new Date(Date.now() - WINDOW_DAYS * 86400000);
  const tags = await prisma.tag.findMany({ select: { name: true } });
  for (const tag of tags) {
    const posts = await prisma.post.findMany({
      where: { deletedAt: null, status: 1, createdAt: { gte: start }, tags: { array_contains: tag.name } },
      select: { createdAt: true },
    });
    let score = 0;
    for (const p of posts) {
      const ageDays = (Date.now() - p.createdAt.getTime()) / 86400000;
      score += Math.exp(-ageDays / 7); // 半衰约 5 天的指数衰减
    }
    await prisma.tag.update({ where: { name: tag.name }, data: { activeScore: Math.round(score * 1000) / 1000 } });
  }
  return tags.length;
}

// 关注标签（幂等）：仅当新建关注时 Tag.followCount + 1，返回更新后的标签
export async function followTag(userId: number, tagName: string): Promise<Tag> {
  await prisma.$transaction(async (tx) => {
    const existing = await tx.userFollowTag.findUnique({
      where: { userId_tagName: { userId, tagName } },
    });
    if (existing) {
      return; // 幂等：已关注，不重复 +1
    }
    await tx.userFollowTag.create({ data: { userId, tagName } });
    await tx.tag.updateMany({
      where: { name: tagName },
      data: { followCount: { increment: 1 } },
    });
  });
  const tag = await prisma.tag.findFirst({ where: { name: tagName } });
  return tag!;
}

// 取消关注标签：仅当存在关注记录时 Tag.followCount - 1，返回更新后的标签
export async function unfollowTag(userId: number, tagName: string): Promise<Tag> {
  await prisma.$transaction(async (tx) => {
    const deleted = await tx.userFollowTag.deleteMany({
      where: { userId, tagName },
    });
    if (deleted.count > 0) {
      await tx.tag.updateMany({
        where: { name: tagName, followCount: { gt: 0 } },
        data: { followCount: { decrement: 1 } },
      });
    }
  });
  const tag = await prisma.tag.findFirst({ where: { name: tagName } });
  return tag!;
}

// 当前用户关注的标签名列表（按关注时间倒序）
export async function listFollowedTags(userId: number): Promise<string[]> {
  const rows = await prisma.userFollowTag.findMany({
    where: { userId },
    select: { tagName: true },
    orderBy: { createdAt: 'desc' },
  });
  return rows.map((r) => r.tagName);
}

// ===== 星图 Live：引力档位 / 未读角标 / 圈子活跃度 =====

export interface TagWeightItem {
  tagName: string;
  weight: number; // 1=强关注 2=常关注 3=轻关注
}

// 读取当前用户全部引力档位（仅返回显式设置过的；缺省由客户端按 2 处理）
export async function listTagWeights(userId: number): Promise<TagWeightItem[]> {
  const rows = await prisma.userTagPref.findMany({
    where: { userId },
    select: { tagName: true, weight: true },
  });
  return rows.map((r) => ({ tagName: r.tagName, weight: r.weight }));
}

// 设置引力档位（upsert）。仅允许已加入的圈子调节——未加入没有「推送强度」可言。
export async function setTagWeight(userId: number, tagName: string, weight: number): Promise<boolean> {
  const w = weight === 1 || weight === 3 ? weight : 2;
  const followed = await prisma.userFollowTag.findUnique({
    where: { userId_tagName: { userId, tagName } },
  });
  if (!followed) {
    return false;
  }
  await prisma.userTagPref.upsert({
    where: { userId_tagName: { userId, tagName } },
    create: { userId, tagName, weight: w },
    update: { weight: w },
  });
  return true;
}

// 记录「已读到此刻」：进圈子（降落/详情页）时调用，未读角标随之归零
export async function markTagRead(userId: number, tagName: string): Promise<void> {
  await prisma.userTagRead.upsert({
    where: { userId_tagName: { userId, tagName } },
    create: { userId, tagName, lastReadAt: new Date() },
    update: { lastReadAt: new Date() },
  });
}

export interface TagActivityItem {
  tagName: string;
  unread: number; // 自 lastReadAt 起的新帖数（未浏览过=全部近期新帖）
  active: boolean; // 近 7 天有新帖
  activeScore: number; // 星等（近14天衰减热度，驱动行星亮度分级）
  latestPostId: number | null; // 最新一帖（星子点击直达）
}

const ACTIVE_WINDOW_DAYS = 7;

// 圈子活跃度 + 未读数：一次查询给出星图「亮星/暗星 + 角标 + 星子」所需数据。
// 帖子 tags 为 JSON 数组列，MySQL 下用 JSON_CONTAINS 匹配；按标签名逐个统计，
// 标签总量受 CIRCLE_META 约束（数十个），逐个 count 在千级帖子量下开销可接受。
export async function listTagActivity(userId: number): Promise<TagActivityItem[]> {
  const tags = await prisma.tag.findMany({ select: { name: true, activeScore: true } });
  const reads = await prisma.userTagRead.findMany({
    where: { userId },
    select: { tagName: true, lastReadAt: true },
  });
  const readMap = new Map(reads.map((r) => [r.tagName, r.lastReadAt]));
  const windowStart = new Date(Date.now() - ACTIVE_WINDOW_DAYS * 86400000);

  const items: TagActivityItem[] = [];
  for (const tag of tags) {
    const since = readMap.get(tag.name) ?? windowStart;
    const [recent, unread, latest] = await Promise.all([
      prisma.post.count({
        where: { deletedAt: null, status: 1, createdAt: { gte: windowStart }, tags: { array_contains: tag.name } },
      }),
      prisma.post.count({
        where: { deletedAt: null, status: 1, createdAt: { gt: since }, tags: { array_contains: tag.name } },
      }),
      prisma.post.findFirst({
        where: { deletedAt: null, status: 1, tags: { array_contains: tag.name } },
        orderBy: { createdAt: 'desc' },
        select: { id: true },
      }),
    ]);
    items.push({ tagName: tag.name, unread, active: recent > 0, activeScore: tag.activeScore, latestPostId: latest?.id ?? null });
  }
  return items;
}
