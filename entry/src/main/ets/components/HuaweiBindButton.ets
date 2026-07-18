// 华为账号绑定按钮封装（Account Kit 官方 LoginWithHuaweiIDButton）。
// 逐字镜像现有 HuaweiLoginButton 的成熟写法，仅做一处职责区分：
//   本组件用于「绑定」场景，从 response.authorizationCode 取 code，
//   通过 onHuaweiBindSuccess(code) 暴露给页面（页面再调 bindAccount('huawei', code)）。
// 组件内部只做「提取 code / 转调」，不写任何业务。
import { LoginWithHuaweiIDButton, loginComponentManager } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'HuaweiBindButton';

@Component
export struct HuaweiBindButton {
  // 成功回调：父组件拿到 authorizationCode 后自行请求服务端绑定
  onHuaweiBindSuccess: (code: string) => void = (code: string): void => {};
  // 失败回调：父组件自行降级（toast / 展示其他操作）
  onHuaweiBindFailure: (error: string | Error) => void = (error: string | Error): void => {};

  private controller: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController()
      .onClickLoginWithHuaweiIDButton((error: BusinessError, response: loginComponentManager.HuaweiIDCredential): void => {
        if (error) {
          hilog.error(0x0000, TAG, '华为绑定失败 code=%{public}d msg=%{public}s', error.code, error.message);
          this.onHuaweiBindFailure(error);
          return;
        }
        if (response) {
          const code: string = response.authorizationCode;
          this.onHuaweiBindSuccess(code);
        }
      });

  // 登录按钮参数（显式类型标注，规避 arkts-no-untyped-obj-literals）。
  // style 为 loginComponentManager.Style 枚举（组件自带尺寸，颜色风格由枚举决定），
  // 此处使用华为经典红色按钮 BUTTON_RED。
  private huaweiParams: loginComponentManager.LoginWithHuaweiIDButtonParams = {
    style: loginComponentManager.Style.BUTTON_RED,
    supportDarkMode: true,
    loginType: loginComponentManager.LoginType.ID,
  };

  build() {
    LoginWithHuaweiIDButton({
      params: this.huaweiParams,
      controller: this.controller,
    })
  }
}
