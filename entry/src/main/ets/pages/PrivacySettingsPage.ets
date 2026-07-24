// 隐私设置页：帖子可见性选择 + 允许关注/私信开关 + 保存按钮

import { getPrivacySettings, updatePrivacySettings } from '../services/api';
import { PrivacySettingsData } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { CARD_RADIUS, CARD_SHADOW } from '../utils/cardTokens';
import { resolveSettingsIcon } from '../utils/settingsIcons';

@Entry
@Component
export struct PrivacySettingsPage {
  @State settings: PrivacySettingsData = { postVisibility: 'public', allowFollow: true, dmPolicy: 'all' };
  @State loadFinished: boolean = false;
  @State loadError: string = '';
  @State saving: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  private visibilityOptions: string[] = [
    'public',
    'followers',
    'private',
  ];

  private visibilityLabels: string[] = [
    '公开 — 所有人可见',
    '仅粉丝 — 仅关注你的人可见',
    '私密 — 仅自己可见',
  ];

  private dmPolicyOptions: string[] = ['all', 'mutual', 'followers'];
  private dmPolicyLabels: string[] = ['所有人可发', '仅互关好友', '仅粉丝'];
  private dmPolicyDesc: string[] = [
    '所有用户都能给你发私信',
    '只有互相关注的好友能给你发私信',
    '只有你的粉丝能给你发私信',
  ];

  aboutToAppear(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    this.loadError = '';
    this.loadFinished = false;
    try {
      const s = await getPrivacySettings();
      this.settings = s;
    } catch (e) {
      this.loadError = (e as Error).message;
    }
    this.loadFinished = true;
  }

  private async onSave(): Promise<void> {
    if (this.saving) return;
    this.saving = true;
    try {
      await updatePrivacySettings(this.settings);
      safeShowToast(this.getUIContext(), { message: '隐私设置已保存' });
      this.getUIContext().getRouter().back();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '保存失败：' + (e as Error).message });
    }
    this.saving = false;
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
        Text('隐私设置')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        // 保存按钮放在右侧
        Text(this.saving ? '保存中' : '保存')
          .fontSize(15)
          .fontColor(this.saving ? $r('app.color.text_secondary') : '#007AFF')
          .width(56)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.onSave(); });
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 });

      if (!this.loadFinished) {
        Column() {
          LoadingProgress().width(40).height(40).color($r('app.color.text_secondary'));
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else if (this.loadError) {
        Column() {
          Text('加载失败').fontSize(15).fontColor($r('app.color.text_secondary'));
          Button('重试').margin({ top: 12 }).onClick(() => { this.loadSettings(); });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else {
        Scroll() {
          Column({ space: 24 }) {
            // 帖子可见性
            Column({ space: 10 }) {
              Text('帖子可见性')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .alignSelf(ItemAlign.Start)
                .padding({ left: 4 });

              Column({ space: 0 }) {
                ForEach(this.visibilityOptions, (opt: string, idx: number) => {
                  Row() {
                    Text(this.visibilityLabels[idx])
                      .fontSize(15)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1);
                    Radio({ value: opt, group: 'visibilityGroup' })
                      .checked(this.settings.postVisibility === opt)
                      .onChange((isChecked: boolean) => {
                        if (isChecked) {
                          this.settings.postVisibility = opt;
                        }
                      });
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                  .backgroundColor($r('app.color.card_bg'));
                  if (idx < this.visibilityOptions.length - 1) {
                    Divider().color('#1AFFFFFF').margin({ left: 16 });
                  }
                });
              }
              .width('100%')
              .borderRadius(CARD_RADIUS)
              .shadow(CARD_SHADOW);
            }
            .width('100%');

            // 允许关注
            Column({ space: 10 }) {
              Text('互动权限')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .alignSelf(ItemAlign.Start)
                .padding({ left: 4 });

              Row() {
                Column() {
                  Text('允许他人关注')
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'));
                  Text('关闭后其他用户将无法关注你')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 2 });
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Toggle({ type: ToggleType.Switch, isOn: this.settings.allowFollow })
                  .onChange((isOn: boolean) => {
                    this.settings.allowFollow = isOn;
                  });
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 16, bottom: 16 })
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(CARD_RADIUS)
              .shadow(CARD_SHADOW);

              Column({ space: 0 }) {
                ForEach(this.dmPolicyOptions, (opt: string, idx: number) => {
                  Row() {
                    Column() {
                      Text(this.dmPolicyLabels[idx])
                        .fontSize(15)
                        .fontColor($r('app.color.text_primary'))
                      Text(this.dmPolicyDesc[idx])
                        .fontSize(12)
                        .fontColor($r('app.color.text_secondary'))
                        .margin({ top: 2 })
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start);

                    Radio({ value: opt, group: 'dmPolicyGroup' })
                      .checked(this.settings.dmPolicy === opt)
                      .onChange((isChecked: boolean) => {
                        if (isChecked) {
                          this.settings.dmPolicy = opt;
                        }
                      });
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                  .backgroundColor($r('app.color.card_bg'))
                  if (idx < this.dmPolicyOptions.length - 1) {
                    Divider().color('#1AFFFFFF').margin({ left: 16 });
                  }
                });
              }
              .width('100%')
              .borderRadius(CARD_RADIUS)
              .shadow(CARD_SHADOW);
            }
            .width('100%');
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
}
