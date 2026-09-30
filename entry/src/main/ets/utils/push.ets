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

// 推送点击带来的路由意图（服务端 clickAction.data 透传）
export interface PushRoute {
  type: string; // 通知类型：comment / up / mention / bookmark / follow / system
  postId: number; // 关联帖子，0 = 无
  commentId: number; // 关联评论，0 = 无
  nid: number; // 通知记录 id
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
  if (typeof rawType !== 'string' || rawType === '') {
    return null;
  }
  return {
    type: rawType,
    postId: toInt(source['postId']),
    commentId: toInt(source['commentId']),
    nid: toInt(source['nid']),
  };
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
