// 统一登录态（横切地基）：持久化 token + 当前用户，供全应用复用。
// 真登录已接入：无登录态时 ensureLogin 不再静默建号，而是跳到 LoginPage 由用户显式选择
// 「华为一键登录」或「其他方式登录（开发桩）」。
import { login, LoginResult } from '../services/api';
import { User } from '../models/types';
import { router } from '@kit.ArkUI';

// 进程级持久化（基于 Preferences，重启/重进页面不丢）。必须在任何 AppStorage 读写前注册一次。
PersistentStorage.persistProp('authToken', '');
PersistentStorage.persistProp('authUserId', '');
PersistentStorage.persistProp('authNickname', '');
PersistentStorage.persistProp('authAvatar', '');
PersistentStorage.persistProp('authBio', '');        // 个人简介（编辑资料回写，避免再进需重填）
PersistentStorage.persistProp('authGender', 0);      // 性别：0=保密/未设 1=男 2=女
PersistentStorage.persistProp('authIsAdmin', false); // 管理员标识（后端 env.adminUserIds 计算，登录时落地）
PersistentStorage.persistProp('unreadMessageCount', 0); // 消息 Tab 未读红点
PersistentStorage.persistProp('unreadDmCount', 0); // 私信未读红点（与通知红点合并显示）
PersistentStorage.persistProp('privacyAgreed', '0'); // 首启隐私协议同意标记（'1'=已同意）

export function getToken(): string {
  return (AppStorage.get<string>('authToken') ?? '') as string;
}

export function getIsAdmin(): boolean {
  return (AppStorage.get<boolean>('authIsAdmin') ?? false) as boolean;
}

export function getUserId(): number {
  const v: string = (AppStorage.get<string>('authUserId') ?? '') as string;
  const n: number = parseInt(v, 10);
  return isNaN(n) ? 0 : n;
}

export function getCurrentUser(): User | null {
  const id: number = getUserId();
  if (id === 0) {
    return null;
  }
  const nickname: string = (AppStorage.get<string>('authNickname') ?? '') as string;
  const avatar: string = (AppStorage.get<string>('authAvatar') ?? '') as string;
  const bio: string = (AppStorage.get<string>('authBio') ?? '') as string;
  const gender: number = (AppStorage.get<number>('authGender') ?? 0) as number;
  const isAdmin: boolean = (AppStorage.get<boolean>('authIsAdmin') ?? false) as boolean;
  return { id, nickname, avatar, bio, gender, isAdmin } as User;
}

export function setSession(token: string, user: User): void {
  AppStorage.setOrCreate('authToken', token);
  AppStorage.setOrCreate('authUserId', String(user.id ?? ''));
  AppStorage.setOrCreate('authNickname', user.nickname ?? '');
  AppStorage.setOrCreate('authAvatar', user.avatar ?? '');
  AppStorage.setOrCreate('authBio', user.bio ?? '');
  AppStorage.setOrCreate('authGender', user.gender ?? 0);
  AppStorage.setOrCreate('authIsAdmin', user.isAdmin ? true : false);
}

// 清登录态：token / 用户信息 / 管理员态全部清空（登出、账号注销共用）。
export function clearSession(): void {
  AppStorage.setOrCreate('authToken', '');
  AppStorage.setOrCreate('authUserId', '');
  AppStorage.setOrCreate('authNickname', '');
  AppStorage.setOrCreate('authAvatar', '');
  AppStorage.setOrCreate('authBio', '');
  AppStorage.setOrCreate('authGender', 0);
  AppStorage.setOrCreate('authIsAdmin', false);
}

// 确保登录态：有登录态直接返回当前用户；无登录态则跳到 LoginPage 由用户显式登录，并返回 null。
// 不再静默用 dev 桩建号（原 MVP 行为），避免真实登录入口被绕过。
export async function ensureLogin(): Promise<User | null> {
  const existing: User | null = getCurrentUser();
  if (existing && getToken()) {
    return existing;
  }
  // 防递归：LoginPage 自身（如「其他方式登录」）调用时不再重复 pushUrl
  try {
    const state = router.getState();
    if (state && state.path !== 'pages/LoginPage') {
      router.pushUrl({ url: 'pages/LoginPage' });
    }
  } catch (e) {
    // router 未就绪等异常时直接尝试跳转，不阻断
    try {
      router.pushUrl({ url: 'pages/LoginPage' });
    } catch (_) { /* ignore */ }
  }
  return null;
}

// 开发/预览兜底：仅由 LoginPage 的「其他方式登录」手动调用，静默桩逻辑集中在此处，
// 不再由 ensureLogin 自动触发。真机走华为账号一键登录（exchangeHuaweiCode）。
export async function loginWithDevStub(): Promise<User> {
  const res: LoginResult = await login({ openId: 'dev-seed-openid', nickname: '科技老张' });
  setSession(res.token, res.user);
  return res.user;
}

// 幂等兜底：确保在 AppStorage 读写前已注册持久化（Index aboutToAppear 调用一次）。
export function initAuthStorage(): void {
  PersistentStorage.persistProp('authToken', '');
  PersistentStorage.persistProp('authUserId', '');
  PersistentStorage.persistProp('authNickname', '');
  PersistentStorage.persistProp('authAvatar', '');
  PersistentStorage.persistProp('authBio', '');
  PersistentStorage.persistProp('authGender', 0);
  PersistentStorage.persistProp('authIsAdmin', false);
  PersistentStorage.persistProp('unreadMessageCount', 0);
  PersistentStorage.persistProp('unreadDmCount', 0);
  PersistentStorage.persistProp('privacyAgreed', '0');
}

// 首启隐私协议：是否已同意（'1'=已同意）。未同意则 Index 弹窗拦截。
export function isPrivacyAgreed(): boolean {
  return (AppStorage.get<string>('privacyAgreed') ?? '0') === '1';
}

// 首启隐私协议：标记为已同意并持久化（PersistentStorage 自动落盘）。
export function setPrivacyAgreed(): void {
  AppStorage.setOrCreate('privacyAgreed', '1');
}

// 华为登录结果落地：语义化封装 setSession，供 LoginPage 在拿到 LoginResult 后调用。
// 与 openId 登录共用同一套登录态（F2：直接调 setSession 复用）。
export function loginByHuaweiResult(result: LoginResult): void {
  setSession(result.token, result.user);
}
