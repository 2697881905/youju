import { prisma } from '../prisma';

// 搜索历史项
export interface SearchHistoryItem {
  id: number;
  keyword: string;
  createdAt: Date;
}

// 热搜词项
export interface HotKeywordItem {
  keyword: string;
  count: number;
}

// 记录搜索历史（去重：先删同用户同关键词再插入，保证最新时间戳）
export async function recordSearchHistory(userId: number, keyword: string): Promise<void> {
  const kw = keyword.trim();
  if (!kw) {
    return;
  }
  await prisma.searchHistory.deleteMany({
    where: { userId, keyword: kw },
  });
  await prisma.searchHistory.create({
    data: { userId, keyword: kw },
  });
}

// 搜索历史列表（按时间倒序，默认 10 条）
export async function listSearchHistory(
  userId: number,
  limit: number = 10
): Promise<SearchHistoryItem[]> {
  const rows = await prisma.searchHistory.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
    take: Math.max(1, Math.min(50, limit)),
    select: { id: true, keyword: true, createdAt: true },
  });
  return rows;
}

// 清除当前用户的全部搜索历史
export async function clearSearchHistory(userId: number): Promise<void> {
  await prisma.searchHistory.deleteMany({
    where: { userId },
  });
}

// 热搜词（聚合最近 days 天搜索记录，按搜索次数降序取 top limit）
export async function listHotKeywords(
  limit: number = 10,
  days: number = 7
): Promise<HotKeywordItem[]> {
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  const rows = await prisma.searchHistory.groupBy({
    by: ['keyword'],
    where: { createdAt: { gte: since } },
    _count: { keyword: true },
    orderBy: { _count: { keyword: 'desc' } },
    take: Math.max(1, Math.min(50, limit)),
  });
  return rows.map((r) => ({ keyword: r.keyword, count: r._count.keyword }));
}
