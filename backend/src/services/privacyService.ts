// 隐私设置管理：用户可控制帖子可见性/允许关注/谁可发私信。
// MVP 仅实现 CRUD + UI 展示，可见性过滤 / follow 校验后续单独迭代。
import { prisma } from '../prisma';
import { ValidationError } from '../utils/errors';

export type PostVisibility = 'public' | 'followers' | 'private';
export type DmPolicy = 'all' | 'mutual' | 'followers';

export interface PrivacySettingsData {
  postVisibility: PostVisibility;
  allowFollow: boolean;
  dmPolicy: DmPolicy;
  // 是否接收个性化推荐：关闭后不再构建画像，每日一贴降级为「热度 + 时间」排序。
  personalizedRecommendation: boolean;
}

const DEFAULTS: PrivacySettingsData = {
  postVisibility: 'public',
  allowFollow: true,
  dmPolicy: 'all',
  personalizedRecommendation: true,
};

export async function getSettings(userId: number): Promise<PrivacySettingsData> {
  const row = await prisma.privacySettings.findUnique({ where: { userId } });
  if (!row) return { ...DEFAULTS };
  return {
    postVisibility: row.postVisibility as PostVisibility,
    allowFollow: row.allowFollow,
    dmPolicy: (row.dmPolicy as DmPolicy) ?? 'all',
    personalizedRecommendation: row.personalizedRecommendation,
  };
}

/**
 * 用户是否接收个性化推荐（默认开启）。
 * 读取失败按「开启」处理并告警：列表接口不应因设置表异常而不可用；
 * 且失败时保持与历史行为一致（历史上无此开关，等同开启）。
 */
export async function isPersonalizationEnabled(userId?: number): Promise<boolean> {
  if (!userId) {
    return true; // 游客无个人画像可言，走既有的非个性化路径
  }
  try {
    const row = await prisma.privacySettings.findUnique({
      where: { userId },
      select: { personalizedRecommendation: true },
    });
    return row ? row.personalizedRecommendation : true;
  } catch (e) {
    console.warn('[privacy] 读取个性化推荐开关失败，按开启处理：', (e as Error).message);
    return true;
  }
}

export async function updateSettings(
  userId: number,
  settings: Partial<PrivacySettingsData>,
): Promise<PrivacySettingsData> {
  const data: Record<string, string | boolean> = {};
  if (settings.postVisibility !== undefined) {
    if (!['public', 'followers', 'private'].includes(settings.postVisibility)) {
      throw new ValidationError('postVisibility 参数无效');
    }
    data.postVisibility = settings.postVisibility;
  }
  if (settings.allowFollow !== undefined) {
    if (typeof settings.allowFollow !== 'boolean') {
      throw new ValidationError('allowFollow 必须为布尔值');
    }
    data.allowFollow = settings.allowFollow;
  }
  if (settings.dmPolicy !== undefined) {
    if (!['all', 'mutual', 'followers'].includes(settings.dmPolicy)) {
      throw new ValidationError('dmPolicy 参数无效');
    }
    data.dmPolicy = settings.dmPolicy;
  }
  if (settings.personalizedRecommendation !== undefined) {
    if (typeof settings.personalizedRecommendation !== 'boolean') {
      throw new ValidationError('personalizedRecommendation 必须为布尔值');
    }
    data.personalizedRecommendation = settings.personalizedRecommendation;
  }

  const row = await prisma.privacySettings.upsert({
    where: { userId },
    update: data,
    create: { userId, ...DEFAULTS, ...data },
  });
  return {
    postVisibility: row.postVisibility as PostVisibility,
    allowFollow: row.allowFollow,
    dmPolicy: (row.dmPolicy as DmPolicy) ?? 'all',
    personalizedRecommendation: row.personalizedRecommendation,
  };
}
