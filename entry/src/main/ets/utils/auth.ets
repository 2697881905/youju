// 统一登录态（横切地基）：持久化 token + 当前用户，供全应用复用。
// 真登录已接入：无登录态时 ensureLogin 不再静默建号，而是跳到 LoginPage 由用户显式选择
// 「华为一键登录」或「其他方式登录（开发桩）」。
import { login, LoginResult } from '../services/api';
import { User } from '../models/types';
import { router } from '@kit.ArkUI';
import { BUILD_MODE_NAME } from 'BuildProfile';
import { asset } from '@kit.AssetStoreKit';
// BUILD_MODE_NAME 由构建期生成，类型为字面量（'debug'/'release'）。
// 严格模式（assembleHap）下与字面量比较会触发 "no overlap" 报错，转成 string 再比较。
const BUILD_MODE: string = BUILD_MODE_NAME;

// 当前隐私政策版本（须与后端 env.privacyPolicyVersion 默认一致；后端可用 PRIVACY_POLICY_VERSION 环境变量覆盖）。
// 前端弹窗"同意"时上报此版本，后端据其对齐并判断是否需要重新征求。
export const PRIVACY_POLICY_VERSION: string = '1.0.0';

// 进程级持久化（基于 Preferences，重启/重进页面不丢）。必须在任何 AppStorage 读写前注册一次。
// 注意：authToken 不再走明文 Preferences，改存硬件加密 Asset Store（见文件末尾 saveTokenToAsset），
// 仅在 AppStorage 保留内存态；其余非敏感用户态仍走 Preferences。
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
  // token 落地到硬件加密 Asset Store（替代明文 Preferences），防沙箱/备份提取
  saveTokenToAsset(token);
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
  clearTokenFromAsset();
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
  if (BUILD_MODE === 'release') {
    throw new Error('开发桩登录已在发布包禁用');
  }
  const res: LoginResult = await login({ openId: 'dev-seed-openid', nickname: '科技老张' });
  setSession(res.token, res.user);
  return res.user;
}

// 第二个虚拟测试账号（昵称「虚拟小美」），与「科技老张」区分，
// 用于跨账号互测：评论 / 关注 / 私信 / 访问对方主页 / 投票等。
export async function loginWithDevStub2(): Promise<User> {
  if (BUILD_MODE === 'release') {
    throw new Error('开发桩登录已在发布包禁用');
  }
  const res: LoginResult = await login({ openId: 'dev-seed-openid-2', nickname: '虚拟小美' });
  setSession(res.token, res.user);
  return res.user;
}

// 幂等兜底：确保在 AppStorage 读写前已注册持久化（Index aboutToAppear 调用一次）。
export function initAuthStorage(): void {
  // 注意：authToken 不注册到明文 Preferences，改由下方从 Asset Store 恢复
  PersistentStorage.persistProp('authUserId', '');
  PersistentStorage.persistProp('authNickname', '');
  PersistentStorage.persistProp('authAvatar', '');
  PersistentStorage.persistProp('authBio', '');
  PersistentStorage.persistProp('authGender', 0);
  PersistentStorage.persistProp('authIsAdmin', false);
  PersistentStorage.persistProp('unreadMessageCount', 0);
  PersistentStorage.persistProp('unreadDmCount', 0);
  PersistentStorage.persistProp('privacyAgreed', '0');
  // 冷启动从硬件加密 Asset Store 恢复登录态 token（替代明文 Preferences 读取）
  const restoredToken: string = loadTokenFromAsset();
  if (restoredToken) {
    AppStorage.setOrCreate('authToken', restoredToken);
  }
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

// ===== Token 硬件加密持久化（F-004，替代明文 Preferences）=====
// JWT 为 ASCII 文本，用 charCode 做 Uint8Array 互转即可，避免引入额外编码依赖。
const TOKEN_ALIAS: string = 'bigbluebook_auth_token';

function tokenToBytes(s: string): Uint8Array {
  const arr: Uint8Array = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) {
    arr[i] = s.charCodeAt(i);
  }
  return arr;
}

function bytesToToken(u: Uint8Array): string {
  let s: string = '';
  for (let i = 0; i < u.length; i++) {
    s += String.fromCharCode(u[i]);
  }
  return s;
}

// 写入 Asset Store：先删后增，保证重复写入（如刷新 token）幂等。
// 设备未解锁 / 模拟器不支持时退化为仅内存态，不阻断登录。
function saveTokenToAsset(token: string): void {
  if (!token) {
    return;
  }
  try {
    const delQuery: asset.AssetMap = new Map();
    delQuery.set(asset.Tag.ALIAS, tokenToBytes(TOKEN_ALIAS));
    try {
      asset.removeSync(delQuery);
    } catch (e) {
      // alias 尚未存在时 remove 抛错，忽略
    }
    const attrs: asset.AssetMap = new Map();
    attrs.set(asset.Tag.ALIAS, tokenToBytes(TOKEN_ALIAS));
    attrs.set(asset.Tag.SECRET, tokenToBytes(token));
    attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    attrs.set(asset.Tag.IS_PERSISTENT, true);
    asset.addSync(attrs);
  } catch (e) {
    console.error('[auth] saveTokenToAsset failed:', e);
  }
}

// 从 Asset Store 读取 token（冷启动恢复），失败或无记录时返回空串。
function loadTokenFromAsset(): string {
  try {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, tokenToBytes(TOKEN_ALIAS));
    const res: asset.AssetMap[] = asset.querySync(query);
    if (res.length > 0) {
      const secret: Object | undefined = res[0].get(asset.Tag.SECRET);
      if (secret instanceof Uint8Array) {
        return bytesToToken(secret);
      }
    }
  } catch (e) {
    console.error('[auth] loadTokenFromAsset failed:', e);
  }
  return '';
}

function clearTokenFromAsset(): void {
  try {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, tokenToBytes(TOKEN_ALIAS));
    asset.removeSync(query);
  } catch (e) {
    // 已不存在时忽略
  }
}
