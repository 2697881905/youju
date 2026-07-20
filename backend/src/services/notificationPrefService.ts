// 通知偏好管理：用户可开关各类通知（comment/up/bookmark/follow/system），默认全开。
// 无记录时返回全 true 默认值（getPrefs）；写入走 upsert（updatePrefs）。
import { prisma } from '../prisma';

export interface NotificationPrefs {
  comment: boolean;
  up: boolean;
  bookmark: boolean;
  follow: boolean;
  system: boolean;
}

export const DEFAULT_PREFS: NotificationPrefs = {
  comment: true,
  up: true,
  bookmark: true,
  follow: true,
  system: true,
};

export async function getPrefs(userId: number): Promise<NotificationPrefs> {
  const row = await prisma.notificationPreference.findUnique({ where: { userId } });
  if (!row) return { ...DEFAULT_PREFS };
  return {
    comment: row.comment,
    up: row.up,
    bookmark: row.bookmark,
    follow: row.follow,
    system: row.system,
  };
}

export async function updatePrefs(userId: number, prefs: Partial<NotificationPrefs>): Promise<NotificationPrefs> {
  const data: Record<string, boolean> = {};
  if (prefs.comment !== undefined) data.comment = prefs.comment;
  if (prefs.up !== undefined) data.up = prefs.up;
  if (prefs.bookmark !== undefined) data.bookmark = prefs.bookmark;
  if (prefs.follow !== undefined) data.follow = prefs.follow;
  if (prefs.system !== undefined) data.system = prefs.system;
  const row = await prisma.notificationPreference.upsert({
    where: { userId },
    update: data,
    create: { userId, ...DEFAULT_PREFS, ...data },
  });
  return {
    comment: row.comment,
    up: row.up,
    bookmark: row.bookmark,
    follow: row.follow,
    system: row.system,
  };
}

// 给定类别，返回当前用户是否允许该类通知（不存在偏好记录时默认允许）
export async function isNotificationAllowed(userId: number, type: string): Promise<boolean> {
  const prefs = await getPrefs(userId);
  const key = type as keyof NotificationPrefs;
  if (key in prefs) return prefs[key];
  return true; // 未知类型默认允许
}
