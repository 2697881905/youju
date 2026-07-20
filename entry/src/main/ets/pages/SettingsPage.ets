// 设置页：分区结构（账号与安全 / 通用 / 关于）+ 退出登录（二次确认）+ 账号注销（双重确认）。
// 退出登录：clearSession + 跳登录页；账号注销：后端软删（POST /v1/auth/me/deactivate）+ 清态 + 跳登录页。
import { router, CustomDialogController } from '@kit.ArkUI';
import { getIsAdmin, getCurrentUser, clearSession } from '../utils/auth';
import { deactivateAccount } from '../services/api';
import { safeShowToast } from '../utils/toast';

// 账号注销第二层确认弹窗（@CustomDialog 支持内嵌 TextInput/Checkbox，AlertDialog 无法内嵌输入）。
@CustomDialog
export struct DeactivateConfirmDialog {
  controller: CustomDialogController;
  currentNickname: string = '';
  onConfirm: () => void = (): void => {};

  @State inputNickname: string = '';
  @State confirmed: boolean = false;

  // 输入昵称与当前一致 或 勾选确认 → 启用「确认注销」
  private canConfirm(): boolean {
    if (this.confirmed) {
      return true;
    }
    return this.inputNickname.trim() === this.currentNickname;
  }

  build() {
    Column({ space: 16 }) {
      Text('确认注销账号')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'));

      Text('请输入你的昵称「' + this.currentNickname + '」以确认注销，或勾选下方确认框。')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'));

      TextInput({ placeholder: '请输入当前昵称', text: this.inputNickname })
        .width('100%')
        .height(44)
        .backgroundColor($r('app.color.bg_primary'))
        .borderRadius(10)
        .onChange((v: string) => {
          this.inputNickname = v;
        });

      Row({ space: 8 }) {
        Checkbox({ name: 'deactivateConfirm', group: 'deactivate' })
          .select(this.confirmed)
          .onChange((isChecked: boolean) => {
            this.confirmed = isChecked;
          });
        Text('我已阅读并理解注销后果，确认注销')
          .fontSize(13)
          .fontColor($r('app.color.text_primary'));
      }
      .width('100%');

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor($r('app.color.bg_primary'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.controller.close();
          });
        Button('确认注销')
          .layoutWeight(1)
          .enabled(this.canConfirm())
          .backgroundColor('#FF453A')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.controller.close();
            this.onConfirm();
          });
      }
      .width('100%');
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16);
  }
}

@Entry
@Component
export struct SettingsPage {
  @State isAdmin: boolean = getIsAdmin();
  // 当前昵称（构造期从登录态读取，供注销二次确认比对；非 @State 避免重复触发渲染）
  private currentNickname: string = getCurrentUser()?.nickname ?? '';

  // 注销确认弹窗控制器（构造期捕获 currentNickname）
  private deactivateController: CustomDialogController = new CustomDialogController({
    builder: DeactivateConfirmDialog({
      currentNickname: this.currentNickname,
      onConfirm: (): void => {
        this.doDeactivate();
      },
    }),
    autoCancel: false,
  });

  aboutToAppear(): void {
    this.isAdmin = getIsAdmin();
  }

  // 退出登录：二次确认 → 清态 + 跳登录页 + toast
  private onLogoutClick(): void {
    this.getUIContext().showAlertDialog({
      title: '退出登录？',
      message: '退出后需重新登录才能使用大蓝书。',
      primaryButton: {
        value: '取消',
        action: (): void => {},
      },
      secondaryButton: {
        value: '确定退出',
        fontColor: '#FF453A',
        action: (): void => {
          clearSession();
          AppStorage.setOrCreate('authIsAdmin', false);
          safeShowToast(this.getUIContext(), { message: '已退出登录' });
          router.replaceUrl({ url: 'pages/LoginPage' });
        },
      },
    });
  }

  // 账号注销：第一层意图确认 → 第二层输入/勾选确认（CustomDialog）
  private onDeactivateClick(): void {
    this.getUIContext().showAlertDialog({
      title: '注销账号？',
      message: '注销后你的账号将被永久关闭，昵称/头像将被匿名化且不可恢复；' +
        '你的帖子/评论将保留（匿名归属）。请谨慎操作。',
      primaryButton: {
        value: '取消',
        action: (): void => {},
      },
      secondaryButton: {
        value: '继续注销',
        fontColor: '#FF453A',
        action: (): void => {
          this.deactivateController.open();
        },
      },
    });
  }

  // 执行注销：调后端软删 → 清态 + 跳登录页 + toast（旧 token 经 auth 中间件全面失效）
  private async doDeactivate(): Promise<void> {
    try {
      await deactivateAccount();
      clearSession();
      AppStorage.setOrCreate('authIsAdmin', false);
      safeShowToast(this.getUIContext(), { message: '账号已注销' });
      router.replaceUrl({ url: 'pages/LoginPage' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  @Builder
  sectionRow(title: string, onTap: () => void): void {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1);
      Text('›')
        .fontSize(18)
        .fontColor($r('app.color.text_secondary'));
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .onClick(() => {
      onTap();
    });
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor($r('app.color.text_primary'))
          .width(48)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          });
        Text('设置')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Text('')
          .width(48);
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 });

      Scroll() {
        Column({ space: 24 }) {
          // 账号与安全
          Column({ space: 10 }) {
            Text('账号与安全')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(HorizontalAlign.Start)
              .padding({ left: 4 });
            this.sectionRow('编辑资料', (): void => {
              router.pushUrl({ url: 'pages/EditProfilePage' });
            });
            this.sectionRow('账号绑定', (): void => {
              router.pushUrl({ url: 'pages/AccountBindingPage' });
            });
            if (this.isAdmin) {
              this.sectionRow('内容审核台', (): void => {
                router.pushUrl({ url: 'pages/ModerationPage' });
              });
            }
          }
          .width('100%')

          // 通用
          Column({ space: 10 }) {
            Text('通用')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(HorizontalAlign.Start)
              .padding({ left: 4 });
            this.sectionRow('通知设置', (): void => {
              safeShowToast(this.getUIContext(), { message: '敬请期待' });
            });
            this.sectionRow('清除缓存', (): void => {
              safeShowToast(this.getUIContext(), { message: '敬请期待' });
            });
          }
          .width('100%')

          // 关于
          Column({ space: 10 }) {
            Text('关于')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(HorizontalAlign.Start)
              .padding({ left: 4 });
            this.sectionRow('关于大蓝书 · 版本 1.0.0', (): void => {
              safeShowToast(this.getUIContext(), { message: '大蓝书 1.0.0' });
            });
            this.sectionRow('隐私政策', (): void => {
              safeShowToast(this.getUIContext(), { message: '敬请期待' });
            });
          }
          .width('100%')

          // 退出登录（红色文字行）
          Row() {
            Text('退出登录')
              .fontSize(16)
              .fontColor('#FF453A')
              .layoutWeight(1);
            Text('›')
              .fontSize(18)
              .fontColor($r('app.color.text_secondary'));
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)
          .onClick(() => {
            this.onLogoutClick();
          });
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 16 });
      }
      .layoutWeight(1)
      .width('100%');

      // 底部：账号注销（警示更强，红色全宽按钮）
      Button('账号注销')
        .width('100%')
        .height(48)
        .margin({ left: 16, right: 16, bottom: 16 })
        .backgroundColor('#FF453A')
        .fontColor('#FFFFFF')
        .fontSize(16)
        .onClick(() => {
          this.onDeactivateClick();
        });
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'));
  }
}
