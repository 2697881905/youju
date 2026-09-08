import { prisma } from '../prisma';
import { USER_PUBLIC_SELECT, publicUserView } from '../utils/userView';
import { getExcludedAuthorIds, getDislikedAuthorIds } from './accessControl';

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

// ===== 帖子相关度搜索（P0-2 阶段1：应用层评分排序，候选窗口 300）=====

export interface SearchPostsParams {
  page?: number;
  limit?: number;
  keyword?: string;
  tag?: string;
  author?: number;
  sort?: 'relevance' | 'hot' | 'latest';
  following?: boolean;
  viewerId?: number;
}

// 相关度评分：标题命中权重最高；全字/前缀/包含逐级递减；标签、体裁、正文兜底
export function scoreSearchPost(post: any, keyword: string): number {
  const k = keyword.toLowerCase().trim();
  const title = String(post.title ?? '').toLowerCase();
  const content = String(post.content ?? '').toLowerCase();
  const genre = String(post.genre ?? '').toLowerCase();
  const tags: string[] = (Array.isArray(post.tags) ? post.tags : [])
    .map((t: unknown) => String(t).toLowerCase());
  let score = 0;
  if (title === k) {
    score += 100; // 标题完全命中
  } else if (title.startsWith(k)) {
    score += 80; // 标题前缀命中
  }
  if (title.includes(k)) {
    score += 50;
  }
  if (tags.some((t) => t === k)) {
    score += 40; // 标签精确命中
  } else if (tags.some((t) => t.includes(k))) {
    score += 25;
  }
  if (genre.includes(k)) {
    score += 15;
  }
  if (content.includes(k)) {
    score += 10; // 正文命中权重最低（正文噪声大）
  }
  return score;
}

// 相关度搜索结果：候选窗口内按相关度→热度→新鲜度排序，再分页 + viewer 打标
export async function searchPosts(params: SearchPostsParams) {
  const page = Math.max(1, Number(params.page ?? 1));
  const limit = Math.min(50, Math.max(1, Number(params.limit ?? 20)));
  const skip = (page - 1) * limit;
  const keyword = (params.keyword ?? '').trim();
  if (keyword.length === 0) {
    return { list: [], pagination: { page, limit, total: 0 } };
  }

  const where: any = {
    status: 1,
    deletedAt: null,
    user: { status: 1, deletedAt: null },
    OR: [
      { title: { contains: keyword } },
      { content: { contains: keyword } },
      { genre: { contains: keyword } },
      { tags: { array_contains: keyword } },
    ],
  };
  if (params.tag) {
    where.tags = { array_contains: params.tag };
  }
  if (params.author) {
    where.userId = params.author;
  }

  // 关注流 / 不可见作者排除（与信息流口径一致）
  let followIds: number[] | undefined;
  if (params.following && params.viewerId) {
    const follows = await prisma.follow.findMany({
      where: { followerId: params.viewerId },
      select: { followingId: true },
    });
    followIds = follows.map((f) => f.followingId);
    if (followIds.length === 0) {
      return { list: [], pagination: { page, limit, total: 0 } };
    }
    where.userId = { in: followIds };
  }
  const excluded = await getExcludedAuthorIds(params.viewerId);
  if (params.viewerId) {
    const disliked = await getDislikedAuthorIds(params.viewerId);
    for (const id of disliked) {
      if (excluded.indexOf(id) < 0) {
        excluded.push(id);
      }
    }
  }
  if (excluded.length > 0) {
    if (params.following) {
      where.userId = { in: followIds!, notIn: excluded };
    } else {
      where.userId = { notIn: excluded };
    }
  }

  // 候选窗口（小体量阶段足够；数据量上来后换数据库侧全文索引）
  const candidates = await prisma.post.findMany({
    where,
    include: { user: { select: USER_PUBLIC_SELECT } },
    take: 300,
  });

  const now = Date.now();
  const sorted = candidates.slice().sort((a, b) => {
    if (params.sort === 'hot') {
      return (b.hotScore ?? 0) - (a.hotScore ?? 0) || b.createdAt.getTime() - a.createdAt.getTime();
    }
    if (params.sort === 'latest') {
      return b.createdAt.getTime() - a.createdAt.getTime();
    }
    // relevance（默认）
    const sa = scoreSearchPost(a, keyword);
    const sb = scoreSearchPost(b, keyword);
    return sb - sa || (b.hotScore ?? 0) - (a.hotScore ?? 0) || b.createdAt.getTime() - a.createdAt.getTime();
  });

  const total = sorted.length;
  const pageList = sorted.slice(skip, skip + limit);

  // viewer 打标（与信息流一致：myUp / myBookmark / myVote）
  let enriched = pageList;
  if (params.viewerId && pageList.length > 0) {
    const ids = pageList.map((p) => p.id);
    const [ups, bms, votes] = await Promise.all([
      prisma.up.findMany({ where: { postId: { in: ids }, userId: params.viewerId }, select: { postId: true } }),
      prisma.bookmark.findMany({ where: { postId: { in: ids }, userId: params.viewerId }, select: { postId: true } }),
      prisma.debateVote.findMany({ where: { postId: { in: ids }, userId: params.viewerId }, select: { postId: true, choice: true } }),
    ]);
    const upSet = new Set(ups.map((u) => u.postId));
    const bmSet = new Set(bms.map((b) => b.postId));
    const voteMap = new Map(votes.map((v) => [v.postId, v.choice]));
    enriched = pageList.map((p) => ({
      ...p,
      myUp: upSet.has(p.id),
      myBookmark: bmSet.has(p.id),
      myVote: voteMap.get(p.id) ?? '',
    }));
  }

  return {
    list: enriched.map((p) => ({ ...p, user: publicUserView(p.user) })),
    pagination: { page, limit, total },
  };
}

// 搜索联想：历史关键词前缀（去重、按最近）+ 圈子标签前缀 + 帖子标题前缀，合并取前 limit
export async function suggestKeywords(keyword: string, limit: number = 8): Promise<string[]> {
  const kw = keyword.trim();
  if (kw.length === 0) {
    return [];
  }
  const cap = Math.max(1, Math.min(20, limit));
  const [history, tags, titles] = await Promise.all([
    prisma.searchHistory.findMany({
      where: { keyword: { startsWith: kw } },
      select: { keyword: true },
      distinct: ['keyword'],
      orderBy: { createdAt: 'desc' },
      take: cap,
    }),
    prisma.tag.findMany({
      where: { name: { startsWith: kw } },
      select: { name: true },
      take: cap,
    }),
    // 帖子标题前缀：本地联调库标签/历史稀少时，保证绝大多数输入都有联想词
    prisma.post.findMany({
      where: { title: { startsWith: kw } },
      select: { title: true },
      take: cap,
    }),
  ]);
  const seen = new Set<string>();
  const out: string[] = [];
  for (const h of history) {
    if (!seen.has(h.keyword)) {
      seen.add(h.keyword);
      out.push(h.keyword);
    }
  }
  for (const t of tags) {
    if (!seen.has(t.name)) {
      seen.add(t.name);
      out.push(t.name);
    }
  }
  for (const t of titles) {
    if (!seen.has(t.title)) {
      seen.add(t.title);
      out.push(t.title);
    }
  }
  return out.slice(0, cap);
}

// ===== @提及 用户检索（发帖 @ 选择器数据源） =====
export type MentionSearchScope = 'following' | 'all';

export interface MentionCandidate {
  id: number;
  nickname: string;
  avatar: string | null;
  bio: string | null;
}

// 提及候选公共过滤：封禁(status!=1)与已注销(deletedAt)不可被 @，避免 @ 到无效对象
/**
 * @提及面板用户检索：
 * - scope=following（默认，keyword 可为空）：返回我关注的人，按关注时间倒序
 * - scope=all（keyword 非空才有效）：全站按昵称模糊检索活跃用户
 * 均排除自己。
 */
export async function searchMentionUsers(
  meId: number,
  keyword: string,
  scope: MentionSearchScope = 'following',
  limit: number = 20
): Promise<MentionCandidate[]> {
  const kw = keyword.trim().slice(0, 32);
  const cap = Math.max(1, Math.min(30, Number(limit) || 20));

  if (scope === 'following') {
    const rows = await prisma.follow.findMany({
      where: { followerId: meId },
      orderBy: { createdAt: 'desc' },
      take: 200, // 放宽取数上限，昵称过滤后默认列表仍够展示
      select: { followingId: true },
    });
    const ids = rows.map((r: { followingId: number }) => r.followingId);
    if (ids.length === 0) {
      return [];
    }
    const where: Record<string, unknown> = {
      id: { in: ids },
      status: 1,
      deletedAt: null,
    };
    if (kw.length > 0) {
      where.nickname = { contains: kw };
    }
    const users = await prisma.user.findMany({
      where,
      select: { id: true, nickname: true, avatar: true, bio: true },
      take: cap,
    });
    // 维持关注时间顺序（后关注的在前）
    const order = new Map<number, number>();
    ids.forEach((id: number, index: number) => {
      order.set(id, index);
    });
    users.sort((a: { id: number }, b: { id: number }) =>
      (order.get(a.id) ?? 0) - (order.get(b.id) ?? 0));
    return users.slice(0, cap).map((u) => ({
      id: u.id,
      nickname: u.nickname,
      avatar: u.avatar,
      bio: u.bio,
    }));
  }

  if (kw.length === 0) {
    return [];
  }
  const users = await prisma.user.findMany({
    where: {
      status: 1,
      deletedAt: null,
      id: { not: meId },
      nickname: { contains: kw },
    },
    select: { id: true, nickname: true, avatar: true, bio: true },
    orderBy: { createdAt: 'desc' },
    take: cap,
  });
  return users.map((u) => ({
    id: u.id,
    nickname: u.nickname,
    avatar: u.avatar,
    bio: u.bio,
  }));
}
