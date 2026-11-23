// 隐私设置页：帖子可见性选择 + 允许关注/私信开关 + 保存按钮

import { getPrivacySettings, updatePrivacySettings } from '../services/api';
import { PrivacySettingsData } from '../models/types';
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

@Entry
@Component
export struct PrivacySettingsPage {
  @State settings: PrivacySettingsData = { postVisibility: 'public', allowFollow: true, dmPolicy: 'all', personalizedRecommendation: true };
  @State loadFinished: boolean = false;
  @State loadError: string = '';
  @State saving: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  private pageScroller: Scroller = new Scroller();

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
    // 登录闸门：隐私设置是「我自己的账号设置」，未登录进来只会是「加载失败」空壳。
    // 用 replaceUrl 把本页从路由栈里替换掉 —— 取消登录返回时落到**入口页**（设置页）。
    if (getUserId() === 0) {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
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

  // 返回键走官方 backIcon（40vp 玻璃圆），action 槽仍是 router.back()，返回行为不变。
  private privacySettingsTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildPageTitleBarOptions({
      back: (): void => { this.getUIContext().getRouter().back(); },
      stackBuilder: (): void => { this.privacySettingsTitleRow(); },
    });
  }

  @Builder
  privacySettingsTitleRow(): void {
    GlassTitleRow({
      title: '隐私设置',
      hasActions: true,
      actions: (): void => { this.privacySaveAction(); },
    });
  }

  // 保存按钮原样留在右侧
  @Builder
  privacySaveAction(): void {
    Text(this.saving ? '保存中' : '保存')
      .fontSize(15).fontFamily($r('app.string.font_family'))
      .fontColor(this.saving ? $r('app.color.text_secondary') : $r('app.color.ds_brand'))
      .width(56)
      .textAlign(TextAlign.Center)
      .onClick(() => { this.onSave(); });
  }

  build() {
    HdsNavigation() {
      Column() {
        if (!this.loadFinished) {
          Column() {
            LoadingProgress().width(40).height(40).color($r('app.color.text_secondary'));
          }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
        } else if (this.loadError) {
          Column() {
            EmptyState({
              title: '加载失败',
              message: this.loadError,
              actionLabel: '重试',
              onAction: (): void => { this.loadSettings(); },
            })
          }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
        } else {
          Scroll(this.pageScroller) {
            Column({ space: 24 }) {
              // 标题栏由 HdsNavigation 承担，内容先让出「状态栏 + 栏高」再排正文。
              GlassBarInsetRow({ statusBarHeight: this.statusBarHeight })

              // 帖子可见性
              Column({ space: 10 }) {
                Text('帖子可见性')
                  .fontSize(13).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.text_secondary'))
                  .alignSelf(ItemAlign.Start)
                  .padding({ left: 4 });

                Column({ space: 0 }) {
                  ForEach(this.visibilityOptions, (opt: string, idx: number) => {
                    Row() {
                      Text(this.visibilityLabels[idx])
                        .fontSize(15).fontFamily($r('app.string.font_family'))
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
                      Divider().color($r('app.color.divider')).margin({ left: 16 });
                    }
                  });
                }
                .width('100%')
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(CARD_RADIUS)
                .shadow(CARD_SHADOW)
                .clip(true);
              }
              .width('100%');

              // 允许关注
              Column({ space: 10 }) {
                Text('互动权限')
                  .fontSize(13).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.text_secondary'))
                  .alignSelf(ItemAlign.Start)
                  .padding({ left: 4 });

                Row() {
                  Column() {
                    Text('允许他人关注')
                      .fontSize(15).fontFamily($r('app.string.font_family'))
                      .fontColor($r('app.color.text_primary'));
                    Text('关闭后其他用户将无法关注你')
                      .fontSize(12).fontFamily($r('app.string.font_family'))
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
                          .fontSize(15).fontFamily($r('app.string.font_family'))
                          .fontColor($r('app.color.text_primary'))
                        Text(this.dmPolicyDesc[idx])
                          .fontSize(12).fontFamily($r('app.string.font_family'))
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
                      Divider().color($r('app.color.divider')).margin({ left: 16 });
                    }
                  });
                }
                .width('100%')
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(CARD_RADIUS)
                .shadow(CARD_SHADOW)
                .clip(true);
              }
              .width('100%');

              // 个性化推荐（合规：《互联网信息服务算法推荐管理规定》第 17 条——
              // 须提供便捷的关闭选项，且用户应能查看/选择/删除用于推荐的标签）
              Column({ space: 10 }) {
                Text('个性化推荐')
                  .fontSize(13).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.text_secondary'))
                  .alignSelf(ItemAlign.Start)
                  .padding({ left: 4 });

                Column({ space: 0 }) {
                  Row() {
                    Column() {
                      Text('接收个性化推荐')
                        .fontSize(15).fontFamily($r('app.string.font_family'))
                        .fontColor($r('app.color.text_primary'));
                      Text('关闭后「每日一贴」按热度与时间排序，不再依据你的浏览与互动记录')
                        .fontSize(12).fontFamily($r('app.string.font_family'))
                        .fontColor($r('app.color.text_secondary'))
                        .margin({ top: 2 });
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start);

                    Toggle({ type: ToggleType.Switch, isOn: this.settings.personalizedRecommendation })
                      .onChange((isOn: boolean) => {
                        this.settings.personalizedRecommendation = isOn;
                      });
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 16, bottom: 16 })
                  .backgroundColor($r('app.color.card_bg'));

                  Divider().color($r('app.color.divider')).margin({ left: 16 });

                  Row() {
                    Column() {
                      Text('兴趣标签管理')
                        .fontSize(15).fontFamily($r('app.string.font_family'))
                        .fontColor($r('app.color.text_primary'));
                      Text('查看并删除用于个性化推荐的标签')
                        .fontSize(12).fontFamily($r('app.string.font_family'))
                        .fontColor($r('app.color.text_secondary'))
                        .margin({ top: 2 });
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start);

                    Text('›')
                      .fontSize(18).fontFamily($r('app.string.font_family'))
                      .fontColor($r('app.color.text_secondary'));
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 16, bottom: 16 })
                  .backgroundColor($r('app.color.card_bg'))
                  .onClick(() => {
                    this.getUIContext().getRouter().pushUrl({ url: 'pages/InterestTagsPage' });
                  });

                  Divider().color($r('app.color.divider')).margin({ left: 16 });

                  // 算法申诉入口（PIPL 第 24 条：自动化决策的说明请求与拒绝权）
                  Row() {
                    Column() {
                      Text('对推荐结果有疑问？')
                        .fontSize(15).fontFamily($r('app.string.font_family'))
                        .fontColor($r('app.color.text_primary'));
                      Text('了解推荐原理，或按隐私政策第 8 节向我们申诉与反馈')
                        .fontSize(12).fontFamily($r('app.string.font_family'))
                        .fontColor($r('app.color.text_secondary'))
                        .margin({ top: 2 });
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start);

                    Text('›')
                      .fontSize(18).fontFamily($r('app.string.font_family'))
                      .fontColor($r('app.color.text_secondary'));
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 16, bottom: 16 })
                  .backgroundColor($r('app.color.card_bg'))
                  .onClick(() => {
                    this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPage' });
                  });
                }
                .width('100%')
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(CARD_RADIUS)
                .shadow(CARD_SHADOW)
                .clip(true);
              }
              .width('100%');
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 32 });
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
    .titleBar(this.privacySettingsTitleBarOptions())
    .bindToScrollable([this.pageScroller])
    .clip(false)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
}