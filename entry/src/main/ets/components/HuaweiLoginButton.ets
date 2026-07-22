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

  // 登录按钮参数（显式类型标注，规避 arkts-no-untyped-obj-literals）。
  // style 为 loginComponentManager.Style 枚举（组件自带尺寸，颜色风格由枚举决定），
  // 此处使用华为经典红色按钮 BUTTON_RED；如需浅色可改为 BUTTON_WHITE。
  private huaweiParams: loginComponentManager.LoginWithHuaweiIDButtonParams = {
    style: loginComponentManager.Style.BUTTON_RED,
    supportDarkMode: true,
    loginType: loginComponentManager.LoginType.ID,
  };

  build() {
    // [API 24+] Account Kit 系统组件未设尺寸时会默认撑满父容器，必须显式约束，
    // 否则在 Column 里会把整个页面变成一块大红板。width/height 只能链在组件上，
    // 不能放进 params（会报 10505001）。
    LoginWithHuaweiIDButton({
      params: this.huaweiParams,
      controller: this.controller,
    })
      .width('100%')
      .height(48)
  }
}
