// 设置页：分区结构（账号与安全 / 隐私 / 通用 / 关于）+ 退出登录 + 账号注销。
// 覆盖全部设置功能：编辑资料、账号绑定、内容审核台、拉黑管理、数据导出、隐私设置、通知设置、清除缓存、关于、隐私政策。

import { getIsAdmin, clearSession } from '../utils/auth';
import { deactivateAccount, clearSearchHistory, exportUserData } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { toggleDarkMode, isDarkMode, isFollowSystem, setFollowSystem, getSystemDark } from '../utils/theme';
import { buildPageTransition } from '../utils/styles';
import { CARD_RADIUS, CARD_SHADOW } from '../utils/cardTokens';
import { resolveSettingsIcon } from '../utils/settingsIcons';
import { window } from '@kit.ArkUI';

@Entry
@Component
export struct SettingsPage {
  @State isAdmin: boolean = getIsAdmin();
  @State darkMode: boolean = isDarkMode();
  @State followSystem: boolean = isFollowSystem();
  @State statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.isAdmin = getIsAdmin();
    this.darkMode = isDarkMode();
    this.followSystem = isFollowSystem();
    this.loadStatusBarHeight();
  }

  private async loadStatusBarHeight(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (!ctx) {
        return;
      }
      const win = await window.getLastWindow(ctx);
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = px2vp(area.topRect.height);
    } catch (e) {
      // 读取失败维持 0
    }
  }

  // 退出登录：二次确认 → 清态 + 跳登录页 + toast
  private onLogoutClick(): void {
    this.getUIContext().showAlertDialog({
      title: '退出登录？',
      message: '退出后需重新登录才能使用大蓝书。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '确定退出', fontColor: $r('app.color.semantic_red'),
        action: (): void => {
          clearSession();
          AppStorage.setOrCreate('authIsAdmin', false);
          safeShowToast(this.getUIContext(), { message: '已退出登录' });
          this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
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
      secondaryButton: { value: '继续注销', fontColor: $r('app.color.semantic_red'), action: (): void => {
        this.getUIContext().showAlertDialog({
          title: '再次确认',
          message: '此操作不可恢复，确定要注销账号吗？',
          primaryButton: { value: '取消', action: (): void => {} },
          secondaryButton: { value: '确认注销', fontColor: $r('app.color.semantic_red'), action: (): void => { this.doDeactivate(); } },
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
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
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
  sectionRow(icon: string, title: string, onTap: () => void): void {
    Row({ space: 12 }) {
      Image(resolveSettingsIcon(icon))
        .width(22).height(22)
        .fillColor($r('app.color.text_secondary'))
        .objectFit(ImageFit.Contain)
      Text(title)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1);
      Image(resolveSettingsIcon('chevronRight'))
        .width(18).height(18)
        .fillColor($r('app.color.text_tertiary'))
        .objectFit(ImageFit.Contain)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(CARD_RADIUS)
    .shadow(CARD_SHADOW)
    .stateStyles({
      normal: {
        .opacity(1)
      },
      pressed: {
        .opacity(0.7)
        .scale({ x: 0.97, y: 0.97 })
      }
    })
    .onClick(() => { onTap(); });
  }

  @Builder
  toggleRow(icon: string, title: string, desc: string, isOn: boolean, onChange: (on: boolean) => void): void {
    Row({ space: 12 }) {
      Image(resolveSettingsIcon(icon))
        .width(22).height(22)
        .fillColor($r('app.color.text_secondary'))
        .objectFit(ImageFit.Contain)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
        Text(desc)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange((on: boolean) => {
          onChange(on);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(CARD_RADIUS)
    .shadow(CARD_SHADOW)
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Row() {
          Image(resolveSettingsIcon('back'))
            .width(24).height(24)
            .fillColor($r('app.color.text_primary'))
        }
        .width(48).height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.getUIContext().getRouter().back(); });
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
            this.sectionRow('edit', '编辑资料', (): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/EditProfilePage' });
            });
            this.sectionRow('phone', '账号绑定', (): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/AccountBindingPage' });
            });
            if (this.isAdmin) {
              this.sectionRow('shield', '内容审核台', (): void => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/ModerationPage' });
              });
            }
            this.sectionRow('block', '拉黑管理', (): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/BlocklistPage' });
            });
            this.sectionRow('export', '数据导出', (): void => {
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
            this.sectionRow('lock', '隐私设置', (): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacySettingsPage' });
            });
            this.sectionRow('bell', '通知设置', (): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/NotificationSettingsPage' });
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

            // 跟随系统
            this.toggleRow('system', '跟随系统', '关闭后可手动选择深浅模式', this.followSystem, (on: boolean): void => {
              this.followSystem = on;
              setFollowSystem(on);
              if (on) {
                this.darkMode = getSystemDark();
              }
            });

            // 深色模式（仅在不跟随系统时可用）
            if (!this.followSystem) {
              this.toggleRow('dark', '深色模式', '关闭后使用浅色主题', this.darkMode, (on: boolean): void => {
                this.darkMode = on;
                toggleDarkMode(on);
              });
            }

            this.sectionRow('trash', '清除缓存', (): void => {
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
            this.sectionRow('book', '关于大蓝书 · 版本 1.0.0', (): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/AboutPage' });
            });
            this.sectionRow('policy', '隐私政策', (): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPage' });
            });
          }
          .width('100%');

          // 退出登录（红色文字行，卡片风格）
          Row({ space: 12 }) {
            Image(resolveSettingsIcon('logout'))
              .width(22).height(22)
              .fillColor($r('app.color.semantic_red'))
              .objectFit(ImageFit.Contain)
            Text('退出登录')
              .fontSize(16)
              .fontColor($r('app.color.semantic_red'))
              .layoutWeight(1);
            Image(resolveSettingsIcon('chevronRight'))
              .width(18).height(18)
              .fillColor($r('app.color.text_tertiary'))
              .objectFit(ImageFit.Contain)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(CARD_RADIUS)
          .shadow(CARD_SHADOW)
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
        .backgroundColor($r('app.color.semantic_red'))
        .fontColor('#FFFFFF')
        .fontSize(16)
        .borderRadius(CARD_RADIUS)
        .onClick(() => { this.onDeactivateClick(); });
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarHeight })
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition());
  }
}
