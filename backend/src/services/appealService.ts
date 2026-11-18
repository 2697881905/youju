// 内容处置申诉服务：作者对被下架内容提交复核申请，管理员审核后恢复或驳回。
// 设计边界：申诉是「三道 UGC 防线」之后的复核出口，只加流程、不放宽审核——
// 审批通过时仍复用既有 resolveReportsByTarget，不新写内容状态变更逻辑。
// 分两步：先 dismissed 关闭 pending 举报（有 pending 且无 resolved 历史时会顺带恢复），
// 再检查内容状态；若仍下架（敏感词下架/历史 resolved/无举报记录）则走 restore 显式恢复。
import { prisma } from '../prisma';
import { ValidationError, ForbiddenError, NotFoundError } from '../utils/errors';
import { resolveReportsByTarget, type TargetType } from './reportService';

export type AppealStatus = 'pending' | 'approved' | 'rejected';

/** 可作为申诉目标的内容类型（用户封禁走别的流程，不在申诉范围） */
const APPEAL_TARGET_TYPES: string[] = ['post', 'comment'];
const PRISMA_UNIQUE_CONSTRAINT_CODE = 'P2002';
const MAX_REASON_LENGTH = 500;

export interface CreateAppealParams {
  authorId: number;
  targetType: TargetType;
  targetId: number;
  reason: string;
}

/**
 * 提交申诉。校验三件事：目标类型合法、内容是申诉人本人的、内容当前确被下架（status=0）。
 * 重复申诉由唯一索引兜底（P2002 → 友好错误），不做先查后插的竞态窗口。
 */
export async function createAppeal(params: CreateAppealParams): Promise<void> {
  if (APPEAL_TARGET_TYPES.indexOf(params.targetType) < 0) {
    throw new ValidationError('申诉目标类型无效');
  }
  const reason = (params.reason ?? '').trim();
  if (reason.length === 0 || reason.length > MAX_REASON_LENGTH) {
    throw new ValidationError('申诉理由须在 1–500 字之间');
  }

  let ownerId: number | null = null;
  let contentStatus: number | null = null;
  let reportCount: number = 0;
  if (params.targetType === 'post') {
    const post = await prisma.post.findUnique({
      where: { id: params.targetId },
      select: { userId: true, status: true, deletedAt: true, reportCount: true },
    });
    if (post && post.deletedAt === null) {
      ownerId = post.userId;
      contentStatus = post.status;
      reportCount = post.reportCount;
    }
  } else {
    const comment = await prisma.comment.findUnique({
      where: { id: params.targetId },
      select: { userId: true, status: true, reportCount: true },
    });
    if (comment) {
      ownerId = comment.userId;
      contentStatus = comment.status;
      reportCount = comment.reportCount;
    }
  }
  if (ownerId === null) {
    throw new NotFoundError('内容不存在或已删除');
  }
  if (ownerId !== params.authorId) {
    throw new ForbiddenError('只能申诉自己的内容');
  }
  // status=0 同时承担「待审核」与「被举报下架」两种语义（见 schema 注释）。
  // reportCount>0 才是被处置信号；否则作者拿待审核内容来申诉没有复核对象。
  if (contentStatus !== 0 || reportCount <= 0) {
    throw new ValidationError('仅被处置下架的内容可申诉');
  }

  try {
    await prisma.appeal.create({
      data: {
        targetType: params.targetType,
        targetId: params.targetId,
        authorId: params.authorId,
        reason,
      },
    });
  } catch (e: any) {
    if (e?.code === PRISMA_UNIQUE_CONSTRAINT_CODE) {
      throw new ValidationError('该内容已有申诉，请等待处理结果');
    }
    throw e;
  }
}

/** 用户查自己提交的申诉（按时间倒序） */
export async function listMyAppeals(authorId: number): Promise<any[]> {
  return prisma.appeal.findMany({
    where: { authorId },
    orderBy: { createdAt: 'desc' },
    take: 100,
  });
}

/** 管理端申诉列表（按状态过滤，待处理优先） */
export async function listAppeals(status?: AppealStatus): Promise<any[]> {
  return prisma.appeal.findMany({
    where: status ? { status } : undefined,
    orderBy: [{ status: 'asc' }, { createdAt: 'asc' }],
    take: 200,
  });
}

/** 读取内容当前状态；内容不存在时返回 null，供复核流程判断是否需要显式恢复。 */
async function readContentStatus(targetType: string, targetId: number): Promise<number | null> {
  if (targetType === 'post') {
    const post = await prisma.post.findUnique({
      where: { id: targetId },
      select: { status: true, deletedAt: true },
    });
    return post && post.deletedAt === null ? post.status : null;
  }
  if (targetType === 'comment') {
    const comment = await prisma.comment.findUnique({
      where: { id: targetId },
      select: { status: true },
    });
    return comment ? comment.status : null;
  }
  return null;
}

/**
 * 管理员复核申诉。
 * - approved：关闭相关 pending 举报；若内容仍下架则显式恢复（均复用 resolveReportsByTarget）。
 * - rejected：仅标记驳回，内容维持下架。
 * 幂等：已处理的申诉不允许二次复核。
 */
export async function reviewAppeal(
  appealId: number,
  reviewerId: number,
  decision: 'approved' | 'rejected',
  reviewNote?: string,
): Promise<void> {
  const appeal = await prisma.appeal.findUnique({ where: { id: appealId } });
  if (!appeal) {
    throw new NotFoundError('申诉不存在');
  }
  if (appeal.status !== 'pending') {
    throw new ValidationError('该申诉已处理');
  }
  const note = (reviewNote ?? '').trim().slice(0, MAX_REASON_LENGTH);

  if (decision === 'approved') {
    const targetType = appeal.targetType as TargetType;
    // 任一步失败都直接抛出，不标记 approved——避免「申诉通过但内容没恢复」的假状态。
    // dismissed 关闭 pending 举报；有 pending 且无 resolved 历史时它会顺带恢复内容。
    await resolveReportsByTarget(targetType, appeal.targetId, 'dismissed', note || '申诉复核通过');
    // 敏感词下架（无 Report）、历史 resolved 或举报已关闭但内容仍下架的情况，
    // 需要再走一次显式 restore。restore 要求无 pending，上一步已满足。
    if (await readContentStatus(appeal.targetType, appeal.targetId) === 0) {
      await resolveReportsByTarget(targetType, appeal.targetId, 'restore', note || '申诉复核通过');
    }
  }
  await prisma.appeal.update({
    where: { id: appealId },
    data: {
      status: decision,
      reviewedAt: new Date(),
      reviewerId,
      reviewNote: note || null,
    },
  });
}
