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
//
// Token 落盘加固（2026-10-05）：prefs 里不再存明文 token，改为与「设备 ODID + 每次写入的
// 随机 nonce」绑定的 keystream 异或遮蔽（authTokenEnc）。恢复路径必须依赖 prefs（Asset 覆盖
// 安装即清空），且必须同步完成（水合早于首帧，AES/Asset 的异步 API 会引入启动时序风险），
// 故用 cryptoFramework 的同步 SHA-256 迭代拼接 keystream。安全边界（诚实说明）：
//  - 跨设备提取/还原备份：ODID 不同 → 解开是噪声 → 防住；
//  - 同设备 root：ODID 可读、密钥流可重算，**不设防**（此场景下内存中的明文 token 同样
//    暴露，遮蔽无意义）；硬件级加固由 auth.ets 的 Asset Store 副本互补承担。
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import deviceInfo from '@ohos.deviceInfo';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

const DOMAIN: number = 0x0000;
const TAG: string = 'sessionStore';

const SESSION_PREF_NAME: string = 'youju_session';

// 与旧 PersistentStorage 同名的键：迁移与水合共用同一份清单（键名不变，消费方零改动）。
// authToken 明文键仅用于读取上一版本的存量数据（读取后立即迁移删除），不再写入。
const KEY_TOKEN: string = 'authToken';
const KEY_TOKEN_ENC: string = 'authTokenEnc';
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
  // 上一版本明文键残留标记（内部迁移用，不参与水合）：读到即触发一次转存删除
  hasLegacyPlainToken: boolean;
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
    hasLegacyPlainToken: false,
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

// ===== Token 遮蔽（XOR keystream，读写在同一设备上自逆）=====

function strToBytes(s: string): Uint8Array {
  const arr: Uint8Array = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) {
    arr[i] = s.charCodeAt(i) & 0xff;
  }
  return arr;
}

function bytesToStr(b: Uint8Array): string {
  let s: string = '';
  for (let i = 0; i < b.length; i++) {
    s += String.fromCharCode(b[i]);
  }
  return s;
}

function sha256Bytes(text: string): Uint8Array {
  const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
  md.updateSync({ data: strToBytes(text) });
  return md.digestSync().data;
}

// keystream：SHA256(odid:nonce:counter) 迭代拼接，覆盖 token 全长
function keystream(odid: string, nonceB64: string, len: number): Uint8Array {
  const out: Uint8Array = new Uint8Array(len);
  let filled: number = 0;
  let counter: number = 0;
  while (filled < len) {
    const block: Uint8Array = sha256Bytes(odid + ':' + nonceB64 + ':' + counter);
    const take: number = Math.min(block.length, len - filled);
    out.set(block.subarray(0, take), filled);
    filled += take;
    counter += 1;
  }
  return out;
}

function shieldToken(token: string, nonceB64: string): string {
  const data: Uint8Array = strToBytes(token);
  const ks: Uint8Array = keystream(odidOf(), nonceB64, data.length);
  for (let i = 0; i < data.length; i++) {
    data[i] = data[i] ^ ks[i];
  }
  return new util.Base64Helper().encodeToStringSync(data);
}

function unshieldToken(shieldedB64: string, nonceB64: string): string {
  const data: Uint8Array = new util.Base64Helper().decodeSync(shieldedB64);
  const ks: Uint8Array = keystream(odidOf(), nonceB64, data.length);
  for (let i = 0; i < data.length; i++) {
    data[i] = data[i] ^ ks[i];
  }
  return bytesToStr(data);
}

function odidOf(): string {
  try {
    return deviceInfo.ODID ?? '';
  } catch (e) {
    return '';
  }
}

// 新鲜 nonce（12 字节随机）：同 token 每次落盘密文都不同，避免「同明文同密文」对齐
function freshNonce(): string {
  try {
    const blob: cryptoFramework.DataBlob = cryptoFramework.createRandom().generateRandomSync(12);
    return new util.Base64Helper().encodeToStringSync(blob.data);
  } catch (e) {
    // 随机源异常兜底：时间戳 nonce 仍保证跨写入不重复
    return new util.Base64Helper().encodeToStringSync(strToBytes(String(Date.now())));
  }
}

// 存储形态：'<nonceB64>:<shieldedB64>'；空 token 存 ''（登出态）
function encodeToken(token: string): string {
  if (token.length === 0) {
    return '';
  }
  const nonce: string = freshNonce();
  return nonce + ':' + shieldToken(token, nonce);
}

function decodeToken(enc: string): string {
  if (enc.length === 0) {
    return '';
  }
  const idx: number = enc.indexOf(':');
  if (idx <= 0) {
    return '';
  }
  try {
    return unshieldToken(enc.slice(idx + 1), enc.slice(0, idx));
  } catch (e) {
    // ODID 变化（恢复出厂）/数据损坏 → 解出无效会话，静默降级为未登录
    hilog.error(DOMAIN, TAG, 'token decode failed: %{public}s', JSON.stringify(e));
    return '';
  }
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
  // 上一版本明文 token 的迁移：转存混淆密文 + 删除明文键（会话不中断，AppStorage 值不变）
  if (loaded.hasLegacyPlainToken) {
    writeSession(loaded);
    hilog.info(DOMAIN, TAG, 'legacy plaintext token migrated to shielded form');
  }
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
    s.authToken = decodeToken(_prefs.getSync(KEY_TOKEN_ENC, '') as string);
    // 上一版本明文键残留（本版本首次启动）：作为兜底会话源，标记迁移
    const legacyPlain: string = _prefs.getSync(KEY_TOKEN, '') as string;
    if (legacyPlain.length > 0) {
      s.hasLegacyPlainToken = true;
      if (s.authToken === '') {
        s.authToken = legacyPlain;
      }
    }
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
    // token 只写混淆密文（见文件头安全边界说明）；明文键做幂等清理
    _prefs.putSync(KEY_TOKEN_ENC, encodeToken((AppStorage.get<string>(KEY_TOKEN) ?? '') as string));
    _prefs.deleteSync(KEY_TOKEN);
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
    _prefs.putSync(KEY_TOKEN_ENC, encodeToken(s.authToken));
    _prefs.deleteSync(KEY_TOKEN);
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
