// 审核服务：待审帖子列表 + 审核操作（approve/reject）
// 审核通过/拒绝 → 通知作者具体结果；举报处理 → 举报人仅收"你的举报已处理"不透露结果
import { prisma } from '../prisma';
import {
  resolveReportsByTarget,
  getReporterIdsByTarget,
} from './reportService';
import { notifySystem } from './notificationService';

/**
 * 待审核帖子列表（status=0）。
 */
export async function listPendingPosts(
  page: number = 1,
  limit: number = 20
): Promise<{ list: any[]; pagination: { page: number; limit: number; total: number } }> {
  const p = Math.max(1, Number(page));
  const l = Math.min(50, Math.max(1, Number(limit)));
  const skip = (p - 1) * l;
  const where = { status: 0 };
  const [list, total] = await Promise.all([
    prisma.post.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip,
      take: l,
      include: {
        user: { select: { id: true, nickname: true, avatar: true } },
      },
    }),
    prisma.post.count({ where }),
  ]);

  // Report 与 Post 无 Prisma 关系（靠 targetType/targetId 标量关联），需单独批量查举报并挂回。
  const postIds = list.map((post) => post.id);
  const reports =
    postIds.length > 0
      ? await prisma.report.findMany({
          where: { targetType: 'post', targetId: { in: postIds } },
          orderBy: { createdAt: 'desc' },
        })
      : [];
  const reporterIds = Array.from(new Set(reports.map((r) => r.reporterId)));
  const reporters =
    reporterIds.length > 0
      ? await prisma.user.findMany({
          where: { id: { in: reporterIds } },
          select: { id: true, nickname: true },
        })
      : [];
  const nicknameById = new Map(reporters.map((u) => [u.id, u.nickname]));
  const reportsByPost = new Map<number, Array<Record<string, unknown>>>();
  for (const r of reports) {
    const arr = reportsByPost.get(r.targetId) ?? [];
    arr.push({ ...r, reporter: { nickname: nicknameById.get(r.reporterId) ?? null } });
    reportsByPost.set(r.targetId, arr);
  }
  const listWithReports = list.map((post) => ({
    ...post,
    reports: reportsByPost.get(post.id) ?? [],
  }));

  return { list: listWithReports, pagination: { page: p, limit: l, total } };
}

/**
 * 审核帖子。
 * action: 'approve' → status=1, reports → dismissed
 * action: 'reject'  → status=2, reports → resolved
 * 抛出错误：
 *   { reason: 'not_found' }      帖子不存在
 *   { reason: 'invalid_status' } 非待审状态
 */
export async function moderatePost(
  postId: number,
  action: 'approve' | 'reject',
  reason?: string
): Promise<void> {
  // 1. 查帖子，校验 status===0
  const post = await prisma.post.findUnique({
    where: { id: postId },
    select: { id: true, userId: true, title: true, status: true },
  });
  if (!post) {
    const err = new Error('帖子不存在');
    (err as any).reason = 'not_found';
    throw err;
  }
  if (post.status !== 0) {
    const err = new Error('该帖子不在待审核状态');
    (err as any).reason = 'invalid_status';
    throw err;
  }

  // 2. 更新帖子状态
  const newStatus = action === 'approve' ? 1 : 2;
  await prisma.post.update({
    where: { id: postId },
    data: { status: newStatus },
  });

  // 3. 批量处理举报记录
  const reportNewStatus = action === 'approve' ? 'dismissed' : 'resolved';
  await resolveReportsByTarget('post', postId, reportNewStatus);

  // 4. 通知作者审核结果
  if (action === 'approve') {
    await notifySystem(
      post.userId,
      `你的帖子《${post.title}》已通过审核`,
      postId
    );
  } else {
    const content = reason
      ? `你的帖子《${post.title}》未通过审核，原因：${reason}`
      : `你的帖子《${post.title}》未通过审核`;
    await notifySystem(post.userId, content, postId);
  }

  // 5. 通知所有举报人（不透露审核结果，统一告知"已处理"）
  const reporterIds = await getReporterIdsByTarget('post', postId);
  for (const reporterId of reporterIds) {
    if (reporterId !== post.userId) {
      await notifySystem(reporterId, '你的举报已处理', postId);
    }
  }
}
