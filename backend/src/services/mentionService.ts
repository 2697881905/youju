import { prisma } from '../prisma';

// ===== 全站 @提及 解析公共件 =====
// 帖子正文、评论正文的 @提及 统一走这里：
// - 显式列表（编辑器选择，精确到 userId）优先，服务端校验「用户真实存在且状态正常、昵称与 @name 一致、
//   文本确实含对应 @昵称」，从根本上规避重名昵称歧义；
// - 显式缺失/全无效时回退按昵称解析（兼容纯手输 @昵称 场景）。

export interface MentionRef {
  name: string;
  userId: number;
}

// @昵称 提取正则（与前端 textHighlight / utils/atMention 同口径：2-20 字，不含空白与常见标点）
export const MENTION_RE = /@([^@\s，。！？、；：""''《》（）【】]{2,20})/g;

// 提取文本中全部 @提及 昵称（去重、保留首次出现顺序）
export function extractMentionNames(content: string): string[] {
  const names: string[] = [];
  const seen = new Set<string>();
  MENTION_RE.lastIndex = 0;
  let m: RegExpExecArray | null;
  while ((m = MENTION_RE.exec(content)) !== null) {
    const name = m[1];
    if (!seen.has(name)) {
      seen.add(name);
      names.push(name);
    }
  }
  return names;
}

// 按昵称解析（回退路径）：命中真实用户（status=1 未注销），重名时取「先入库者」——该路径仅兜底手输场景
async function resolveByNickname(content: string): Promise<MentionRef[]> {
  const names = extractMentionNames(content);
  if (names.length === 0) {
    return [];
  }
  const users = await prisma.user.findMany({
    where: { nickname: { in: names }, status: 1, deletedAt: null },
    select: { id: true, nickname: true },
  });
  const byName = new Map<string, number>();
  for (const u of users) {
    if (!byName.has(u.nickname)) {
      byName.set(u.nickname, u.id);
    }
  }
  const result: MentionRef[] = [];
  for (const name of names) {
    const uid = byName.get(name);
    if (uid !== undefined) {
      result.push({ name, userId: uid });
    }
  }
  return result;
}

/**
 * 生成入库/通知用的 @提及 映射：
 * - 显式列表（编辑器选择，精确 userId）优先：逐项校验后在文本中出现的保留；
 * - 显式未覆盖的手工 @昵称 按昵称解析补全，避免手工提及丢失；
 * - 显式缺失或全部无效时整体回退为按昵称解析。
 * 目标用户一律要求 status=1（正常）且未注销。
 */
export async function resolveMentionRefs(
  content: string | undefined | null,
  explicit: unknown
): Promise<MentionRef[]> {
  if (!content || content.trim().length === 0) {
    return [];
  }
  if (!Array.isArray(explicit) || explicit.length === 0) {
    return resolveByNickname(content);
  }
  const picked: MentionRef[] = [];
  const seenUserId = new Set<number>();
  for (const item of explicit) {
    if (typeof item !== 'object' || item === null) {
      continue;
    }
    const rec = item as Record<string, unknown>;
    const name = rec.name;
    const userId = rec.userId;
    if (typeof name !== 'string' || name.length < 2 || name.length > 20) {
      continue;
    }
    if (typeof userId !== 'number' || !Number.isFinite(userId) || userId <= 0) {
      continue;
    }
    if (seenUserId.has(userId)) {
      continue;
    }
    if (content.indexOf('@' + name) < 0) {
      continue; // 文本中已不含该 @，丢弃过期选择
    }
    seenUserId.add(userId);
    picked.push({ name, userId });
  }
  if (picked.length === 0) {
    return resolveByNickname(content);
  }
  const rows = await prisma.user.findMany({
    where: { id: { in: Array.from(seenUserId) }, status: 1, deletedAt: null },
    select: { id: true, nickname: true },
  });
  const nickById = new Map<number, string>();
  for (const u of rows) {
    nickById.set(u.id, u.nickname);
  }
  const verified: MentionRef[] = [];
  for (const p of picked) {
    if (nickById.get(p.userId) === p.name) {
      verified.push(p);
    }
  }
  if (verified.length === 0) {
    return resolveByNickname(content);
  }
  // 显式选择未覆盖的其它手工输入 @昵称 按昵称解析补全，避免映射丢失。
  // 关键：已被显式选择覆盖的 @name（用户从面板点选、以 userId 为准）不再回退按昵称解析，
  // 否则同名的「库中首人」会被错误并入，重名精确性失效。
  const resolved = await resolveByNickname(content);
  const merged: MentionRef[] = verified.slice();
  const haveNames = new Set<string>();
  for (const v of verified) {
    haveNames.add(v.name);
  }
  for (const r of resolved) {
    if (!haveNames.has(r.name)) {
      haveNames.add(r.name);
      merged.push(r);
    }
  }
  return merged;
}
