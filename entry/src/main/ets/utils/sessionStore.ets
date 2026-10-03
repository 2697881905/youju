// 会话持久化（dataPreferences 独立文件）：登录态 + 隐私同意标记的可靠存储层。
//
// 为什么不用 PersistentStorage（真机实测结论，2026-10）：覆盖安装（hdc install -r / DevEco Run）
// 之后的冷启动，PersistentStorage 大概率读不回旧 persistent_storage 文件——AppStorage 全部回到
// 默认值（偶发首启直接黑屏挂死）；用户随后任何一次持久化键写入（如重新同意隐私弹窗）都会把
// 内存默认值整份刷回磁盘，authToken / authUserId 被清空 → 「覆盖安装后账号必掉」。
// Asset Store 也在覆盖安装时被系统清空，同样无法兜底。而 dataPreferences（theme.ets 同款）
// 在同一真机的覆盖安装全流程中始终可靠，故会话改走显式管理的 Preferences 文件：
// 启动同步读（水合 AppStorage）、登录/登出显式写（flushSync 即时落盘），
// 不再依赖 PersistentStorage 的隐式双向同步。
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'sessionStore';

const SESSION_PREF_NAME: string = 'youju_session';

// 与旧 PersistentStorage 同名的键：迁移与水合共用同一份清单（键名不变，消费方零改动）。
const KEY_TOKEN: string = 'authToken';
const KEY_USER_ID: string = 'authUserId';
const KEY_NICKNAME: string = 'authNickname';
const KEY_AVATAR: string = 'authAvatar';
const KEY_PROFILE_BACKGROUND: string = 'authProfileBackground';
const KEY_BIO: string = 'authBio';
const KEY_GENDER: string = 'authGender';
const KEY_IS_ADMIN: string = 'authIsAdmin';
const KEY_PRIVACY_AGREED: string = 'privacyAgreed';

// 旧 PersistentStorage 落盘文件名（位于 UIAbilityContext.filesDir，即 haps/entry/files/）。
// 已安装设备升级到本方案后首启做一次性迁移；读不到/解析失败静默放弃（最坏重登一次）。
const LEGACY_FILE_NAME: string = 'persistent_storage';

let _prefs: preferences.Preferences | null = null;
let _legacyChecked: boolean = false;

interface SessionFields {
  authToken: string;
  authUserId: string;
  authNickname: string;
  authAvatar: string;
  authProfileBackground: string;
  authBio: string;
  authGender: number;
  authIsAdmin: boolean;
  privacyAgreed: string;
}

function defaultSession(): SessionFields {
  const s: SessionFields = {
    authToken: '',
    authUserId: '',
    authNickname: '',
    authAvatar: '',
    authProfileBackground: '',
    authBio: '',
    authGender: 0,
    authIsAdmin: false,
    privacyAgreed: '0',
  };
  return s;
}

// 初始化：EntryAbility.onCreate 调用（早于任何页面构建，保证首帧前 AppStorage 已有登录态）。
// appContext 打开会话文件；abilityContext 仅用于定位旧 persistent_storage 文件做一次性迁移。
export function initSessionStore(appContext: common.ApplicationContext, abilityContext: common.UIAbilityContext): void {
  if (_prefs !== null) {
    return;
  }
  try {
    _prefs = preferences.getPreferencesSync(appContext, { name: SESSION_PREF_NAME });
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'open session prefs failed: %{public}s', JSON.stringify(e));
    return;
  }
  const loaded: SessionFields = readSession();
  if (loaded.authToken === '' && !_legacyChecked) {
    _legacyChecked = true;
    const migrated: SessionFields = migrateLegacySession(abilityContext);
    if (migrated.authToken !== '') {
      writeSession(migrated);
      hydrateAppStorage(migrated);
      hilog.info(DOMAIN, TAG, 'legacy session migrated (userId=%{public}s)', migrated.authUserId);
      return;
    }
  }
  hydrateAppStorage(loaded);
}

function readSession(): SessionFields {
  if (_prefs === null) {
    return defaultSession();
  }
  const s: SessionFields = defaultSession();
  try {
    s.authToken = _prefs.getSync(KEY_TOKEN, '') as string;
    s.authUserId = _prefs.getSync(KEY_USER_ID, '') as string;
    s.authNickname = _prefs.getSync(KEY_NICKNAME, '') as string;
    s.authAvatar = _prefs.getSync(KEY_AVATAR, '') as string;
    s.authProfileBackground = _prefs.getSync(KEY_PROFILE_BACKGROUND, '') as string;
    s.authBio = _prefs.getSync(KEY_BIO, '') as string;
    s.authGender = _prefs.getSync(KEY_GENDER, 0) as number;
    s.authIsAdmin = _prefs.getSync(KEY_IS_ADMIN, false) as boolean;
    s.privacyAgreed = _prefs.getSync(KEY_PRIVACY_AGREED, '0') as string;
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'read session failed: %{public}s', JSON.stringify(e));
  }
  return s;
}

// 把当前会话写入磁盘：AppStorage 是运行时唯一事实源，这里整份快照落盘（putSync + flushSync）。
// 登录（setSession）、登出（clearSession）、资料回写、同意隐私等所有变更入口统一走这里，
// 保证文件与 AppStorage 严格一致；flushSync 消除旧 PersistentStorage 的数秒落盘延迟，
// 登录后立刻杀进程也不会丢。
export function saveSessionSnapshot(): void {
  if (_prefs === null) {
    return;
  }
  try {
    _prefs.putSync(KEY_TOKEN, (AppStorage.get<string>(KEY_TOKEN) ?? '') as string);
    _prefs.putSync(KEY_USER_ID, (AppStorage.get<string>(KEY_USER_ID) ?? '') as string);
    _prefs.putSync(KEY_NICKNAME, (AppStorage.get<string>(KEY_NICKNAME) ?? '') as string);
    _prefs.putSync(KEY_AVATAR, (AppStorage.get<string>(KEY_AVATAR) ?? '') as string);
    _prefs.putSync(KEY_PROFILE_BACKGROUND, (AppStorage.get<string>(KEY_PROFILE_BACKGROUND) ?? '') as string);
    _prefs.putSync(KEY_BIO, (AppStorage.get<string>(KEY_BIO) ?? '') as string);
    _prefs.putSync(KEY_GENDER, (AppStorage.get<number>(KEY_GENDER) ?? 0) as number);
    _prefs.putSync(KEY_IS_ADMIN, (AppStorage.get<boolean>(KEY_IS_ADMIN) ?? false) as boolean);
    _prefs.putSync(KEY_PRIVACY_AGREED, (AppStorage.get<string>(KEY_PRIVACY_AGREED) ?? '0') as string);
    _prefs.flushSync();
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'save session failed: %{public}s', JSON.stringify(e));
  }
}

function writeSession(s: SessionFields): void {
  if (_prefs === null) {
    return;
  }
  try {
    _prefs.putSync(KEY_TOKEN, s.authToken);
    _prefs.putSync(KEY_USER_ID, s.authUserId);
    _prefs.putSync(KEY_NICKNAME, s.authNickname);
    _prefs.putSync(KEY_AVATAR, s.authAvatar);
    _prefs.putSync(KEY_PROFILE_BACKGROUND, s.authProfileBackground);
    _prefs.putSync(KEY_BIO, s.authBio);
    _prefs.putSync(KEY_GENDER, s.authGender);
    _prefs.putSync(KEY_IS_ADMIN, s.authIsAdmin);
    _prefs.putSync(KEY_PRIVACY_AGREED, s.privacyAgreed);
    _prefs.flushSync();
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'write session failed: %{public}s', JSON.stringify(e));
  }
}

function hydrateAppStorage(s: SessionFields): void {
  AppStorage.setOrCreate(KEY_TOKEN, s.authToken);
  AppStorage.setOrCreate(KEY_USER_ID, s.authUserId);
  AppStorage.setOrCreate(KEY_NICKNAME, s.authNickname);
  AppStorage.setOrCreate(KEY_AVATAR, s.authAvatar);
  AppStorage.setOrCreate(KEY_PROFILE_BACKGROUND, s.authProfileBackground);
  AppStorage.setOrCreate(KEY_BIO, s.authBio);
  AppStorage.setOrCreate(KEY_GENDER, s.authGender);
  AppStorage.setOrCreate(KEY_IS_ADMIN, s.authIsAdmin);
  AppStorage.setOrCreate(KEY_PRIVACY_AGREED, s.privacyAgreed);
}

// ===== 旧 PersistentStorage 文件的一次性迁移 =====

// 旧文件为 Preferences XML，值为 JSON 编码后整体 XML 转义（如 "40" → &quot;40&quot;）。
function xmlUnescape(raw: string): string {
  return raw
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

function readLegacyField(xml: string, key: string): string | null {
  const re: RegExp = new RegExp('<string key="' + key + '">([^<]*)</string>');
  const m: RegExpMatchArray | null = xml.match(re);
  if (m === null || m.length < 2) {
    return null;
  }
  return xmlUnescape(m[1]);
}

function migrateLegacySession(abilityContext: common.UIAbilityContext): SessionFields {
  const out: SessionFields = defaultSession();
  try {
    const path: string = abilityContext.filesDir + '/' + LEGACY_FILE_NAME;
    const stat: fileIo.Stat = fileIo.statSync(path);
    if (stat.size <= 0) {
      return out;
    }
    const xml: string = fileIo.readTextSync(path);
    const tokenRaw: string | null = readLegacyField(xml, KEY_TOKEN);
    const uidRaw: string | null = readLegacyField(xml, KEY_USER_ID);
    // 迁移门槛：token + userId 必须成对（与旧「幽灵会话」丢弃策略一致）。
    if (tokenRaw === null || uidRaw === null) {
      return out;
    }
    const tokenJson: Object | null = JSON.parse(tokenRaw);
    const uidJson: Object | null = JSON.parse(uidRaw);
    if (typeof tokenJson !== 'string' || typeof uidJson !== 'string' ||
      (tokenJson as string).length === 0 || (uidJson as string).length === 0) {
      return out;
    }
    out.authToken = tokenJson as string;
    out.authUserId = uidJson as string;
    const nickname: string | null = readLegacyField(xml, KEY_NICKNAME);
    if (nickname !== null) {
      const v: Object | null = JSON.parse(nickname);
      if (typeof v === 'string') {
        out.authNickname = v as string;
      }
    }
    const avatar: string | null = readLegacyField(xml, KEY_AVATAR);
    if (avatar !== null) {
      const v: Object | null = JSON.parse(avatar);
      if (typeof v === 'string') {
        out.authAvatar = v as string;
      }
    }
    const background: string | null = readLegacyField(xml, KEY_PROFILE_BACKGROUND);
    if (background !== null) {
      const v: Object | null = JSON.parse(background);
      if (typeof v === 'string') {
        out.authProfileBackground = v as string;
      }
    }
    const bio: string | null = readLegacyField(xml, KEY_BIO);
    if (bio !== null) {
      const v: Object | null = JSON.parse(bio);
      if (typeof v === 'string') {
        out.authBio = v as string;
      }
    }
    const gender: string | null = readLegacyField(xml, KEY_GENDER);
    if (gender !== null) {
      const v: Object | null = JSON.parse(gender);
      if (typeof v === 'number') {
        out.authGender = v as number;
      }
    }
    const isAdmin: string | null = readLegacyField(xml, KEY_IS_ADMIN);
    if (isAdmin !== null) {
      const v: Object | null = JSON.parse(isAdmin);
      if (typeof v === 'boolean') {
        out.authIsAdmin = v as boolean;
      }
    }
    const agreed: string | null = readLegacyField(xml, KEY_PRIVACY_AGREED);
    if (agreed !== null) {
      const v: Object | null = JSON.parse(agreed);
      if (typeof v === 'string') {
        out.privacyAgreed = v as string;
      }
    }
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'legacy session migration skipped: %{public}s', JSON.stringify(e));
  }
  return out;
}
