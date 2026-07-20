// 设置页：分区结构（账号与安全 / 隐私 / 通用 / 关于）+ 退出登录 + 账号注销。
// 覆盖全部设置功能：编辑资料、账号绑定、内容审核台、拉黑管理、数据导出、隐私设置、通知设置、清除缓存、关于、隐私政策。
import { router } from '@kit.ArkUI';
import { getIsAdmin, clearSession } from '../utils/auth';
import { deactivateAccount, clearSearchHistory, exportUserData } from '../services/api';
import { safeShowToast } from '../utils/toast';

@Entry
@Component
export struct SettingsPage {
  @State isAdmin: boolean = getIsAdmin();

  aboutToAppear(): void {
    this.isAdmin = getIsAdmin();
  }

  // 退出登录：二次确认 → 清态 + 跳登录页 + toast
  private onLogoutClick(): void {
    this.getUIContext().showAlertDialog({
      title: '退出登录？',
      message: '退出后需重新登录才能使用大蓝书。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '确定退出', fontColor: '#FF453A',
        action: (): void => {
          clearSession();
          AppStorage.setOrCreate('authIsAdmin', false);
          safeShowToast(this.getUIContext(), { message: '已退出登录' });
          router.replaceUrl({ url: 'pages/LoginPage' });
        },
      },
    });
  }

  // 账号注销：第一层意图确认 → 第二层再次确认
  private onDeactivateClick(): void {
    this.getUIContext().showAlertDialog({
      title: '注销账号？',
      message: '注销后你的账号将被永久关闭，昵称/头像将被匿名化且不可恢复；你的帖子/评论将保留（匿名归属）。请谨慎操作。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '继续注销', fontColor: '#FF453A', action: (): void => {
        this.getUIContext().showAlertDialog({
          title: '再次确认',
          message: '此操作不可恢复，确定要注销账号吗？',
          primaryButton: { value: '取消', action: (): void => {} },
          secondaryButton: { value: '确认注销', fontColor: '#FF453A', action: (): void => { this.doDeactivate(); } },
        });
      } },
    });
  }

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

  // 清除缓存：确认弹窗 → 清搜索历史（API） + toast
  private onClearCacheClick(): void {
    this.getUIContext().showAlertDialog({
      title: '清除缓存？',
      message: '将清除搜索历史等本地缓存数据，不影响你的帖子与账号。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '确定清除', action: async (): Promise<void> => {
        try {
          await clearSearchHistory();
          safeShowToast(this.getUIContext(), { message: '缓存已清除' });
        } catch (e) {
          safeShowToast(this.getUIContext(), { message: (e as Error).message });
        }
      } },
    });
  }

  // 数据导出：确认弹窗 → 调后端导出 → toast
  private onExportDataClick(): void {
    this.getUIContext().showAlertDialog({
      title: '导出数据',
      message: '将导出你的全部数据（个人信息、帖子、评论、收藏等），导出数据仅你本人可见。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '确认导出', action: async (): Promise<void> => {
        try {
          const data = await exportUserData();
          // MVP：toast 展示导出数量，文件写入后续实现
          const msg = '数据已导出：帖子' + data.postsCount + '篇、评论' + data.commentsCount +
            '条、收藏' + data.bookmarksCount + '个、关注' + data.followingsCount + '人';
          safeShowToast(this.getUIContext(), { message: msg });
        } catch (e) {
          safeShowToast(this.getUIContext(), { message: '导出失败：' + (e as Error).message });
        }
      } },
    });
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
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
    .backgroundColor('rgba(255,255,255,0.04)')
    .border({ width: 0.5, color: 'rgba(255,255,255,0.08)' })
    .borderRadius(12)
    .onClick(() => { onTap(); });
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor($r('app.color.text_primary'))
          .width(48).height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => { router.back(); });
        Text('设置')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Text('').width(48);
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 });

      Scroll() {
        Column({ space: 24 }) {
          // ===== 账号与安全 =====
          Column({ space: 10 }) {
            Text('账号与安全')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
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
            this.sectionRow('拉黑管理', (): void => {
              router.pushUrl({ url: 'pages/BlocklistPage' });
            });
            this.sectionRow('数据导出', (): void => {
              this.onExportDataClick();
            });
          }
          .width('100%');

          // ===== 隐私 =====
          Column({ space: 10 }) {
            Text('隐私')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
              .padding({ left: 4 });
            this.sectionRow('隐私设置', (): void => {
              router.pushUrl({ url: 'pages/PrivacySettingsPage' });
            });
            this.sectionRow('通知设置', (): void => {
              router.pushUrl({ url: 'pages/NotificationSettingsPage' });
            });
          }
          .width('100%');

          // ===== 通用 =====
          Column({ space: 10 }) {
            Text('通用')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
              .padding({ left: 4 });
            this.sectionRow('清除缓存', (): void => {
              this.onClearCacheClick();
            });
          }
          .width('100%');

          // ===== 关于 =====
          Column({ space: 10 }) {
            Text('关于')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
              .padding({ left: 4 });
            this.sectionRow('关于大蓝书 · 版本 1.0.0', (): void => {
              router.pushUrl({ url: 'pages/AboutPage' });
            });
            this.sectionRow('隐私政策', (): void => {
              router.pushUrl({ url: 'pages/PrivacyPage' });
            });
          }
          .width('100%');

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
          .onClick(() => { this.onLogoutClick(); });
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 16 });
      }
      .layoutWeight(1)
      .width('100%');

      // 底部：账号注销（红色全宽按钮）
      Button('账号注销')
        .width('100%')
        .height(48)
        .margin({ left: 16, right: 16, bottom: 16 })
        .backgroundColor('#FF453A')
        .fontColor('#FFFFFF')
        .fontSize(16)
        .onClick(() => { this.onDeactivateClick(); });
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(TransitionEffect.OPACITY
      .animation({ duration: 300, curve: Curve.EaseOut })
      .combine(TransitionEffect.translate({ x: 50 })
        .animation({ duration: 350, curve: Curve.EaseOut })));
  }
}
