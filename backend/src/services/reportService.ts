// 举报服务：创建举报（幂等 + 阈值触发自动下架）+ 查询 + 批量处理
import { prisma } from '../prisma';
import { notifySystem } from './notificationService';
import { notifyNewReport } from './opsNotifier';
import { env } from '../config/env';

export type TargetType = 'post' | 'comment' | 'user';
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

// 「举报中心」固定置顶消息前缀：所有新举报收敛为管理员消息中心的一条固定置顶通知，
// 已存在则更新内容（最新待处理数）并重置未读，避免每条举报都刷一条新消息。
const ADMIN_REPORT_CENTER_PREFIX = '举报中心';

/**
 * 幂等更新/创建管理员的「举报中心」置顶通知。
 * - 已存在（content 以「举报中心」前缀开头的置顶系统消息）：更新内容（最新待处理数）
 * - 不存在：有待处理举报时才创建（无待办时不造一条空提醒）
 *
 * markUnread 语义：
 * - true（仅新举报产生）：重置未读，点亮红点提醒管理员
 * - false（处置回写）：不重新点亮；待处理清零时顺手熄灭红点（无待办即无提醒）
 */
export async function upsertAdminReportCenter(
  adminId: number,
  pendingCount: number,
  markUnread: boolean = true
): Promise<void> {
  const content = pendingCount > 0
    ? `${ADMIN_REPORT_CENTER_PREFIX}：有 ${pendingCount} 条举报待处理`
    : `${ADMIN_REPORT_CENTER_PREFIX}：暂无待处理举报`;
  const readFlag: boolean | undefined = markUnread ? false : (pendingCount === 0 ? true : undefined);
  const existing = await prisma.notification.findFirst({
    where: { userId: adminId, type: 'system', pinned: true, content: { startsWith: ADMIN_REPORT_CENTER_PREFIX } },
    orderBy: { createdAt: 'desc' },
  });
  if (existing) {
    const data: Record<string, unknown> = { content, pinned: true };
    if (readFlag !== undefined) {
      data.read = readFlag;
    }
    await prisma.notification.update({ where: { id: existing.id }, data });
    return;
  }
  if (pendingCount > 0) {
    await notifySystem(adminId, content, null, true);
  }
}

/**
 * 把每个管理员的「举报中心」置顶消息同步到当前真实待处理数。
 * - 新举报产生：markUnread=true（createReport 调用）
 * - 处置回写（举报成立/驳回、内容审核通过/驳回）：markUnread=false
 *   —— 否则会出现「举报都处理完了，消息中心还挂着有 N 条待处理」的旧文案（用户报障）。
 */
export async function syncAdminReportCenter(markUnread: boolean = false): Promise<void> {
  const pending: number = await prisma.report.count({ where: { status: 'pending' } });
  for (const adminId of env.adminUserIds) {
    await upsertAdminReportCenter(adminId, pending, markUnread).catch(() => {});
  }
}

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
  // 评论目标的所属帖子 id：评论类系统通知带上「帖子 + 评论」以便点击精准定位
  let targetCommentPostId: number | null = null;

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
  } else if (params.targetType === 'user') {
    // 举报用户（聊天/私信骚扰等场景）：只落举报记录，不做自动下架
    const user = await prisma.user.findUnique({
      where: { id: params.targetId },
      select: { id: true },
    });
    if (!user) {
      const err = new Error('用户不存在');
      (err as any).reason = 'not_found';
      throw err;
    }
    targetExists = true;
    targetUserId = user.id;
  } else {
    const comment = await prisma.comment.findUnique({
      where: { id: params.targetId },
      select: { id: true, userId: true, content: true, postId: true },
    });
    if (!comment) {
      const err = new Error('评论不存在');
      (err as any).reason = 'not_found';
      throw err;
    }
    targetExists = true;
    targetUserId = comment.userId;
    targetCommentPostId = comment.postId;
  }

  // 3. 创建举报、递增计数与自动下架必须原子完成，避免留下不可重试的半状态。
  const threshold = env.reportThreshold > 0 ? env.reportThreshold : 3;
  let transactionResult: { report: any; autoTakenDown: boolean; reportCount: number };
  try {
    transactionResult = await prisma.$transaction(async (tx) => {
      const report = await tx.report.create({
        data: {
          reporterId: params.reporterId,
          targetType: params.targetType,
          targetId: params.targetId,
          reason: params.reason,
          description: params.description?.trim() || null,
          status: 'pending',
        },
      });

      let newReportCount = 0;
      if (params.targetType === 'post') {
        const updated = await tx.post.update({
          where: { id: params.targetId },
          data: { reportCount: { increment: 1 } },
          select: { reportCount: true },
        });
        newReportCount = updated.reportCount;
        if (newReportCount >= threshold) {
          await tx.post.update({ where: { id: params.targetId }, data: { status: 0 } });
        }
      } else if (params.targetType === 'comment') {
        const updated = await tx.comment.update({
          where: { id: params.targetId },
          data: { reportCount: { increment: 1 } },
          select: { reportCount: true },
        });
        newReportCount = updated.reportCount;
        if (newReportCount >= threshold) {
          await tx.comment.update({ where: { id: params.targetId }, data: { status: 0 } });
        }
      }
      // targetType==='user'：仅上面已创建举报记录，无计数/下架逻辑
      return { report, autoTakenDown: newReportCount >= threshold, reportCount: newReportCount };
    });
  } catch (e: any) {
    if (e.code === PRISMA_UNIQUE_CONSTRAINT_CODE) {
      const err = new Error('你已举报过该内容');
      (err as any).reason = 'conflict';
      throw err;
    }
    throw e;
  }

  // 4. 通知属于事务后的外部副作用，失败不反向破坏已提交的举报状态。
  // 4a. 运营侧：出现新举报（pending 记录）即推送飞书群机器人；不 await，绝不阻断主流程。
  void notifyNewReport({
    reportId: transactionResult.report.id,
    targetType: params.targetType,
    targetId: params.targetId,
    reason: params.reason,
    description: params.description,
    targetTitle: params.targetType === 'post' ? targetTitle : undefined,
    reportCount: transactionResult.reportCount > 0 ? transactionResult.reportCount : undefined,
    autoTakenDown: transactionResult.autoTakenDown,
  }).catch(() => {});

  // 4b. 举报通知推送管理员（运营处置入口）：统一收敛为每个管理员一条固定置顶的
  // 「举报中心」消息（存在则更新内容+重置未读），不再每条举报逐条刷屏。普通举报人/作者
  // 不收到「受理回执」。
  await syncAdminReportCenter(true);

  // 4c. 举报达到阈值自动下架 → 通知内容作者（置顶，告知审核状态）。
  if (transactionResult.autoTakenDown) {
    if (params.targetType === 'post') {
      await notifySystem(
        targetUserId,
        `你的帖子《${targetTitle}》因被举报正在审核中`,
        params.targetId,
        true
      ).catch(() => {});
    } else {
      // 评论类：带「所属帖子 + 评论 id」，点击通知可精准定位到该评论（下架态不可见时退回帖子顶部）
      await notifySystem(
        targetUserId,
        '你的评论因被举报正在审核中',
        targetCommentPostId,
        true,
        params.targetId
      ).catch(() => {});
    }
  }
  return transactionResult;
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
 * 处置台统一入口：对某目标执行一次裁决（举报状态 + 内容状态 + 通知，一次性闭环）。
 *
 * action 语义：
 * - 'resolved'  成立并下架：pending 举报 → resolved；内容 status → 0（保持「下架」状态，
 *               不写 2，待处置/已处置的表达由举报状态承担）；通知作者「未通过审核（原因）」。
 * - 'dismissed' 驳回举报：pending 举报 → dismissed；内容若因举报被下架（status=0）则一并恢复为 1
 *               （修「驳回后内容滞留在审核台」），确实恢复时通知作者「已通过审核」。
 * - 'restore'   改判/误封恢复：仅把内容 0 → 1 + 通知作者「已通过审核」；不改举报状态、
 *               不通知举报人。仅 post/comment 目标、且无 pending 举报、且当前确实处于下架态时可用。
 *
 * 错误：{ reason: 'not_found' | 'has_pending' | 'not_taken_down' | 'invalid_target' }
 * 通知都是事务后的外部副作用，失败不阻断已完成的处置。
 */
export async function resolveReportsByTarget(
  targetType: TargetType,
  targetId: number,
  action: 'resolved' | 'dismissed' | 'restore',
  reason?: string
): Promise<void> {
  const outcome = await prisma.$transaction(async (tx) => {
    // 1. 目标快照：既是处置对象，也是通知文案与 postId 挂载的来源
    let authorId = 0;
    let title = '';
    let notifyPostId: number | null = null;
    // 评论目标的评论 id：系统通知带上「帖子 + 评论」，点击精准定位到该条评论
    let notifyCommentId: number | null = null;
    let isContent = false;
    let contentStatus = 1;
    if (targetType === 'post') {
      const post = await tx.post.findUnique({
        where: { id: targetId },
        select: { id: true, userId: true, title: true, status: true },
      });
      if (!post) {
        const err = new Error('目标内容不存在');
        (err as any).reason = 'not_found';
        throw err;
      }
      authorId = post.userId;
      title = post.title;
      notifyPostId = post.id;
      isContent = true;
      contentStatus = post.status;
    } else if (targetType === 'comment') {
      const comment = await tx.comment.findUnique({
        where: { id: targetId },
        select: { id: true, userId: true, postId: true, status: true },
      });
      if (!comment) {
        const err = new Error('目标内容不存在');
        (err as any).reason = 'not_found';
        throw err;
      }
      authorId = comment.userId ?? 0;
      notifyPostId = comment.postId;
      notifyCommentId = comment.id;
      isContent = true;
      contentStatus = comment.status;
    } else {
      const user = await tx.user.findUnique({ where: { id: targetId }, select: { id: true } });
      if (!user) {
        const err = new Error('目标用户不存在');
        (err as any).reason = 'not_found';
        throw err;
      }
    }

    let restored = false;
    if (action === 'restore') {
      if (!isContent) {
        const err = new Error('用户举报不支持该操作');
        (err as any).reason = 'invalid_target';
        throw err;
      }
      const pending = await tx.report.count({ where: { targetType, targetId, status: 'pending' } });
      if (pending > 0) {
        const err = new Error('该内容仍有待处理举报，请先处置举报');
        (err as any).reason = 'has_pending';
        throw err;
      }
      if (contentStatus !== 0) {
        const err = new Error('该内容当前未下架，无需恢复');
        (err as any).reason = 'not_taken_down';
        throw err;
      }
      const res =
        targetType === 'post'
          ? await tx.post.updateMany({ where: { id: targetId, status: 0 }, data: { status: 1 } })
          : await tx.comment.updateMany({ where: { id: targetId, status: 0 }, data: { status: 1 } });
      restored = res.count > 0;
      if (!restored) {
        // 并发下已被其他处置恢复（快照与更新之间的竞态兜底）
        const err = new Error('该内容当前未下架，无需恢复');
        (err as any).reason = 'not_taken_down';
        throw err;
      }
    } else {
      const newStatus: 'resolved' | 'dismissed' = action === 'resolved' ? 'resolved' : 'dismissed';
      await tx.report.updateMany({
        where: { targetType, targetId, status: 'pending' },
        data: { status: newStatus, resolvedAt: new Date() },
      });
      if (isContent) {
        if (action === 'resolved') {
          // 成立即下架，与 createReport 阈值自动下架保持一致
          if (targetType === 'post') {
            await tx.post.updateMany({ where: { id: targetId }, data: { status: 0 } });
          } else {
            await tx.comment.updateMany({ where: { id: targetId }, data: { status: 0 } });
          }
        } else if (contentStatus === 0) {
          // 驳回：内容因举报被下架时一并恢复（否则会滞留在处置台之外、无入口可恢复）
          const res =
            targetType === 'post'
              ? await tx.post.updateMany({ where: { id: targetId, status: 0 }, data: { status: 1 } })
              : await tx.comment.updateMany({ where: { id: targetId, status: 0 }, data: { status: 1 } });
          restored = res.count > 0;
        }
      }
    }

    const reporterRows = await tx.report.findMany({
      where: { targetType, targetId },
      select: { reporterId: true },
    });
    return {
      authorId,
      title,
      notifyPostId,
      notifyCommentId,
      isContent,
      restored,
      reporterIds: reporterRows.map((r) => r.reporterId),
    };
  });

  // 2. 事务后副作用（失败不阻断已完成的处置）
  // 2a. 作者：成立 → 未通过审核（带原因）；驳回/改判且确实恢复 → 已通过审核
  if (outcome.isContent && outcome.authorId > 0) {
    const trimmedReason: string = (reason ?? '').trim();
    if (action === 'resolved') {
      const base = targetType === 'post' ? `你的帖子《${outcome.title}》未通过审核` : '你的评论未通过审核';
      const content = trimmedReason.length > 0 ? `${base}，原因：${trimmedReason}` : base;
      await notifySystem(outcome.authorId, content, outcome.notifyPostId, undefined, outcome.notifyCommentId).catch(() => {});
    } else if (outcome.restored) {
      const content = targetType === 'post' ? `你的帖子《${outcome.title}》已通过审核` : '你的评论已通过审核';
      await notifySystem(outcome.authorId, content, outcome.notifyPostId, undefined, outcome.notifyCommentId).catch(() => {});
    }
  }
  // 2b. 举报人：成立/驳回都告知「已处理」（不透露结论）；restore 不涉及举报流转 → 不发；
  //     排除作者本人（自举报场景不重复打扰）
  if (action !== 'restore') {
    for (const rid of outcome.reporterIds) {
      if (rid === outcome.authorId) {
        continue;
      }
      await notifySystem(rid, '你的举报已处理', outcome.notifyPostId, undefined, outcome.notifyCommentId).catch(() => {});
    }
  }

  // 3. 举报状态已流转 → 同步管理员的「举报中心」待处理数（不重置未读；清零时熄灭红点）。
  // 缺了这一步，消息中心的「有 N 条举报待处理」会停在上次新举报时的数字（用户报障）。
  await syncAdminReportCenter().catch(() => {});
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
 * 举报记录分页列表（供 admin 处置台查看）。
 * 返回附带举报人昵称、目标摘要（帖子标题/评论内容/用户昵称）+ 目标内容当前状态
 * （targetStatus：post/comment 的 status，user 为 null）+ 作者信息（author*，user 目标即自身），
 * 供前台举报中心直接渲染处置决策（驳回并恢复 / 成立并下架 / 封禁作者）。
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
  if (list.length === 0) {
    return { list: [], pagination: { page: p, limit: l, total } };
  }

  // 举报人昵称
  const reporterIds = Array.from(new Set(list.map((r) => r.reporterId)));
  const reporters = await prisma.user.findMany({
    where: { id: { in: reporterIds } },
    select: { id: true, nickname: true },
  });
  const nicknameById = new Map(reporters.map((u) => [u.id, u.nickname]));

  // 目标摘要（帖子标题 / 评论内容 / 用户昵称+封禁状态）+ 内容状态与作者
  const postIds = list.filter((r) => r.targetType === 'post').map((r) => r.targetId);
  const commentIds = list.filter((r) => r.targetType === 'comment').map((r) => r.targetId);
  const userIds = list.filter((r) => r.targetType === 'user').map((r) => r.targetId);
  const [posts, comments, users] = await Promise.all([
    postIds.length > 0
      ? prisma.post.findMany({
          where: { id: { in: postIds } },
          select: { id: true, title: true, status: true, userId: true },
        })
      : Promise.resolve([]),
    commentIds.length > 0
      ? prisma.comment.findMany({
          where: { id: { in: commentIds } },
          select: { id: true, content: true, postId: true, status: true, userId: true },
        })
      : Promise.resolve([]),
    userIds.length > 0
      ? prisma.user.findMany({
          where: { id: { in: userIds } },
          select: { id: true, nickname: true, avatar: true, status: true },
        })
      : Promise.resolve([]),
  ]);
  const postById = new Map(posts.map((post) => [post.id, post]));
  const commentById = new Map(comments.map((c) => [c.id, c]));
  const userById = new Map(users.map((u) => [u.id, u]));

  // 内容作者（post/comment 目标）：批量查一次昵称/头像/封禁态，供卡片上「封禁/解封作者」
  const contentAuthorIds: number[] = [];
  for (const post of posts) {
    if (post.userId !== null && post.userId !== undefined && contentAuthorIds.indexOf(post.userId) < 0) {
      contentAuthorIds.push(post.userId);
    }
  }
  for (const c of comments) {
    if (c.userId !== null && c.userId !== undefined && contentAuthorIds.indexOf(c.userId) < 0) {
      contentAuthorIds.push(c.userId);
    }
  }
  const contentAuthors =
    contentAuthorIds.length > 0
      ? await prisma.user.findMany({
          where: { id: { in: contentAuthorIds } },
          select: { id: true, nickname: true, avatar: true, status: true },
        })
      : [];
  // authorById：内容作者 + 用户目标自身（后者直接复用已查到的 users 行）
  const authorById = new Map<number, { id: number; nickname: string | null; avatar: string | null; status: number }>();
  for (const u of contentAuthors) {
    authorById.set(u.id, u);
  }
  for (const u of users) {
    authorById.set(u.id, u);
  }

  return {
    list: list.map((r) => {
      const post = r.targetType === 'post' ? postById.get(r.targetId) : undefined;
      const comment = r.targetType === 'comment' ? commentById.get(r.targetId) : undefined;
      const targetUser = r.targetType === 'user' ? userById.get(r.targetId) : undefined;
      // 目标所属帖子（评论目标需要定位其所属帖才能跳转查看上下文）
      let targetPostId: number | null = null;
      if (r.targetType === 'post') {
        targetPostId = r.targetId;
      } else if (r.targetType === 'comment') {
        targetPostId = comment ? comment.postId : null;
      }
      // 作者：user 目标即自身；post/comment 取内容作者（内容被删/作者注销时可能取不到）
      const authorId: number | null =
        r.targetType === 'user'
          ? r.targetId
          : r.targetType === 'post'
            ? post?.userId ?? null
            : comment?.userId ?? null;
      const author = authorId !== null ? authorById.get(authorId) : undefined;
      return {
        ...r,
        reporter: { nickname: nicknameById.get(r.reporterId) ?? null },
        postTitle: post ? post.title : null,
        commentContent: comment ? comment.content : null,
        targetNickname: targetUser ? targetUser.nickname : null,
        targetBanned: targetUser ? targetUser.status === 0 : null,
        // 目标内容当前状态（post/comment）；user 目标无内容 → null
        targetStatus: post ? post.status : comment ? comment.status : null,
        authorId,
        authorNickname: author ? author.nickname : null,
        authorAvatar: author ? author.avatar : null,
        authorBanned: author ? author.status === 0 : null,
        targetPostId,
      };
    }),
    pagination: { page: p, limit: l, total },
  };
}
