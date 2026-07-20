// 隐私设置管理：用户可控制帖子可见性/允许关注/允许私信。
// MVP 仅实现 CRUD + UI 展示，可见性过滤 / follow 校验后续单独迭代。
import { prisma } from '../prisma';

export type PostVisibility = 'public' | 'followers' | 'private';

export interface PrivacySettingsData {
  postVisibility: PostVisibility;
  allowFollow: boolean;
  allowMessage: boolean;
}

const DEFAULTS: PrivacySettingsData = {
  postVisibility: 'public',
  allowFollow: true,
  allowMessage: true,
};

export async function getSettings(userId: number): Promise<PrivacySettingsData> {
  const row = await prisma.privacySettings.findUnique({ where: { userId } });
  if (!row) return { ...DEFAULTS };
  return {
    postVisibility: row.postVisibility as PostVisibility,
    allowFollow: row.allowFollow,
    allowMessage: row.allowMessage,
  };
}

export async function updateSettings(
  userId: number,
  settings: Partial<PrivacySettingsData>,
): Promise<PrivacySettingsData> {
  const data: Record<string, string | boolean> = {};
  if (settings.postVisibility !== undefined) data.postVisibility = settings.postVisibility;
  if (settings.allowFollow !== undefined) data.allowFollow = settings.allowFollow;
  if (settings.allowMessage !== undefined) data.allowMessage = settings.allowMessage;

  const row = await prisma.privacySettings.upsert({
    where: { userId },
    update: data,
    create: { userId, ...DEFAULTS, ...data },
  });
  return {
    postVisibility: row.postVisibility as PostVisibility,
    allowFollow: row.allowFollow,
    allowMessage: row.allowMessage,
  };
}
