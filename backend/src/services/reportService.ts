// 举报服务：创建举报（幂等 + 阈值触发自动下架）+ 查询 + 批量处理
import { prisma } from '../prisma';
import { notifySystem } from './notificationService';
import { env } from '../config/env';

export type TargetType = 'post' | 'comment';
export type ReportReason =
  | 'political'
  | 'pornographic'
  | 'personal_attack'
  | 'gender_war'
  | 'advertisement'
  | 'spam'
  | 'other';

export interface CreateReportParams {
  reporterId: number;
  targetType: TargetType;
  targetId: number;
  reason: ReportReason;
  description?: string;
}

// Prisma unique 约束冲突错误码（P2002）
const PRISMA_UNIQUE_CONSTRAINT_CODE = 'P2002';

/**
 * 创建举报（幂等：同一用户同一内容仅一次）。
 * 抛出错误：
 *   { reason: 'conflict' }   重复举报
 *   { reason: 'not_found' }  目标不存在
 */
export async function createReport(
  params: CreateReportParams
): Promise<{ report: any; autoTakenDown: boolean }> {
  // 1. 校验 reason='other' 时 description 必填
  if (params.reason === 'other' && (!params.description || !params.description.trim())) {
    const err = new Error('请填写补充说明');
    (err as any).reason = 'validation';
    throw err;
  }

  // 2. 校验目标是否存在
  let targetExists = false;
  let targetUserId = 0;
  let targetTitle = '';

  if (params.targetType === 'post') {
    const post = await prisma.post.findUnique({
      where: { id: params.targetId },
      select: { id: true, userId: true, title: true },
    });
    if (!post) {
      const err = new Error('帖子不存在');
      (err as any).reason = 'not_found';
      throw err;
    }
    targetExists = true;
    targetUserId = post.userId;
    targetTitle = post.title;
  } else {
    const comment = await prisma.comment.findUnique({
      where: { id: params.targetId },
      select: { id: true, userId: true, content: true },
    });
    if (!comment) {
      const err = new Error('评论不存在');
      (err as any).reason = 'not_found';
      throw err;
    }
    targetExists = true;
    targetUserId = comment.userId;
  }

  // 3. 创建举报记录（unique 约束冲突 → 抛 conflict）
  let report: any;
  try {
    report = await prisma.report.create({
      data: {
        reporterId: params.reporterId,
        targetType: params.targetType,
        targetId: params.targetId,
        reason: params.reason,
        description: params.description?.trim() || null,
        status: 'pending',
      },
    });
  } catch (e: any) {
    if (e.code === PRISMA_UNIQUE_CONSTRAINT_CODE) {
      const err = new Error('你已举报过该内容');
      (err as any).reason = 'conflict';
      throw err;
    }
    throw e;
  }

  // 4. 递增目标 reportCount
  let newReportCount = 0;
  if (params.targetType === 'post') {
    const updated = await prisma.post.update({
      where: { id: params.targetId },
      data: { reportCount: { increment: 1 } },
      select: { reportCount: true, status: true },
    });
    newReportCount = updated.reportCount;
  } else {
    const updated = await prisma.comment.update({
      where: { id: params.targetId },
      data: { reportCount: { increment: 1 } },
      select: { reportCount: true, status: true },
    });
    newReportCount = updated.reportCount;
  }

  // 5. 判断 reportCount >= 阈值 → 自动下架 status=0 + notifySystem 通知作者
  const threshold = env.reportThreshold > 0 ? env.reportThreshold : 3;
  if (newReportCount >= threshold) {
    if (params.targetType === 'post') {
      await prisma.post.update({
        where: { id: params.targetId },
        data: { status: 0 },
      });
      await notifySystem(
        targetUserId,
        `你的帖子《${targetTitle}》因被举报正在审核中`,
        params.targetId
      );
    } else {
      await prisma.comment.update({
        where: { id: params.targetId },
        data: { status: 0 },
      });
      await notifySystem(
        targetUserId,
        '你的评论因被举报正在审核中',
        null
      );
    }
    return { report, autoTakenDown: true };
  }

  return { report, autoTakenDown: false };
}

/**
 * 按目标查询举报记录（供审核使用）。
 */
export async function listReportsByTarget(
  targetType: TargetType,
  targetId: number
): Promise<any[]> {
  return prisma.report.findMany({
    where: { targetType, targetId },
    orderBy: { createdAt: 'desc' },
  });
}

/**
 * 批量更新某目标的所有 pending 举报状态（审核时调用）。
 * newStatus: 'resolved'（举报成立） | 'dismissed'（举报驳回）
 */
export async function resolveReportsByTarget(
  targetType: TargetType,
  targetId: number,
  newStatus: 'resolved' | 'dismissed'
): Promise<void> {
  await prisma.report.updateMany({
    where: { targetType, targetId, status: 'pending' },
    data: { status: newStatus, resolvedAt: new Date() },
  });
}

/**
 * 获取某目标的所有举报人 ID（用于审核后通知举报人）。
 */
export async function getReporterIdsByTarget(
  targetType: TargetType,
  targetId: number
): Promise<number[]> {
  const reports = await prisma.report.findMany({
    where: { targetType, targetId },
    select: { reporterId: true },
  });
  return reports.map((r) => r.reporterId);
}

/**
 * 举报记录分页列表（供 admin 审核队列查看）。
 */
export async function listReports(
  page: number = 1,
  limit: number = 20,
  status?: string
): Promise<{ list: any[]; pagination: { page: number; limit: number; total: number } }> {
  const p = Math.max(1, Number(page));
  const l = Math.min(50, Math.max(1, Number(limit)));
  const skip = (p - 1) * l;
  const where: any = status ? { status } : {};
  const [list, total] = await Promise.all([
    prisma.report.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip,
      take: l,
    }),
    prisma.report.count({ where }),
  ]);
  return { list, pagination: { page: p, limit: l, total } };
}
