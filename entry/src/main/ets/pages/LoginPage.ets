// 登录页（P0 新增，无登录态时由 Index 跳转至此）
// 提供两种登录方式：
//   1) 华为账号一键登录（LoginWithHuaweiIDButton）：成功后用 code 换登录态，setSession 复用现有登录态
//   2) 其他方式登录：走现有 openId 授权登录桩（ensureLogin），作为华为登录降级兜底

import { exchangeHuaweiCode, LoginResult } from '../services/api';
import { setSession, ensureLogin } from '../utils/auth';
import { HuaweiLoginButton } from '../components/HuaweiLoginButton';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';

@Entry
@Component
struct LoginPage {
  build() {
    Column({ space: 24 }) {
      Text('登录大蓝书')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 80, bottom: 40 })

      // 方式一：华为账号一键登录
      HuaweiLoginButton({
        onHuaweiSuccess: (code: string): void => {
          this.handleHuaweiSuccess(code);
        },
        onHuaweiFailure: (error: string | Error): void => {
          this.handleHuaweiFailure(error);
        },
      })

      // 方式二：其他方式登录（openId 授权桩），华为登录降级兜底
      Button('其他方式登录')
        .width('80%')
        .height(44)
        .onClick((): void => {
          this.handleOtherLogin();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .transition(buildPageTransition())
  }

  // 华为登录成功：用 code 换登录态并落地 session
  private async handleHuaweiSuccess(code: string): Promise<void> {
    try {
      const result: LoginResult = await exchangeHuaweiCode({ code });
      setSession(result.token, result.user);
      this.getUIContext().getRouter().back();
    } catch (e) {
      const err: Error = e as Error;
      this.toast(err.message);
    }
  }

  // 华为登录失败：toast 降级，不阻塞原入口（用户仍可点「其他方式登录」）
  private handleHuaweiFailure(error: string | Error): void {
    const msg: string = typeof error === 'string' ? error : error.message;
    this.toast('华为登录未完成：' + msg);
  }

  // 其他方式登录：走现有 openId 授权桩
  private async handleOtherLogin(): Promise<void> {
    try {
      const user = await ensureLogin();
      if (user) {
        this.getUIContext().getRouter().back();
      }
    } catch (e) {
      const err: Error = e as Error;
      this.toast(err.message);
    }
  }

  private toast(message: string): void {
    safeShowToast(this.getUIContext(),{ message: message, duration: 2000 });
  }
}
