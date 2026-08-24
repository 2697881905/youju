// 登录欢迎页
// 视觉层次：品牌氛围光晕 → 图标+名称+标语 → 登录按钮 → 隐私协议勾选
// 品牌标语「有据可依 更好的生活」传达产品核心价值与定位。
// 隐私协议需用户主动勾选后方可点击登录按钮，未勾选时所有登录入口禁用。
// 配色沿用设计系统 ds_brand 蓝色主色 + 暖色点缀，跟随深色/浅色模式自动适配。

import { exchangeHuaweiCode, LoginResult } from '../services/api';
import { setSession, loginWithDevStub, loginWithDevStub2, markCircleOnboardingPending } from '../utils/auth';
import { HuaweiLoginButton } from '../components/HuaweiLoginButton';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { RadiusTokens } from '../design/tokens/radius';
import { BUILD_MODE_NAME } from '../utils/buildMode';
const BUILD_MODE: string = BUILD_MODE_NAME;

@Entry
@Component
struct LoginPage {
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @State huaweiErrorTip: string = '';
  @State otherSubmitting: boolean = false;
  @State v2Submitting: boolean = false;
  @State huaweiSubmitting: boolean = false;
  @State devLoginVisible: boolean = BUILD_MODE !== 'release';
  @State privacyAgreed: boolean = false;

  build() {
    Stack() {
      // ── 品牌氛围光晕：两道柔和径向渐变叠加在底色上，营造品牌蓝+暖色的视觉基调 ──
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.ds_brand_tint'))
      // 右上方蓝色光晕
      Column()
        .width(300)
        .height(300)
        .borderRadius(150)
        .backgroundColor($r('app.color.ds_brand'))
        .opacity(0.06)
        .position({ right: -80, top: -40 })
        .blur(80)
      // 左下方暖色光晕（与 logo 中橙色点缀呼应）
      Column()
        .width(220)
        .height(220)
        .borderRadius(110)
        .backgroundColor($r('app.color.ds_warm'))
        .opacity(0.05)
        .position({ left: -60, bottom: 120 })
        .blur(60)

      // ── 主内容 ──
      Column() {
        // 顶部状态栏留白
        Blank().height(this.statusBarHeight)

        // ── 品牌区：图标 + 名称 + 核心标语 + 副标题 ──
        Column() {
          // 应用图标
          Image($r('app.media.logo'))
            .width(108)
            .height(108)
            .borderRadius(RadiusTokens.lg)

          // 品牌名称
          Text('有据')
            .fontSize(40).fontFamily($r('app.string.font_family'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ds_text_primary'))
            .margin({ top: 16 })

          // 品牌标语
          Text('有据可依  更好的生活')
            .fontSize(15).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.ds_text_secondary'))
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        // ── 登录按钮区 ──
        Column({ space: 12 }) {
          // 华为登录失败时的内联提示
          if (this.huaweiErrorTip.length > 0) {
            Text(this.huaweiErrorTip)
              .fontSize(12).fontFamily($r('app.string.font_family'))
              .fontColor($r('app.color.semantic_orange'))
              .width('85%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 4 })
          }

          // 主登录：华为账号一键登录（系统组件）
          HuaweiLoginButton({
            onHuaweiSuccess: (code: string): void => {
              this.handleHuaweiSuccess(code);
            },
            onHuaweiFailure: (error: string | Error): void => {
              this.handleHuaweiFailure(error);
            },
          })
            .width('85%')
            .enabled(!this.huaweiSubmitting && this.privacyAgreed)
            .opacity(this.huaweiSubmitting || !this.privacyAgreed ? 0.6 : 1)

          // 开发桩登录入口（发布包隐藏）
          if (this.devLoginVisible) {
            // 分隔线
            Row({ space: 12 }) {
              Divider().layoutWeight(1).color($r('app.color.ds_separator'))
              Text('或')
                .fontSize(12).fontFamily($r('app.string.font_family'))
                .fontColor($r('app.color.ds_text_tertiary'))
              Divider().layoutWeight(1).color($r('app.color.ds_separator'))
            }
            .width('85%')
            .margin({ top: 4 })

            // 其他方式登录
            Button(this.otherSubmitting ? '登录中…' : '其他方式登录')
              .width('85%')
              .height(48)
              .fontSize(16).fontFamily($r('app.string.font_family'))
              .fontColor($r('app.color.ds_text_primary'))
              .backgroundColor($r('app.color.ds_elevated'))
              .border({ width: 1, color: $r('app.color.ds_separator'), style: BorderStyle.Solid })
              .borderRadius(RadiusTokens.md)
              .enabled(!this.otherSubmitting && this.privacyAgreed)
              .opacity(this.otherSubmitting || !this.privacyAgreed ? 0.6 : 1)
              .onClick((): void => {
                this.handleOtherLogin();
              })

            // 虚拟测试账号·小美
            Button(this.v2Submitting ? '登录中…' : '虚拟用户·小美 登录')
              .width('85%')
              .height(48)
              .fontSize(16).fontFamily($r('app.string.font_family'))
              .fontColor($r('app.color.ds_text_primary'))
              .backgroundColor($r('app.color.ds_elevated'))
              .border({ width: 1, color: $r('app.color.ds_separator'), style: BorderStyle.Solid })
              .borderRadius(RadiusTokens.md)
              .enabled(!this.v2Submitting && this.privacyAgreed)
              .opacity(this.v2Submitting || !this.privacyAgreed ? 0.6 : 1)
              .onClick((): void => {
                this.handleVirtual2Login();
              })
          }
        }
        .width('100%')
        .padding({ bottom: 20 })

        // ── 隐私协议勾选 ──
        Row({ space: 6 }) {
          Checkbox()
            .select(this.privacyAgreed)
            .selectedColor($r('app.color.ds_brand'))
            .width(18)
            .height(18)
            .onChange((value: boolean) => {
              this.privacyAgreed = value;
            })
          Row() {
            Text('我已阅读并同意')
              .fontSize(12).fontFamily($r('app.string.font_family'))
              .fontColor($r('app.color.ds_text_tertiary'))
            Text('《用户协议》')
              .fontSize(12).fontFamily($r('app.string.font_family'))
              .fontColor($r('app.color.ds_brand'))
              .onClick((): void => {
                const ctx = this.getUIContext();
                ctx.getRouter().pushUrl({ url: 'pages/UserAgreementPage' });
              })
            Text('与')
              .fontSize(12).fontFamily($r('app.string.font_family'))
              .fontColor($r('app.color.ds_text_tertiary'))
            Text('《隐私政策》')
              .fontSize(12).fontFamily($r('app.string.font_family'))
              .fontColor($r('app.color.ds_brand'))
              .onClick((): void => {
                const ctx = this.getUIContext();
                ctx.getRouter().pushUrl({ url: 'pages/PrivacyPage' });
              })
          }
          .onClick(() => {
            this.privacyAgreed = !this.privacyAgreed;
          })
        }
        .width('85%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 34 })
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .transition(buildPageTransition())
  }

  // ── 华为登录成功：用 code 换登录态并落地 session ──
  private async handleHuaweiSuccess(code: string): Promise<void> {
    if (this.huaweiSubmitting) {
      return;
    }
    this.huaweiSubmitting = true;
    this.huaweiErrorTip = '';
    try {
      const result: LoginResult = await exchangeHuaweiCode({ code });
      setSession(result.token, result.user);
      if (result.isNewUser) {
        markCircleOnboardingPending(result.user.id);
      }
      this.getUIContext().getRouter().back();
    } catch (e) {
      const err: Error = e as Error;
      this.huaweiErrorTip = '登录失败：' + err.message;
    } finally {
      this.huaweiSubmitting = false;
    }
  }

  // ── 华为登录失败：内联提示（不让用户盲点），不阻塞原入口 ──
  private handleHuaweiFailure(error: string | Error): void {
    const raw: string = typeof error === 'string' ? error : error.message;
    if (/clientId|client_id|profile|Invalid input parameter/i.test(raw)) {
      this.huaweiErrorTip = '华为账号服务暂未配置，请使用「其他方式登录」';
    } else if (/CANCEL|用户取消/i.test(raw)) {
      this.huaweiErrorTip = '';
    } else {
      this.huaweiErrorTip = '华为登录未完成：' + raw;
    }
  }

  // ── 其他方式登录：走开发桩 ──
  private async handleOtherLogin(): Promise<void> {
    if (this.otherSubmitting) {
      return;
    }
    this.otherSubmitting = true;
    try {
      const result: LoginResult = await loginWithDevStub();
      if (result.isNewUser) {
        markCircleOnboardingPending(result.user.id);
      }
      this.getUIContext().getRouter().back();
    } catch (e) {
      const err: Error = e as Error;
      this.toast('登录失败：' + err.message);
    } finally {
      this.otherSubmitting = false;
    }
  }

  // ── 第二个虚拟账号登录 ──
  private async handleVirtual2Login(): Promise<void> {
    if (this.v2Submitting) {
      return;
    }
    this.v2Submitting = true;
    try {
      const result: LoginResult = await loginWithDevStub2();
      if (result.isNewUser) {
        markCircleOnboardingPending(result.user.id);
      }
      this.getUIContext().getRouter().back();
    } catch (e) {
      const err: Error = e as Error;
      this.toast('登录失败：' + err.message);
    } finally {
      this.v2Submitting = false;
    }
  }

  private toast(message: string): void {
    safeShowToast(this.getUIContext(), { message: message, duration: 2000 });
  }
}
