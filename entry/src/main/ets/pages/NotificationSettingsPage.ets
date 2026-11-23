// 通知设置页：展示 5 类通知开关（评论/点赞/收藏/关注/系统），Toggle 实时保存

import { getNotificationPrefs, updateNotificationPrefs } from '../services/api';
import { NotificationPrefs } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { CARD_RADIUS, CARD_SHADOW } from '../utils/cardTokens';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import type { HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import {
  buildPageTitleBarOptions,
  GlassTitleRow,
  GlassBarInsetRow,
} from '../design/components/HdsGlassBackSurface';
import { EmptyState } from '../design/components/EmptyState';
import { getUserId } from '../utils/auth';

interface PrefRow {
  key: string;
  label: string;
  desc: string;
}

@Entry
@Component
export struct NotificationSettingsPage {
  @State prefs: NotificationPrefs = { comment: true, up: true, bookmark: true, follow: true, system: true };
  @State loadFinished: boolean = false;
  @State loadError: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  private pageScroller: Scroller = new Scroller();

  private rows: PrefRow[] = [
    { key: 'comment', label: '评论通知', desc: '有人评论你的帖子时通知你' },
    { key: 'up', label: '点赞通知', desc: '有人给你的帖子点赞时通知你' },
    { key: 'bookmark', label: '收藏通知', desc: '有人收藏你的帖子时通知你' },
    { key: 'follow', label: '关注通知', desc: '有人关注你时通知你' },
    { key: 'system', label: '系统通知', desc: '审核结果、举报处理等系统消息' },
  ];

  aboutToAppear(): void {
    // 登录闸门：通知偏好是「我自己的账号设置」，未登录进来只会是「加载失败」空壳。
    // 用 replaceUrl 把本页从路由栈里替换掉 —— 取消登录返回时落到**入口页**（设置页）。
    if (getUserId() === 0) {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.loadPrefs();
  }

  private async loadPrefs(): Promise<void> {
    this.loadError = '';
    try {
      const p = await getNotificationPrefs();
      this.prefs = p;
    } catch (e) {
      this.loadError = (e as Error).message;
    }
    this.loadFinished = true;
  }

  private async onToggle(key: string): Promise<void> {
    // 乐观更新：先改 UI，再调后端
    // 快照当前值（arkts-no-spread，逐字段拷贝）
    const snapshot: NotificationPrefs = {
      comment: this.prefs.comment,
      up: this.prefs.up,
      bookmark: this.prefs.bookmark,
      follow: this.prefs.follow,
      system: this.prefs.system,
    };
    try {
      await updateNotificationPrefs(snapshot);
    } catch (e) {
      // 回滚：恢复快照值
      this.prefs.comment = snapshot.comment;
      this.prefs.up = snapshot.up;
      this.prefs.bookmark = snapshot.bookmark;
      this.prefs.follow = snapshot.follow;
      this.prefs.system = snapshot.system;
      safeShowToast(this.getUIContext(), { message: '保存失败：' + (e as Error).message });
    }
  }

  // 返回键走官方 backIcon（40vp 玻璃圆），action 槽仍是 router.back()，返回行为不变。
  private notificationSettingsTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildPageTitleBarOptions({
      back: (): void => { this.getUIContext().getRouter().back(); },
      stackBuilder: (): void => { this.notificationSettingsTitleRow(); },
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
    });
  }

  @Builder
  notificationSettingsTitleRow(): void {
    GlassTitleRow({ title: '通知设置', serif: true })
  }

  build() {
    HdsNavigation() {
      Column() {
        if (!this.loadFinished) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color($r('app.color.text_secondary'));
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center);
        } else if (this.loadError) {
          Column() {
            EmptyState({
              title: '加载失败',
              message: this.loadError,
              actionLabel: '重试',
              onAction: (): void => {
                this.loadFinished = false;
                this.loadPrefs();
              },
            })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center);
        } else {
          Scroll(this.pageScroller) {
            Column({ space: 10 }) {
              // 标题栏由 HdsNavigation 承担，内容先让出「状态栏 + 栏高」再排正文。
              GlassBarInsetRow({ statusBarHeight: this.statusBarHeight })

              ForEach(this.rows, (row: PrefRow) => {
                Row() {
                  Column() {
                    Text(row.label)
                      .fontSize(15).fontFamily($r('app.string.font_family'))
                      .fontColor($r('app.color.text_primary'));
                    Text(row.desc)
                      .fontSize(12).fontFamily($r('app.string.font_family'))
                      .fontColor($r('app.color.text_secondary'))
                      .margin({ top: 2 });
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start);

                  Toggle({ type: ToggleType.Switch, isOn: this.getPrefValue(row.key) })
                    .onChange((isOn: boolean) => {
                      this.setPrefValue(row.key, isOn);
                      this.onToggle(row.key);
                    });
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 16, bottom: 16 })
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(CARD_RADIUS)
                .shadow(CARD_SHADOW);
              });
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 32 })
            // 内容不足一屏时撑满视口：Scroll 默认会把不足一屏的子内容垂直居中，撑满即钉在顶部
            .constraintSize({ minHeight: '100%' });
          }
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .layoutWeight(1)
          .width('100%');
        }
      }
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .titleBar(this.notificationSettingsTitleBarOptions())
    .bindToScrollable([this.pageScroller])
    .clip(false)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }

  private getPrefValue(key: string): boolean {
    switch (key) {
      case 'comment': return this.prefs.comment;
      case 'up': return this.prefs.up;
      case 'bookmark': return this.prefs.bookmark;
      case 'follow': return this.prefs.follow;
      case 'system': return this.prefs.system;
      default: return true;
    }
  }

  private setPrefValue(key: string, value: boolean): void {
    switch (key) {
      case 'comment': this.prefs.comment = value; break;
      case 'up': this.prefs.up = value; break;
      case 'bookmark': this.prefs.bookmark = value; break;
      case 'follow': this.prefs.follow = value; break;
      case 'system': this.prefs.system = value; break;
    }
  }
}