// 通知设置页：展示 5 类通知开关（评论/点赞/收藏/关注/系统），Toggle 实时保存

import { getNotificationPrefs, updateNotificationPrefs } from '../services/api';
import { NotificationPrefs } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';

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

  private rows: PrefRow[] = [
    { key: 'comment', label: '评论通知', desc: '有人评论你的帖子时通知你' },
    { key: 'up', label: '点赞通知', desc: '有人给你的帖子点赞时通知你' },
    { key: 'bookmark', label: '收藏通知', desc: '有人收藏你的帖子时通知你' },
    { key: 'follow', label: '关注通知', desc: '有人关注你时通知你' },
    { key: 'system', label: '系统通知', desc: '审核结果、举报处理等系统消息' },
  ];

  aboutToAppear(): void {
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
            this.getUIContext().getRouter().back();
          });
        Text('通知设置')
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
          Text('加载失败')
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'));
          Text(this.loadError)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 });
          Button('重试')
            .margin({ top: 12 })
            .onClick(() => {
              this.loadFinished = false;
              this.loadPrefs();
            });
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center);
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.rows, (row: PrefRow) => {
              Row() {
                Column() {
                  Text(row.label)
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'));
                  Text(row.desc)
                    .fontSize(12)
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
              .borderRadius(12);
            });
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 32 });
        }
        .layoutWeight(1)
        .width('100%');
      }
    }
    .width('100%')
    .padding({ top: this.statusBarHeight })
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
