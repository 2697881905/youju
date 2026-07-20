// 统一登录态（横切地基）：持久化 token + 当前用户，供全应用复用。
// MVP 先用 dev-seed-openid 桩自动登录；Account Kit 真实接入后替换 ensureLogin 内部实现。
import { login, LoginResult } from '../services/api';
import { User } from '../models/types';

// 进程级持久化（基于 Preferences，重启/重进页面不丢）。必须在任何 AppStorage 读写前注册一次。
PersistentStorage.persistProp('authToken', '');
PersistentStorage.persistProp('authUserId', '');
PersistentStorage.persistProp('authNickname', '');
PersistentStorage.persistProp('authAvatar', '');
PersistentStorage.persistProp('authIsAdmin', false); // 管理员标识（后端 env.adminUserIds 计算，登录时落地）
PersistentStorage.persistProp('unreadMessageCount', 0); // 消息 Tab 未读红点
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
  const isAdmin: boolean = (AppStorage.get<boolean>('authIsAdmin') ?? false) as boolean;
  return { id, nickname, avatar, isAdmin } as User;
}

export function setSession(token: string, user: User): void {
  AppStorage.setOrCreate('authToken', token);
  AppStorage.setOrCreate('authUserId', String(user.id ?? ''));
  AppStorage.setOrCreate('authNickname', user.nickname ?? '');
  AppStorage.setOrCreate('authAvatar', user.avatar ?? '');
  AppStorage.setOrCreate('authIsAdmin', user.isAdmin ? true : false);
}

// 清登录态：token / 用户信息 / 管理员态全部清空（登出、账号注销共用）。
export function clearSession(): void {
  AppStorage.setOrCreate('authToken', '');
  AppStorage.setOrCreate('authUserId', '');
  AppStorage.setOrCreate('authNickname', '');
  AppStorage.setOrCreate('authAvatar', '');
  AppStorage.setOrCreate('authIsAdmin', false);
}

// MVP 桩：无登录态时自动用 dev-seed-openid 登录（对应后端 seed 用户 科技老张 id=1）。
// 接入 Account Kit 后，此函数内部改为调用华为账号登录换取 openId 再 login()。
export async function ensureLogin(): Promise<User> {
  const existing: User | null = getCurrentUser();
  if (existing && getToken()) {
    return existing;
  }
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
  PersistentStorage.persistProp('authIsAdmin', false);
  PersistentStorage.persistProp('unreadMessageCount', 0);
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
