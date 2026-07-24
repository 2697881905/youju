// 登录页（P0 重构）
// 布局：品牌头（图标+名称+副标题） → 华为账号登录（受限 Account Kit 系统组件）
//   → 「其他方式登录」强调兜底（开发桩，目前唯一可用入口）→ 隐私协议尾巴
// 华为登录失败（含 AGC 未配置的 Invalid clientId/profile）给出友好提示，
// 但不阻塞——用户可继续走「其他方式登录」。
// 颜色全部使用资源色，跟随系统深色/浅色模式自动适配。

import { exchangeHuaweiCode, LoginResult } from '../services/api';
import { setSession, loginWithDevStub } from '../utils/auth';
import { HuaweiLoginButton } from '../components/HuaweiLoginButton';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { CARD_RADIUS } from '../utils/cardTokens';

@Entry
@Component
struct LoginPage {
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 华为登录失败时的内联提示文本（空=不展示）
  @State huaweiErrorTip: string = '';
  // 「其他方式登录」提交中态
  @State otherSubmitting: boolean = false;
  // 华为登录进行中态（按钮不可重复点）
  @State huaweiSubmitting: boolean = false;

  build() {
    Column() {
      // 顶部状态栏留白
      Blank().height(this.statusBarHeight)

      // 品牌头
      Column({ space: 12 }) {
        // 应用图标（与启动图标 startIcon 同款，logo.png 是从 startIcon 导出的同源副本）
        Image($r('app.media.logo'))
          .width(72)
          .height(72)
          .borderRadius(16)
          .margin({ top: 64 })

        Text('大蓝书')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('理性选购 更好的生活')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ bottom: 8 })
      }
      .width('100%')

      // 登录按钮区
      Column({ space: 16 }) {
        // 华为登录失败时的内联提示（账号服务未配置 / 用户取消等场景）
        if (this.huaweiErrorTip.length > 0) {
          Text(this.huaweiErrorTip)
            .fontSize(12)
            .fontColor($r('app.color.semantic_orange'))
            .width('80%')
            .textAlign(TextAlign.Center)
        }

        // 方式一：华为账号一键登录（系统组件，由 HuaweiLoginButton 内已限制尺寸）
        HuaweiLoginButton({
          onHuaweiSuccess: (code: string): void => {
            this.handleHuaweiSuccess(code);
          },
          onHuaweiFailure: (error: string | Error): void => {
            this.handleHuaweiFailure(error);
          },
        })
          .width('80%')
          .enabled(!this.huaweiSubmitting)
          .opacity(this.huaweiSubmitting ? 0.6 : 1)

        // 方式二：其他方式登录（开发桩，预览/模拟器/AGC 未配置时唯一可用入口）
        // 强调显示：卡片背景 + 主题色描边 + 主色文字，深浅模式自适应
        Button(this.otherSubmitting ? '登录中…' : '其他方式登录')
          .width('80%')
          .height(48)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.card_bg'))
          .border({ width: 1, color: $r('app.color.text_primary'), style: BorderStyle.Solid })
          .borderRadius(CARD_RADIUS)
          .enabled(!this.otherSubmitting)
          .opacity(this.otherSubmitting ? 0.6 : 1)
          .onClick((): void => {
            this.handleOtherLogin();
          })
      }
      .width('100%')
      .margin({ top: 40 })

      Blank()  // 推底部到底

      // 隐私协议尾巴：可点击文字跳转真实页面
      Row() {
        Text('登录即表示同意')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        Text('《用户协议》')
          .fontSize(12)
          .fontColor($r('app.color.brand_primary'))
          .onClick((): void => {
            const ctx = this.getUIContext();
            ctx.getRouter().pushUrl({ url: 'pages/UserAgreementPage' });
          })
        Text('与')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        Text('《隐私政策》')
          .fontSize(12)
          .fontColor($r('app.color.brand_primary'))
          .onClick((): void => {
            const ctx = this.getUIContext();
            ctx.getRouter().pushUrl({ url: 'pages/PrivacyPage' });
          })
      }
      .margin({ bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }

  // 华为登录成功：用 code 换登录态并落地 session
  private async handleHuaweiSuccess(code: string): Promise<void> {
    if (this.huaweiSubmitting) {
      return;
    }
    this.huaweiSubmitting = true;
    this.huaweiErrorTip = '';
    try {
      const result: LoginResult = await exchangeHuaweiCode({ code });
      setSession(result.token, result.user);
      this.getUIContext().getRouter().back();
    } catch (e) {
      const err: Error = e as Error;
      this.huaweiErrorTip = '登录失败：' + err.message;
    } finally {
      this.huaweiSubmitting = false;
    }
  }

  // 华为登录失败：内联提示（不让用户盲点），不阻塞原入口
  private handleHuaweiFailure(error: string | Error): void {
    const raw: string = typeof error === 'string' ? error : error.message;
    // AGC 未配置 / 证书指纹不匹配时的特征串，提示用户走兜底
    if (/clientId|client_id|profile|Invalid input parameter/i.test(raw)) {
      this.huaweiErrorTip = '华为账号服务暂未配置，请使用「其他方式登录」';
    } else if (/CANCEL|用户取消/i.test(raw)) {
      // 用户主动取消，不展示错误
      this.huaweiErrorTip = '';
    } else {
      this.huaweiErrorTip = '华为登录未完成：' + raw;
    }
  }

  // 其他方式登录：走开发桩（目前唯一可用入口）
  private async handleOtherLogin(): Promise<void> {
    if (this.otherSubmitting) {
      return;
    }
    this.otherSubmitting = true;
    try {
      const user = await loginWithDevStub();
      if (user) {
        this.getUIContext().getRouter().back();
      }
    } catch (e) {
      const err: Error = e as Error;
      this.toast('登录失败：' + err.message);
    } finally {
      this.otherSubmitting = false;
    }
  }

  private toast(message: string): void {
    safeShowToast(this.getUIContext(), { message: message, duration: 2000 });
  }
}
