import { Prisma } from '@prisma/client';

// 已注销用户的统一匿名昵称（与 authService.DELETED_NICKNAME 保持一致）。
// 因 schema 中 User.nickname 无 @@unique 约束，可直接赋固定串而无唯一冲突。
export const DELETED_NICKNAME = '已注销用户';

// 公开用户信息 select（含 deletedAt 供序列化层判断软删状态）。
export const USER_PUBLIC_SELECT = {
  id: true,
  nickname: true,
  avatar: true,
  deletedAt: true,
} satisfies Prisma.UserSelect;

// 序列化后的公开用户视图（前端消费，不含 deletedAt 原始字段）。
export interface PublicUserView {
  id: number;
  nickname: string;
  avatar: string | null;
  deleted?: boolean;
}

// 将任意含 user 字段的返回体转为公开视图：已注销则匿名化（昵称固定、头像清空、deleted=true）。
export function publicUserView(
  u: { id: number; nickname: string; avatar: string | null; deletedAt?: Date | null } | null | undefined,
): PublicUserView | null {
  if (!u) {
    return null;
  }
  if (u.deletedAt) {
    return { id: u.id, nickname: DELETED_NICKNAME, avatar: null, deleted: true };
  }
  return { id: u.id, nickname: u.nickname, avatar: u.avatar };
}
