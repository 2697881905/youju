// 账号绑定业务服务（AccountBindingService）。
//
// ⚠️ 单一登录方式（v1 已拍板）：有据只用「华为账号」登录——
//    前端 AccountKit 拿 authorizationCode → 后端 /v1/auth/huawei/exchange → unionID 建号/登录。
//    早期与「华为账号」并列的「鸿蒙账号（openId）」已废弃：
//      · 生产已禁用开放 openId 登录（见 routes/auth.ts 的 /v1/auth/login 注释，存在冒充风险）；
//      · loginWithHuawei 建号时 openId 恒为 null（见 services/authService.ts）；
//    因此绑定列表不再合成 harmony 项，主账号项直接由 User.unionID 合成，且不可解绑
//    （解绑会把 unionID 置空 = 用户永久失去登录能力）。
//
// 职责：列表合成（huawei 主账号置顶 + 第三方）、绑定（当前全部拒绝，接口保留待微信接入）、
//       解绑（huawei → 403、不存在 → 404、删行）、脱敏。

import { prisma } from '../prisma';
import { CODE } from '../utils/response';

// provider 类型（与前端 types.ets 的 Provider 对齐，后端单一来源）
export type Provider = 'huawei' | 'wechat';

// 可主动绑定的 provider 白名单（v1 为空：华为账号即登录方式，登录即绑定，无需二次绑定）
const ALLOWED_BIND_PROVIDERS: Provider[] = [];

// 第三方 provider 的列表排序优先级（huawei 为主账号始终置顶，无需在此）
const PROVIDER_PRIORITY: Record<string, number> = {
  wechat: 2,
};

// provider 展示名映射
const DISPLAY_NAME: Record<string, string> = {
  huawei: '华为账号',
  wechat: '微信',
};

// 账号绑定列表项（与前端 BindingItem 字段对齐；externalId 已脱敏）
export interface BindingItem {
  provider: Provider;
  externalId: string; // 已脱敏展示串，如 '****1234'
  boundAt: string; // ISO 时间串
  isPrimary: boolean; // true 仅华为主账号
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
 * 列表：合成华为主账号置顶项 + 已绑定的第三方按优先级排序。
 * 主账号项由 User.unionID 合成（不落 UserBinding 表）；
 * 兼容早期 openId 老账号：unionID 为空时退回 openId，仅用于脱敏展示，仍标记为华为主账号。
 */
export async function listBindings(userId: number): Promise<BindingItem[]> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { openId: true, unionID: true, createdAt: true },
  });
  if (!user) {
    throw new Error('用户不存在');
  }

  const bindings = await prisma.userBinding.findMany({
    where: { userId },
  });

  const items: BindingItem[] = [];

  // 华为主账号（合成项，isPrimary=true，externalId 脱敏）
  const primaryRaw: string = user.unionID ?? user.openId ?? '';
  items.push({
    provider: 'huawei',
    externalId: maskExternalId(primaryRaw),
    boundAt: user.createdAt.toISOString(),
    isPrimary: true,
    displayName: DISPLAY_NAME['huawei'],
    status: 'primary',
  });

  // 第三方绑定按优先级排序后追加（跳过 huawei：主账号已由上方合成，避免重复行）
  const sorted = bindings.slice().sort((a, b) => {
    const pa: number = PROVIDER_PRIORITY[a.provider] ?? 99;
    const pb: number = PROVIDER_PRIORITY[b.provider] ?? 99;
    return pa - pb;
  });
  for (const b of sorted) {
    const provider = b.provider as Provider;
    if (provider === 'huawei') {
      continue;
    }
    items.push({
      provider,
      externalId: maskExternalId(b.externalId),
      boundAt: b.boundAt.toISOString(),
      isPrimary: b.isPrimary,
      displayName: DISPLAY_NAME[provider] ?? provider,
      status: 'bound',
    });
  }

  return items;
}

/**
 * 绑定第三方账号。
 * v1 不支持任何主动绑定：华为账号即登录方式（登录即绑定，且换绑会覆盖 User.unionID 导致串号），
 * 微信尚未接入。接口保留，待微信接入时在此按 provider 分派实现。
 * @throws AccountError 400（华为账号无需重复绑定 / 暂不支持该类型）
 */
export async function bind(userId: number, provider: Provider, code: string): Promise<BindingItem> {
  if (provider === 'huawei') {
    throw new AccountError(CODE.BAD_REQUEST, 400, '华为账号即登录方式，无需重复绑定');
  }
  if (!ALLOWED_BIND_PROVIDERS.includes(provider)) {
    throw new AccountError(CODE.BAD_REQUEST, 400, '暂不支持绑定该账号类型');
  }
  // 未来接入微信：此处用 code 换 openid → 占用校验 → 写 UserBinding
  throw new AccountError(CODE.BAD_REQUEST, 400, '暂不支持绑定该账号类型');
}

/**
 * 解绑第三方账号。
 * @param userId 当前登录用户 ID
 * @param provider 待解绑 provider
 * @returns { provider, unbound: true }
 * @throws AccountError 403（解绑主账号 huawei）/ 404（绑定不存在）
 */
export async function unbind(userId: number, provider: Provider): Promise<UnbindResult> {
  if (provider === 'huawei') {
    throw new AccountError(CODE.FORBIDDEN, 403, '华为账号为登录方式，不支持解绑');
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
 * externalId 脱敏（仅返回时脱敏，存储为明文）：统一保留末 4 位 → '****' + raw.slice(-4)。
 */
function maskExternalId(raw: string): string {
  if (!raw) {
    return '****';
  }
  return '****' + raw.slice(-4);
}
