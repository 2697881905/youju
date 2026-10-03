// 统一登录态（横切地基）：持久化 token + 当前用户，供全应用复用。
// 真登录已接入：无登录态时 ensureLogin 不再静默建号，而是跳到 LoginPage 由用户显式选择
// 「华为一键登录」或「其他方式登录（开发桩）」。
import { login, LoginResult } from '../services/api';
import { User } from '../models/types';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getSharedUiContext } from './navigationTransition';
import { BUILD_MODE_NAME } from './buildMode';
import { asset } from '@kit.AssetStoreKit';
import { saveSessionSnapshot } from './sessionStore';
// BUILD_MODE_NAME 由构建期生成，类型为字面量（'debug'/'release'）。
// 严格模式（assembleHap）下与字面量比较会触发 "no overlap" 报错，转成 string 再比较。
const BUILD_MODE: string = BUILD_MODE_NAME;

// 当前隐私政策版本（须与后端 env.privacyPolicyVersion 默认一致；后端可用 PRIVACY_POLICY_VERSION 环境变量覆盖）。
// 前端弹窗"同意"时上报此版本，后端据其对齐并判断是否需要重新征求。
export const PRIVACY_POLICY_VERSION: string = '1.1.0';

// 登录态持久化已迁出 PersistentStorage → utils/sessionStore.ets（dataPreferences 独立文件）。
// 真机实测（2026-10）：覆盖安装（hdc install -r / DevEco Run）后的冷启动，PersistentStorage
// 读不回旧文件（AppStorage 全回默认值），用户一旦写入（如重同意隐私弹窗）就把默认值整份刷回
// 磁盘，token/用户信息被清空 → 「覆盖安装后账号必掉」。会话键改为普通 AppStorage 键，
// 由 sessionStore 在 EntryAbility.onCreate 最早水合、在 setSession/clearSession 显式落盘。
// 这里仅保留非关键 UI 态（未读红点/圈子引导标记）继续走 PersistentStorage——它们即使被
// 重置也只影响红点/引导弹窗，重新拉取即可。
PersistentStorage.persistProp('unreadMessageCount', 0); // 消息 Tab 未读红点
PersistentStorage.persistProp('unreadDmCount', 0); // 私信未读红点（与通知红点合并显示）
PersistentStorage.persistProp('circleOnboardingPendingUserId', '');

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
  const profileBackground: string = (AppStorage.get<string>('authProfileBackground') ?? '') as string;
  const bio: string = (AppStorage.get<string>('authBio') ?? '') as string;
  const gender: number = (AppStorage.get<number>('authGender') ?? 0) as number;
  const isAdmin: boolean = (AppStorage.get<boolean>('authIsAdmin') ?? false) as boolean;
  return { id, nickname, avatar, profileBackground, bio, gender, isAdmin } as User;
}

export function setSession(token: string, user: User): void {
  AppStorage.setOrCreate('authToken', token);
  AppStorage.setOrCreate('authUserId', String(user.id ?? ''));
  AppStorage.setOrCreate('authNickname', user.nickname ?? '');
  AppStorage.setOrCreate('authAvatar', user.avatar ?? '');
  AppStorage.setOrCreate('authProfileBackground', user.profileBackground ?? '');
  AppStorage.setOrCreate('authBio', user.bio ?? '');
  AppStorage.setOrCreate('authGender', user.gender ?? 0);
  AppStorage.setOrCreate('authIsAdmin', user.isAdmin ? true : false);
  // 会话整份落盘（dataPreferences，flushSync 即时写盘）：登录后立刻杀进程也不丢。
  saveSessionSnapshot();
  // token 另存硬件加密 Asset Store（安全加固，防沙箱/备份提取明文）。
  // 异步执行：Asset 同步 API 曾在启动路径挂死（覆盖安装后首启黑屏），登录路径也不再阻塞 UI。
  saveTokenToAsset(token);
}

// 新账号登录后先在 Tab 容器展示圈子选择；用户完成或跳过前保持该标记，避免中途退出后丢失流程。
export function markCircleOnboardingPending(userId: number | undefined): void {
  if (userId !== undefined && userId > 0) {
    AppStorage.setOrCreate('circleOnboardingPendingUserId', String(userId));
  }
}

// 清登录态：token / 用户信息 / 管理员态全部清空（登出、账号注销共用）。
export function clearSession(): void {
  AppStorage.setOrCreate('authToken', '');
  AppStorage.setOrCreate('authUserId', '');
  AppStorage.setOrCreate('authNickname', '');
  AppStorage.setOrCreate('authAvatar', '');
  AppStorage.setOrCreate('authProfileBackground', '');
  AppStorage.setOrCreate('authBio', '');
  AppStorage.setOrCreate('authGender', 0);
  AppStorage.setOrCreate('authIsAdmin', false);
  // 未读计数是 PersistentStorage 持久化的。若不复位：用户从没打开过「消息」页就登出时，
  // 唯一会清零的 MessagePage.resetData() 不会执行 → 红点残留，且冷启动后仍显示
  // 上一账号的未读数（隐私观感问题，审核会实际点）。
  AppStorage.setOrCreate('unreadMessageCount', 0);
  AppStorage.setOrCreate('unreadDmCount', 0);
  // 快照落盘：token/用户字段清空，privacyAgreed 保留（登出不撤销隐私同意）。
  saveSessionSnapshot();
  clearTokenFromAsset();
}

// 会话字段的非登录入口变更（如 CircleTab 拉到头像后回写 authAvatar）也要落盘，
// 否则冷启动恢复的是旧值。统一走快照，调用方在 AppStorage 写完后调用即可。
export function persistSessionSnapshot(): void {
  saveSessionSnapshot();
}

// 确保登录态：有登录态直接返回当前用户；无登录态则跳到 LoginPage 由用户显式登录，并返回 null。
// 不再静默用 dev 桩建号（原 MVP 行为），避免真实登录入口被绕过。
export async function ensureLogin(): Promise<User | null> {
  const existing: User | null = getCurrentUser();
  if (existing && getToken()) {
    return existing;
  }
  // 防递归：LoginPage 自身（如「其他方式登录」）调用时不再重复 pushUrl。
  // router 全局形态已废弃（since 18）→ 走共享 UIContext 的 Router（@since 11 ✓，与原 API 等价）。
  // 共享实例由 Index.aboutToAppear 注册；本函数只会被组件/页面在 Index 挂载后调用，必非 null。
  const ui = getSharedUiContext();
  if (ui === null) {
    hilog.warn(0x0000, 'auth', 'ensureLogin: 共享 UIContext 未注册，无法跳转 LoginPage');
    return null;
  }
  try {
    const state = ui.getRouter().getState();
    if (state && state.path !== 'pages/LoginPage') {
      ui.getRouter().pushUrl({ url: 'pages/LoginPage' });
    }
  } catch (e) {
    // Router 异常不阻断登录流程：调用方对 null 返回已有处理。
    hilog.warn(0x0000, 'auth', 'ensureLogin: 跳转 LoginPage 失败 %{public}s', JSON.stringify(e));
  }
  return null;
}

// 开发/预览兜底：仅由 LoginPage 的「其他方式登录」手动调用，静默桩逻辑集中在此处，
// 不再由 ensureLogin 自动触发。真机走华为账号一键登录（exchangeHuaweiCode）。
export async function loginWithDevStub(): Promise<LoginResult> {
  if (BUILD_MODE === 'release') {
    throw new Error('开发桩登录已在发布包禁用');
  }
  const res: LoginResult = await login({ openId: 'dev-seed-openid', nickname: '科技老张' });
  setSession(res.token, res.user);
  return res;
}

// 第二个虚拟测试账号（昵称「虚拟小美」），与「科技老张」区分，
// 用于跨账号互测：评论 / 关注 / 私信 / 访问对方主页 / 投票等。
export async function loginWithDevStub2(): Promise<LoginResult> {
  if (BUILD_MODE === 'release') {
    throw new Error('开发桩登录已在发布包禁用');
  }
  const res: LoginResult = await login({ openId: 'dev-seed-openid-2', nickname: '虚拟小美' });
  setSession(res.token, res.user);
  return res;
}

// 幂等兜底：确保在 AppStorage 读写前已注册持久化（Index aboutToAppear 调用一次）。
// 仅覆盖仍走 PersistentStorage 的非关键 UI 态；登录态的水合在 EntryAbility.onCreate
// 由 sessionStore.initSessionStore 完成（早于本调用），此处不再触碰会话键。
export function initAuthStorage(): void {
  PersistentStorage.persistProp('unreadMessageCount', 0);
  PersistentStorage.persistProp('unreadDmCount', 0);
  PersistentStorage.persistProp('circleOnboardingPendingUserId', '');
}

// 首启隐私协议：是否已同意（'1'=已同意）。未同意则 Index 弹窗拦截。
export function isPrivacyAgreed(): boolean {
  return (AppStorage.get<string>('privacyAgreed') ?? '0') === '1';
}

// 首启隐私协议：标记为已同意并持久化（随会话快照一并落盘，重装后不重弹）。
export function setPrivacyAgreed(): void {
  AppStorage.setOrCreate('privacyAgreed', '1');
  saveSessionSnapshot();
}

// ===== Token 硬件加密副本（F-004 安全加固）=====
// 定位变化：启动恢复已改走 sessionStore（dataPreferences，覆盖安装后仍可靠），Asset Store
// 在覆盖安装时会被系统清空、且只存 token 无 userId（单 token 无法成会话），故不再参与冷启动
// 恢复。保留写入作为安全加固副本：沙箱文件被提取时拿不到明文 token。
// 全部异步执行：Asset 同步 API（querySync/addSync）曾在覆盖安装后的启动路径挂死（黑屏），
// 登录/登出路径同样不让 UI 等它。
// JWT 为 ASCII 文本，用 charCode 做 Uint8Array 互转即可，避免引入额外编码依赖。
const TOKEN_ALIAS: string = 'youju_auth_token';

function tokenToBytes(s: string): Uint8Array {
  const arr: Uint8Array = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) {
    arr[i] = s.charCodeAt(i);
  }
  return arr;
}

// 写入 Asset Store：先删后增，保证重复写入（如刷新 token）幂等。
// 设备未解锁 / 模拟器不支持时静默失败，不阻断登录。
async function saveTokenToAsset(token: string): Promise<void> {
  if (!token) {
    return;
  }
  try {
    const delQuery: asset.AssetMap = new Map();
    delQuery.set(asset.Tag.ALIAS, tokenToBytes(TOKEN_ALIAS));
    try {
      await asset.remove(delQuery);
    } catch (e) {
      // alias 尚未存在时 remove 抛错，忽略
    }
    const attrs: asset.AssetMap = new Map();
    attrs.set(asset.Tag.ALIAS, tokenToBytes(TOKEN_ALIAS));
    attrs.set(asset.Tag.SECRET, tokenToBytes(token));
    attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    attrs.set(asset.Tag.IS_PERSISTENT, true);
    await asset.add(attrs);
  } catch (e) {
    console.error('[auth] saveTokenToAsset failed:', e);
  }
}

async function clearTokenFromAsset(): Promise<void> {
  try {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, tokenToBytes(TOKEN_ALIAS));
    await asset.remove(query);
  } catch (e) {
    // 已不存在时忽略
  }
}
