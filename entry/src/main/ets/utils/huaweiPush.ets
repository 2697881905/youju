// 华为推送 Token 注册（前端侧）。
// 登录后调用 pushService.getToken() 取设备 Token 并上报后端；
// 模拟器 / 未开通推送服务时 getToken 会抛错，这里静默降级，绝不阻断主流程。
import { pushService } from '@kit.PushKit';
import { getToken } from './auth';
import { registerPushToken } from '../services/api';

export async function ensurePushRegistration(): Promise<void> {
  if (getToken() === '') {
    return; // 未登录不上报
  }
  try {
    // HarmonyOS NEXT 的 pushService.getToken() 返回 Promise<string>（设备推送 Token）。
    const token: string = await pushService.getToken();
    if (!token) {
      return;
    }
    await registerPushToken(token);
  } catch (e) {
    // 推送不可用（模拟器 / 未配置 AGC 推送）属预期，忽略即可
  }
}
