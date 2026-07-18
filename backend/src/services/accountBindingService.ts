// 账号绑定业务服务（AccountBindingService）。
// 职责：列表合成（harmony 主账号置顶 + 第三方按优先级排序）、绑定（双处占用校验 → 409、
//       写 UserBinding + 同步 User.unionID）、解绑（harmony → 403、不存在 → 404、删行）、脱敏。
//
// ⚠️ 契约变体（已拍板）：绑定走 code。
//    前端 HuaweiBindButton 从 response.authorizationCode 取 code 回调 onHuaweiBindSuccess(code)；
//    本服务的 bind(userId, provider, code) 内部用现有 huaweiAuth 的
//    exchangeCodeForToken(code) → fetchHuaweiUserProfile(token).unionID 取得 unionID 后再落库，
//    因此前端无需直接拿到 unionID，规避了华为凭证是否暴露 unionID 的不确定性。

import { prisma } from '../prisma';
import { exchangeCodeForToken, fetchHuaweiUserProfile } from './huaweiAuth';
import { CODE } from '../utils/response';

// provider 类型（与前端 types.ets 的 Provider 对齐，后端单一来源）
export type Provider = 'harmony' | 'huawei' | 'wechat';

// 可主动绑定的 provider 白名单（P0 仅 huawei；harmony 为主账号由列表合成，不允许主动绑定）
const ALLOWED_BIND_PROVIDERS: Provider[] = ['huawei'];

// 第三方 provider 的列表排序优先级（harmony 始终置顶，无需在此）
const PROVIDER_PRIORITY: Record<string, number> = {
  huawei: 1,
  wechat: 2,
};

// provider 展示名映射
const DISPLAY_NAME: Record<string, string> = {
  harmony: '鸿蒙账号',
  huawei: '华为账号',
  wechat: '微信',
};

// 账号绑定列表项（与前端 BindingItem 字段对齐；externalId 已脱敏）
export interface BindingItem {
  provider: Provider;
  externalId: string; // 已脱敏展示串，如 '****1234'
  boundAt: string; // ISO 时间串
  isPrimary: boolean; // true 仅鸿蒙主账号
  displayName: string; // 中文展示名
  status: 'primary' | 'bound' | 'unbound';
}

// 解绑响应
export interface UnbindResult {
  provider: Provider;
  unbound: boolean;
}

// 业务错误：携带需要返回给前端的 code 与 httpStatus，便于路由统一转 fail
export class AccountError extends Error {
  code: number;
  httpStatus: number;

  constructor(code: number, httpStatus: number, message: string) {
    super(message);
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

/**
 * 列表：合成 harmony 主账号置顶项 + 已绑定的第三方按优先级排序。
 * harmony 项由 User.openId / User.createdAt 合成（不落 UserBinding 表）。
 */
export async function listBindings(userId: number): Promise<BindingItem[]> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { openId: true, createdAt: true },
  });
  if (!user) {
    throw new Error('用户不存在');
  }

  const bindings = await prisma.userBinding.findMany({
    where: { userId },
  });

  const items: BindingItem[] = [];

  // 鸿蒙主账号（合成项，isPrimary=true，externalId 脱敏）
  items.push({
    provider: 'harmony',
    externalId: maskExternalId('harmony', user.openId ?? ''),
    boundAt: user.createdAt.toISOString(),
    isPrimary: true,
    displayName: DISPLAY_NAME['harmony'],
    status: 'primary',
  });

  // 第三方绑定按优先级排序后追加
  const sorted = bindings.slice().sort((a, b) => {
    const pa: number = PROVIDER_PRIORITY[a.provider] ?? 99;
    const pb: number = PROVIDER_PRIORITY[b.provider] ?? 99;
    return pa - pb;
  });
  for (const b of sorted) {
    const provider = b.provider as Provider;
    items.push({
      provider,
      externalId: maskExternalId(provider, b.externalId),
      boundAt: b.boundAt.toISOString(),
      isPrimary: b.isPrimary,
      displayName: DISPLAY_NAME[provider] ?? provider,
      status: 'bound',
    });
  }

  return items;
}

/**
 * 绑定第三方账号（code 变体）。
 * @param userId 当前登录用户 ID（来自 JWT，强制作为过滤条件防越权）
 * @param provider 待绑定 provider，仅 ALLOWED_BIND_PROVIDERS 内合法（harmony 不允许）
 * @param code 前端华为授权页回调的 authorizationCode
 * @returns 新建的 BindingItem（externalId 已脱敏）
 * @throws AccountError 400（参数非法）/ 409（已被他人占用）/ 500（华为换 token 失败等）
 */
export async function bind(userId: number, provider: Provider, code: string): Promise<BindingItem> {
  if (!ALLOWED_BIND_PROVIDERS.includes(provider)) {
    throw new AccountError(CODE.BAD_REQUEST, 400, '暂不支持绑定该账号类型');
  }
  if (!code || !code.trim()) {
    throw new AccountError(CODE.BAD_REQUEST, 400, '缺少授权码');
  }

  // 用 code 换取华为 unionID（复用现有 huaweiAuth，零新增依赖）
  const token: string = await exchangeCodeForToken(code);
  const profile = await fetchHuaweiUserProfile(token);
  const unionID: string = profile.unionID;

  // 占用校验：UserBinding(provider+externalId) 与 User.unionID 两处，均排除自身
  const occupied: boolean = await isExternalIdOccupiedByOther(provider, unionID, userId);
  if (occupied) {
    throw new AccountError(CODE.CONFLICT, 409, '该华为账号已关联其他大蓝书账号');
  }

  // 写 UserBinding（isPrimary=false）+ 同步 User.unionID
  const created = await prisma.userBinding.create({
    data: {
      userId,
      provider,
      externalId: unionID,
      isPrimary: false,
    },
  });
  await prisma.user.update({
    where: { id: userId },
    data: { unionID },
  });

  return {
    provider,
    externalId: maskExternalId(provider, unionID),
    boundAt: created.boundAt.toISOString(),
    isPrimary: false,
    displayName: DISPLAY_NAME[provider] ?? provider,
    status: 'bound',
  };
}

/**
 * 解绑第三方账号。
 * @param userId 当前登录用户 ID
 * @param provider 待解绑 provider
 * @returns { provider, unbound: true }
 * @throws AccountError 403（解绑主账号 harmony）/ 404（绑定不存在）
 */
export async function unbind(userId: number, provider: Provider): Promise<UnbindResult> {
  if (provider === 'harmony') {
    throw new AccountError(CODE.FORBIDDEN, 403, '主账号不可解绑');
  }
  const existing = await prisma.userBinding.findUnique({
    where: { userId_provider: { userId, provider } },
  });
  if (!existing) {
    throw new AccountError(CODE.NOT_FOUND, 404, '未找到该绑定关系');
  }
  await prisma.userBinding.delete({
    where: { userId_provider: { userId, provider } },
  });
  return { provider, unbound: true };
}

/**
 * 校验某个 externalId 是否已被「其他」账号占用（排除自身 userId）。
 * 两处存储都查：UserBinding 表 与 User.unionID 列。
 */
async function isExternalIdOccupiedByOther(
  provider: Provider,
  externalId: string,
  userId: number,
): Promise<boolean> {
  const byBinding = await prisma.userBinding.findFirst({
    where: {
      provider,
      externalId,
      NOT: { userId },
    },
  });
  if (byBinding) {
    return true;
  }
  const byUser = await prisma.user.findFirst({
    where: {
      unionID: externalId,
      NOT: { id: userId },
    },
  });
  return !!byUser;
}

/**
 * externalId 脱敏（仅返回时脱敏，存储为明文）。
 * - harmony：保留前 2 后 2，中间 ****；长度 ≤6 整体 ****
 * - huawei / wechat：保留末 4 位 → '****' + raw.slice(-4)
 */
function maskExternalId(provider: string, raw: string): string {
  if (!raw) {
    return '****';
  }
  if (provider === 'harmony') {
    if (raw.length <= 6) {
      return '****';
    }
    return raw.slice(0, 2) + '****' + raw.slice(-2);
  }
  // huawei / wechat（及未来其他第三方）：保留末 4 位
  return '****' + raw.slice(-4);
}
