// 设置页：分区结构（账号与安全 / 隐私 / 通用 / 关于）+ 退出登录 + 账号注销。
// 覆盖全部设置功能：编辑资料、账号绑定、内容审核台、拉黑管理、数据导出、隐私设置、通知设置、清除缓存、关于、隐私政策。

import { getIsAdmin, clearSession, getUserId } from '../utils/auth';
import { clearPushToken } from '../utils/push';
import { deactivateAccount, clearSearchHistory, exportUserData } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { toggleDarkMode, setFollowSystem } from '../utils/theme';
import { buildPageTransition } from '../utils/styles';
import { CARD_RADIUS } from '../utils/cardTokens';
import { resolveSettingsIcon } from '../utils/settingsIcons';
import { window } from '@kit.ArkUI';
import { BackButton } from '../design/components/BackButton';
import { shareUserDataExport } from '../utils/dataExport';

@Entry
@Component
export struct SettingsPage {
  @State isAdmin: boolean = getIsAdmin();
  // 登录态（持久化）：用于控制「退出登录 / 账号注销」这类对访客毫无意义的行显隐。
  // 用 @StorageLink 而不是 getUserId() —— 登录成功后返回本页，页面不会重建，
  // 只有 StorageLink 能触发刷新。
  @StorageLink('authUserId') authUserId: string = '';
  @StorageLink('isDarkMode') darkMode: boolean = false;
  @StorageLink('followSystem') followSystem: boolean = true;
  @State statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.isAdmin = getIsAdmin();
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
      this.statusBarHeight = this.getUIContext().px2vp(area.topRect.height);
    } catch (e) {
      // 读取失败维持 0
    }
  }

  // 是否已登录（响应式读取，登录/登出后本页立即跟上）
  private loggedIn(): boolean {
    const v: string = (this.authUserId ?? '') as string;
    return v.length > 0 && v !== '0';
  }

  // 需登录的**页面型**设置项统一入口：未登录时不进目标页，就地引导登录。
  // 这里用 push（不是 replaceUrl）—— 设置页要留在路由栈里，登录或取消登录返回后仍在设置页。
  // 目标页自身也有一道 aboutToAppear 闸门（replaceUrl 兜底），两条一起才覆盖所有入口。
  private openGated(url: string): void {
    if (getUserId() === 0) {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.getUIContext().getRouter().pushUrl({ url: url });
  }

  // 需登录的**就地动作**（不跳页，如数据导出）：返回 false 表示已被拦截，调用方直接放弃。
  private gatedActionPassed(): boolean {
    if (getUserId() === 0) {
      safeShowToast(this.getUIContext(), { message: '请先登录后再使用' });
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
      return false;
    }
    return true;
  }

  // 退出登录：二次确认 → 清态 + 跳登录页 + toast
  private onLogoutClick(): void {
    this.getUIContext().showAlertDialog({
      title: '退出登录？',
      message: '退出后需重新登录才能使用有据。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '确定退出', fontColor: $r('app.color.semantic_red'),
        action: (): void => {
          // 先解绑推送 Token：解绑请求依赖鉴权 Header，必须在 clearSession 之前发出。
          // 失败也不阻断登出（内部已兜底），最多残留旧绑定，换号登录时会随 register 迁移。
          clearPushToken();
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
      clearPushToken();
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
        // 访客没有服务端搜索历史（该接口需鉴权，未登录调用必然 401）→ 直接按「已清除」收尾，
        // 不为清一个空缓存把人踢去登录页。
        if (getUserId() === 0) {
          safeShowToast(this.getUIContext(), { message: '缓存已清除' });
          return;
        }
        try {
          await clearSearchHistory();
          safeShowToast(this.getUIContext(), { message: '缓存已清除' });
        } catch (e) {
          safeShowToast(this.getUIContext(), { message: (e as Error).message });
        }
      } },
    });
  }

  // 数据导出：确认弹窗 → 获取已鉴权 JSON → 写缓存文件并交由系统保存/分享。
  private onExportDataClick(): void {
    this.getUIContext().showAlertDialog({
      title: '导出数据',
      message: '将导出你的全部数据（个人信息、帖子、评论、收藏等），导出数据仅你本人可见。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '确认导出', action: async (): Promise<void> => {
        try {
          const data = await exportUserData();
          await shareUserDataExport(this.getUIContext(), data);
          safeShowToast(this.getUIContext(), { message: '数据导出文件已生成' });
        } catch (e) {
          // shareUserDataExport 已带阶段标记（[导出-文件]/[导出-分享面板]）；其余按网络阶段标注
          const msg: string = (e as Error).message ?? '';
          safeShowToast(this.getUIContext(), { message: msg.startsWith('[导出-') ? msg : '[导出-网络] ' + msg });
        }
      } },
    });
  }

  @Builder
  sectionRow(icon: string, title: string, onTap: () => void): void {
    ListItem() {
      Row({ space: 12 }) {
        Image(resolveSettingsIcon(icon))
          .width(22).height(22)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.ds_icon'))
        Text(title)
          .fontSize(16).fontFamily($r('app.string.font_family'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1);
        Image(resolveSettingsIcon('chevronRight'))
          .width(18).height(18)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.ds_icon'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .onClick(() => { onTap(); })
    }
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Text('设置')
          .fontSize(17).fontFamily($r('app.string.font_family'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Text('').width(44);
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 });

      List({ space: 8 }) {
        // ===== 账号与安全 =====
        ListItem() {
          Text('账号与安全')
            .fontSize(13).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 16, top: 8 })
        }

        ListItemGroup() {
          this.sectionRow('phone', '账号绑定', (): void => {
            this.openGated('pages/AccountBindingPage');
          })
          if (this.isAdmin) {
            this.sectionRow('book', '举报中心', (): void => {
              this.openGated('pages/ReportAdminPage');
            })
          }
          this.sectionRow('block', '拉黑管理', (): void => {
            this.openGated('pages/BlocklistPage');
          })
          this.sectionRow('export', '数据导出', (): void => {
            if (this.gatedActionPassed()) {
              this.onExportDataClick();
            }
          })
        }
        .borderRadius(CARD_RADIUS)
        .backgroundColor($r('app.color.card_bg'))
        .clip(true)

        // ===== 隐私 =====
        ListItem() {
          Text('隐私')
            .fontSize(13).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 16, top: 8 })
        }

        ListItemGroup() {
          this.sectionRow('lock', '隐私设置', (): void => {
            this.openGated('pages/PrivacySettingsPage');
          })
          this.sectionRow('bell', '通知设置', (): void => {
            this.openGated('pages/NotificationSettingsPage');
          })
        }
        .borderRadius(CARD_RADIUS)
        .backgroundColor($r('app.color.card_bg'))
        .clip(true)

        // ===== 通用 =====
        ListItem() {
          Text('通用')
            .fontSize(13).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 16, top: 8 })
        }

        ListItemGroup() {
          ListItem() {
            Row({ space: 12 }) {
              Image(resolveSettingsIcon('system'))
                .width(22).height(22)
                .objectFit(ImageFit.Contain)
                .fillColor($r('app.color.ds_icon'))
              Column({ space: 2 }) {
                Text('跟随系统')
                  .fontSize(16).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.text_primary'))
                Text('关闭后可手动选择深浅模式')
                  .fontSize(12).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.followSystem })
                .onChange((on: boolean): void => {
                  if (on === this.followSystem) {
                    return;
                  }
                  setFollowSystem(on);
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          }

          ListItem() {
            Row({ space: 12 }) {
              Image(resolveSettingsIcon('dark'))
                .width(22).height(22)
                .objectFit(ImageFit.Contain)
                .fillColor($r('app.color.ds_icon'))
              Column({ space: 2 }) {
                Text('深色模式')
                  .fontSize(16).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.text_primary'))
                Text('关闭后使用浅色主题')
                  .fontSize(12).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.darkMode })
                .enabled(!this.followSystem)
                .opacity(!this.followSystem ? 1 : 0.4)
                .onChange((on: boolean): void => {
                  if (this.followSystem || on === this.darkMode) {
                    return;
                  }
                  toggleDarkMode(on);
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          }

          this.sectionRow('trash', '清除缓存', (): void => {
            this.onClearCacheClick();
          })
        }
        .borderRadius(CARD_RADIUS)
        .backgroundColor($r('app.color.card_bg'))
        .clip(true)

        // ===== 关于 =====
        ListItem() {
          Text('关于')
            .fontSize(13).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 16, top: 8 })
        }

        ListItemGroup() {
          this.sectionRow('book', '关于有据 · 版本 1.0.1', (): void => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/AboutPage' });
          })
          this.sectionRow('policy', '隐私政策', (): void => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPage' });
          })
        }
        .borderRadius(CARD_RADIUS)
        .backgroundColor($r('app.color.card_bg'))
        .clip(true)

        // ===== 退出登录 / 账号注销 =====
        if (this.loggedIn()) {
          ListItemGroup() {
            ListItem() {
              Row({ space: 12 }) {
                Image(resolveSettingsIcon('logout'))
                  .width(22).height(22)
                  .objectFit(ImageFit.Contain)
                  .fillColor($r('app.color.ds_icon'))
                Text('退出登录')
                  .fontSize(16).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.semantic_red'))
                  .layoutWeight(1);
                Image(resolveSettingsIcon('chevronRight'))
                  .width(18).height(18)
                  .objectFit(ImageFit.Contain)
                  .fillColor($r('app.color.ds_icon'))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => { this.onLogoutClick(); })
            }

            ListItem() {
              Row({ space: 12 }) {
                Image(resolveSettingsIcon('trash'))
                  .width(22).height(22)
                  .objectFit(ImageFit.Contain)
                  .fillColor($r('app.color.ds_icon'))
                Text('账号注销')
                  .fontSize(16).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.semantic_red'))
                  .layoutWeight(1);
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => { this.onDeactivateClick(); })
            }
          }
          .borderRadius(CARD_RADIUS)
          .backgroundColor($r('app.color.card_bg'))
          .clip(true)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 16 });
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarHeight })
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition());
  }
}
