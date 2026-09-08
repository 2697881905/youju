import { prisma } from '../prisma';
import { notifyOnComment, notifyOnCommentReply, notifyCommentMentions } from './notificationService';
import { bumpHotScore } from './hotScoreService';
import { sensitiveWordService } from './sensitiveWordService';
import { SensitiveWordError } from '../utils/errors';
import { ValidationError } from '../utils/errors';

// 扁平评论 → 楼中楼树：一级评论（parentId 为空）+ 每条下的全部后代回复（按时间升序）。
// 多层回复（回复子回复）会向上归一挂到所属一级评论下，楼中楼始终只展示一层嵌套；
// 父评论不在返回窗口内（如已删除/被截断）时该回复视作一级处理，避免孤儿丢失。
// flat 需已按一级评论展示顺序排好（如 upCount desc），取出一级评论时保持原顺序。
export function buildCommentTree<T extends { id?: number; parentId?: number | null; createdAt?: string | Date }>(flat: T[]): (T & { replies?: T[] })[] {
  const byId = new Map<number, T>();
  for (const c of flat) {
    if (c.id !== undefined) {
      byId.set(c.id, c);
    }
  }
  const rootIds = new Set<number>();
  for (const c of flat) {
    const pid = c.parentId;
    if (pid === undefined || pid === null || pid === 0) {
      if (c.id !== undefined) {
        rootIds.add(c.id);
      }
    }
  }
  // 向上找到所属的根评论 id；父链断裂（父不在窗口）时返回 null
  const rootOf = (c: T): number | null => {
    let pid = c.parentId ?? null;
    while (pid !== undefined && pid !== null && pid !== 0) {
      if (rootIds.has(pid)) {
        return pid;
      }
      const parent = byId.get(pid);
      if (!parent) {
        return null;
      }
      pid = parent.parentId ?? null;
    }
    return null;
  };
  const replyMap = new Map<number, T[]>();
  const roots: T[] = [];
  for (const c of flat) {
    const pid = c.parentId;
    if (pid === undefined || pid === null || pid === 0) {
      roots.push(c);
    } else {
      const rootId = rootOf(c) ?? pid;
      const arr = replyMap.get(rootId) ?? [];
      arr.push(c);
      replyMap.set(rootId, arr);
    }
  }
  for (const arr of replyMap.values()) {
    arr.sort((a, b) => String(a.createdAt).localeCompare(String(b.createdAt)));
  }
  return roots.map((r) => {
    const replies = r.id !== undefined ? (replyMap.get(r.id) ?? []) : [];
    return { ...r, replies };
  });
}

export async function listComments(postId: number, page = 1, limit = 50) {
  const skip = (page - 1) * limit;
  const where = { postId, status: 1 }; // 仅返回正常评论（隐藏被举报下架的）
  const [list, total] = await Promise.all([
    prisma.comment.findMany({
      where,
      orderBy: { upCount: 'desc' },
      skip,
      take: limit,
      include: { user: { select: { id: true, nickname: true, avatar: true } } },
    }),
    prisma.comment.count({ where }),
  ]);
  // 组装楼中楼树返回（分页按扁平列表切片后组树；total 保持原语义）
  return { list: buildCommentTree(list), pagination: { page, limit, total } };
}

export async function createComment(
  postId: number,
  userId: number,
  content: string,
  parentId?: number | null,
  isFact = 0
) {
  const text = content.trim();
  if (text.length === 0 || text.length > 2000) {
    throw new ValidationError('评论长度需在 1-2000 字');
  }
  let parentRef: { userId: number; postUserId: number } | null = null;
  if (parentId !== undefined && parentId !== null) {
    const parent = await prisma.comment.findUnique({
      where: { id: parentId },
      select: { postId: true, status: true, userId: true },
    });
    if (!parent || parent.postId !== postId || parent.status !== 1) {
      throw new ValidationError('父评论不存在或不属于当前帖子');
    }
    parentRef = { userId: parent.userId, postUserId: postId };
  }
  // 敏感词前置检测
  if (sensitiveWordService.checkText(text)) {
    throw new SensitiveWordError();
  }
  const [comment] = await prisma.$transaction([
    prisma.comment.create({
      data: { postId, userId, content: text, parentId: parentId ?? null, isFact },
    }),
    // 维护帖子评论数（与删除时 decrement 配对，避免评论数失真）
    prisma.post.update({ where: { id: postId }, data: { commentCount: { increment: 1 } } }),
  ]);
  // 触发通知：评论完成后通知帖子作者（自己评自己不发；失败不影响主流程）
  notifyOnComment(postId, userId).catch(() => {});
  // 楼中楼回复：额外通知被回复的评论作者（排除自己/帖子作者重复；失败不影响主流程）
  if (parentRef !== null) {
    notifyOnCommentReply(postId, userId, parentRef).catch(() => {});
  }
  // 评论内容 @提及：命中真实用户则通知（排除自己/帖子作者/被回复人等已通知对象）
  notifyCommentMentions(postId, userId, text, commentNotifyExcludes(userId, parentRef)).catch(() => {});
  // 评论数变化 → 热度信号增量更新
  bumpHotScore(postId).catch(() => {});
  return comment;
}

// @提及排除集：自己 + 帖子作者 + 被回复的评论作者（避免与 comment/reply 通知重复打扰）
function commentNotifyExcludes(actorId: number, parentRef: { userId: number; postUserId: number } | null): ReadonlySet<number> {
  const set = new Set<number>([actorId]);
  if (parentRef !== null) {
    set.add(parentRef.postUserId);
    set.add(parentRef.userId);
  }
  return set;
}

export async function deleteComment(id: number, userId: number) {
  const c = await prisma.comment.findUnique({ where: { id } });
  if (!c) return { ok: false, reason: 'not_found' };
  if (c.userId !== userId) return { ok: false, reason: 'forbidden' };
  // 楼中楼级联：找出该评论下的直接子回复，一并删除（含其顶/举报记录），避免孤儿回复悬挂
  const children = await prisma.comment.findMany({
    where: { parentId: id, status: 1 },
    select: { id: true },
  });
  const ids = [id, ...children.map((ch) => ch.id)];
  await prisma.$transaction([
    prisma.commentUp.deleteMany({ where: { commentId: { in: ids } } }),
    prisma.report.deleteMany({ where: { targetType: 'comment', targetId: { in: ids } } }),
    prisma.comment.deleteMany({ where: { id: { in: ids } } }),
    // 维护帖子评论数（与发布时 increment 配对，子回复一并扣减）
    prisma.post.update({ where: { id: c.postId }, data: { commentCount: { decrement: ids.length } } }),
  ]);
  return { ok: true };
}
