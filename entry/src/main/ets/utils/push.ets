// 华为推送（Push Kit）客户端收口：Token 获取/上报/解绑、通知权限申请、通知点击意图解析。
// 设计原则同后端：任何环节失败都静默降级 —— 推送是锦上添花，不能拖累登录与启动。
import { pushService } from '@kit.PushKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { common, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { registerPushToken, unregisterPushToken } from '../services/api';
import { getToken } from './auth';

const PUSH_DOMAIN: number = 0x0000;
const PUSH_TAG: string = 'push';

// 推送点击带来的路由意图（服务端 clickAction.data 透传）；
// youju:// deep link（分享落地页拉起）解析后也复用同一结构走待处理路由通道。
export interface PushRoute {
  type: string; // 通知类型：comment / up / mention / bookmark / follow / system / dm；deep link：post / user
  postId: number; // 关联帖子，0 = 无
  commentId: number; // 关联评论，0 = 无
  nid: number; // 通知记录 id
  peerId: number; // 私信：对方 userId，0 = 非私信
  peerName: string; // 私信：对方昵称（会话页靠 intent 渲染，只给 id 拿不到名字）
  userId: number; // deep link：youju://user/{id} 打开他人主页，0 = 无
}

// 进程内去重：冷启动上报过一次后，登录成功回调不必重复打同一请求。
let lastReportedToken: string = '';

// 取本机推送 Token。失败（未联网 / 推送权益未开通 / 不支持设备）返回空串。
export function fetchPushToken(): Promise<string> {
  return pushService.getToken().catch((e: BusinessError): string => {
    // 1000900012 = 推送权益未开通，1000900014 = 设备不支持：真机未配置时常见，不刷屏。
    hilog.warn(PUSH_DOMAIN, PUSH_TAG, 'getToken 失败 %{public}d %{public}s', e.code, e.message);
    return '';
  });
}

// 上报本机 Token 并绑定到当前账号（须先有登录态，否则请求会被 401 打回）。
// 登录成功、切号登录、冷启动会话恢复均可调用，重复调用幂等。
export async function syncPushToken(): Promise<void> {
  if (getToken() === '') {
    return;
  }
  const token: string = await fetchPushToken();
  if (token === '' || token === lastReportedToken) {
    return;
  }
  try {
    await registerPushToken(token);
    lastReportedToken = token;
  } catch (e) {
    // 上报失败不阻断：下次冷启动/登录会自然重试
    hilog.warn(PUSH_DOMAIN, PUSH_TAG, 'registerPushToken 失败 %{public}s', JSON.stringify(e));
  }
}

// 登出 / 注销账号：先解绑服务端记录，再删除本机 Token。
// ⚠️ 必须在 clearSession() **之前**调用 —— 解绑请求本身要带鉴权 Header。
export async function clearPushToken(): Promise<void> {
  try {
    const token: string = lastReportedToken.length > 0 ? lastReportedToken : await fetchPushToken();
    if (token !== '') {
      await unregisterPushToken(token);
    }
    await pushService.deleteToken();
    lastReportedToken = '';
  } catch (e) {
    // 解绑失败也要让登出流程走完：最多残留旧绑定，换号登录时会随 register 迁移归属
    hilog.warn(PUSH_DOMAIN, PUSH_TAG, 'clearPushToken 失败 %{public}s', JSON.stringify(e));
  }
}

// 通知权限：未授权时系统不会把 Push 消息展示进通知栏，必须先显式申请。
// 只在已登录且尚未授权时弹一次系统申请，不做重复打扰。
export function requestNotificationPermission(ctx: common.UIAbilityContext): void {
  notificationManager.isNotificationEnabled().then((enabled: boolean): void => {
    if (enabled) {
      return;
    }
    notificationManager.requestEnableNotification(ctx).catch((e: BusinessError): void => {
      hilog.warn(PUSH_DOMAIN, PUSH_TAG, 'requestEnableNotification 失败 %{public}d', e.code);
    });
  }).catch((): void => {
    // 查询失败不处理：后续登录/冷启动仍会再试一次
  });
}

// ===== 通知点击：want 参数解析 =====
// 服务端 clickAction.data 的字段会平铺进 want.parameters；部分版本也可能整体挂在
// parameters['data']（JSON 串）。两条路径都认，取不到即视为非推送来源（普通冷启动）。

type FlatParams = Record<string, string | number>;

function toInt(v: string | number | undefined): number {
  if (typeof v === 'number') {
    return v;
  }
  if (typeof v === 'string') {
    const n: number = parseInt(v, 10);
    return isNaN(n) ? 0 : n;
  }
  return 0;
}

// 路由意图 type 白名单：本通道同时接收「服务端推送 clickAction.data」与「本地任意应用
// 对 exported EntryAbility 构造的 want.parameters」，后者不可信——不在白名单内的 type
// 一律丢弃，防止恶意应用伪造 type=dm + peerId 把用户强行带进指定会话页（冒充官方钓鱼）。
const PUSH_ROUTE_TYPES: string[] =
  ['comment', 'up', 'mention', 'bookmark', 'follow', 'system', 'dm', 'post', 'user'];

export function readPushRoute(want: Want | undefined): PushRoute | null {
  if (want === undefined || want.parameters === undefined) {
    return null;
  }
  let source: FlatParams;
  try {
    // want.parameters 类型是 Record<string, Object>，逐字段取值在严格模式下要反复断言；
    // 参数量极小，用 JSON 往返一次拿到扁平结构，顺带规避不可序列化字段。
    source = JSON.parse(JSON.stringify(want.parameters)) as FlatParams;
  } catch (e) {
    return null;
  }
  const nested: string | number | undefined = source['data'];
  if (typeof nested === 'string' && nested.length > 0) {
    try {
      source = JSON.parse(nested) as FlatParams;
    } catch (e) {
      // 保持外层形态重试
    }
  }
  const rawType: string | number | undefined = source['type'];
  if (typeof rawType !== 'string' || PUSH_ROUTE_TYPES.indexOf(rawType) < 0) {
    return null;
  }
  return {
    type: rawType,
    postId: toInt(source['postId']),
    commentId: toInt(source['commentId']),
    nid: toInt(source['nid']),
    peerId: toInt(source['peerId']),
    peerName: typeof source['peerName'] === 'string' ? source['peerName'] : '',
    userId: 0, // 推送载荷不携带 userId，deep link 专属字段
  };
}

// ===== youju:// Deep Link 解析（分享落地页「去有据看看」按钮拉起）=====
// 网页侧无法调用应用内的 openLink API，落地页按钮直接跳转 youju://post/{id} / youju://user/{id}，
// 系统按 module.json5 的 skills（scheme: youju）把意图送进本应用（want.uri 携带原始链接）。
// 解析结果复用推送的待处理路由通道（enqueuePushRoute/takePushRoute）——Index 的 @Watch
// 消费逻辑零改动即可跳转，避免再造一套 AppStorage 信号。解析不出的链接一律返回 null 静默忽略。
export function readDeepLinkRoute(want: Want | undefined): PushRoute | null {
  const uri: string = want?.uri ?? '';
  if (!uri.startsWith('youju://')) {
    return null;
  }
  const path: string = uri.slice('youju://'.length).split('?')[0].replace(/\/+$/, '');
  const segs: string[] = path.split('/').filter((s: string): boolean => s.length > 0);
  if (segs.length !== 2) {
    return null;
  }
  const id: number = parseInt(segs[1], 10);
  if (isNaN(id) || id <= 0) {
    return null;
  }
  if (segs[0] === 'post') {
    return { type: 'post', postId: id, commentId: 0, nid: 0, peerId: 0, peerName: '', userId: 0 };
  }
  if (segs[0] === 'user') {
    return { type: 'user', postId: 0, commentId: 0, nid: 0, peerId: 0, peerName: '', userId: id };
  }
  return null;
}

// 由 EntryAbility 调用：塞入待处理路由并递增 seq，用于触发 Index 的 @Watch 回调。
// 拆成「值 + 序号」两段是因为 AppStorage 对「同一值重复写入」不派发变更，
// 连续点开两条同类型通知时必须有单调递增的信号。
export function enqueuePushRoute(route: PushRoute): void {
  AppStorage.setOrCreate('pendingPushRoute', JSON.stringify(route));
  const seq: number = (AppStorage.get<number>('pushRouteSeq') ?? 0) as number;
  AppStorage.setOrCreate('pushRouteSeq', seq + 1);
}

// 由 Index 消费：取出并清空（一次性，避免重复跳转）。
export function takePushRoute(): PushRoute | null {
  const raw: string = (AppStorage.get<string>('pendingPushRoute') ?? '') as string;
  if (raw === '') {
    return null;
  }
  AppStorage.setOrCreate('pendingPushRoute', '');
  try {
    return JSON.parse(raw) as PushRoute;
  } catch (e) {
    return null;
  }
}
