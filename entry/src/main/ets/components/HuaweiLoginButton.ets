// 华为账号登录按钮封装（Account Kit 官方 LoginWithHuaweiIDButton）。
// 对外仅暴露两个普通属性回调（非 @Prop）：
//   onHuaweiSuccess(code: string) —— 成功拿到 Authorization Code
//   onHuaweiFailure(error: string | Error) —— 失败（含用户取消），不阻塞原入口
// 组件内部回调只做「提取 code / 转调」，不写业务登录逻辑。
import { LoginWithHuaweiIDButton, loginComponentManager } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'HuaweiLoginButton';

@Component
export struct HuaweiLoginButton {
  // 成功回调：父组件拿到 authorizationCode 后自行请求服务端
  onHuaweiSuccess: (code: string) => void = (code: string): void => {};
  // 失败回调：父组件自行降级（toast / 展示其他登录方式）
  onHuaweiFailure: (error: string | Error) => void = (error: string | Error): void => {};

  private controller: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController()
      .onClickLoginWithHuaweiIDButton((error: BusinessError, response: loginComponentManager.HuaweiIDCredential): void => {
        if (error) {
          hilog.error(0x0000, TAG, '华为登录失败 code=%{public}d msg=%{public}s', error.code, error.message);
          this.onHuaweiFailure(error);
          return;
        }
        if (response) {
          const code: string = response.authorizationCode;
          this.onHuaweiSuccess(code);
        }
      });

  build() {
    LoginWithHuaweiIDButton({
      params: {
        // 跟随系统深浅色模式
        supportDarkMode: true,
        // 仅获取 UnionID / Authorization Code（不拉手机号，符合 P0 范围）
        loginType: loginComponentManager.LoginType.ID,
      },
      controller: this.controller,
    })
  }
}
