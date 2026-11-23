// 关于页：纯静态信息展示，无后端调用

import { common } from '@kit.AbilityKit';
import { buildPageTransition } from '../utils/styles';
import { APP_VERSION_NAME } from '../utils/buildMode';
import { RadiusTokens } from '../design/tokens/radius';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import type { HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import {
  buildPageTitleBarOptions,
  GlassTitleRow,
  GlassBarInsetRow,
} from '../design/components/HdsGlassBackSurface';

@Entry
@Component
export struct AboutPage {
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 交给 bindToScrollable 驱动栏级渐变模糊，玻璃珠才有内容可采样
  private pageScroller: Scroller = new Scroller();

  // 打开工信部 ICP 备案官网首页
  private openIcpBeian(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ctx.openLink('https://beian.miit.gov.cn/');
  }

  private aboutTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildPageTitleBarOptions({
      // action 槽原样保留 router.back()，不依赖 NavPathStack 默认 pop
      back: (): void => { this.getUIContext().getRouter().back(); },
      stackBuilder: (): void => { this.aboutTitleRow(); },
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
    });
  }

  @Builder
  aboutTitleRow(): void {
    GlassTitleRow({ title: '关于', serif: true })
  }

  build() {
    HdsNavigation() {
      Column() {
        Scroll(this.pageScroller) {
          Column({ space: 20 }) {
            // 穿底让位：状态栏 + MINI 栏高
            GlassBarInsetRow({ statusBarHeight: this.statusBarHeight });

            // 应用图标：与登录页同一资源（$r('app.media.logo')）、同款圆角（RadiusTokens.lg）
            // 此前是通用线条图标占位，关于页的品牌信息是审核常规核对项。
            Column() {
              Image($r('app.media.logo'))
                .width(72)
                .height(72)
                .borderRadius(RadiusTokens.lg);
              Text('有据')
                .fontSize(22).fontFamily($r('app.string.font_family'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .margin({ top: 8 });
              Text('版本 ' + APP_VERSION_NAME)
                .fontSize(14).fontFamily($r('app.string.font_family'))
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 });
            }
            .width('100%')
            .padding({ top: 24, bottom: 24 });

            // 简介卡片
            Column() {
              Text('简介')
                .fontSize(13).fontFamily($r('app.string.font_family'))
                .fontColor($r('app.color.text_secondary'))
                .alignSelf(ItemAlign.Start)
                .padding({ left: 4, bottom: 8 });
              Column() {
                Text('有据是一个面向大众的理性内容分享社区。在这里，你可以分享购物测评、避坑指南、实用教程和生活心得，与志同道合的朋友互相学习、共同成长。')
                  .fontSize(15).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.text_primary'))
                  .lineHeight(24)
                  .padding({ left: 16, right: 16, top: 16, bottom: 16 });
              }
              .width('100%')
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(8);
            }
            .width('100%');

            // 开发者信息
            Column() {
              Text('开发者')
                .fontSize(13).fontFamily($r('app.string.font_family'))
                .fontColor($r('app.color.text_secondary'))
                .alignSelf(ItemAlign.Start)
                .padding({ left: 4, bottom: 8 });
              Column() {
                Text('白逸飞')
                  .fontSize(15).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.text_primary'))
                  .padding({ left: 16, right: 16, top: 16, bottom: 8 });
                Text('© 2026 白逸飞 · 有据. All rights reserved.')
                  .fontSize(12).fontFamily($r('app.string.font_family'))
                  .fontColor($r('app.color.text_secondary'))
                  .padding({ left: 16, right: 16, bottom: 16 });
              }
              .width('100%')
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(8);
            }
            .width('100%');

            // 备案信息（ICP）
            Column() {
              Text('备案信息')
                .fontSize(13).fontFamily($r('app.string.font_family'))
                .fontColor($r('app.color.text_secondary'))
                .alignSelf(ItemAlign.Start)
                .padding({ left: 4, bottom: 8 });
              Column({ space: 8 }) {
                Row() {
                  Text('ICP备案号')
                    .fontSize(14).fontFamily($r('app.string.font_family'))
                    .fontColor($r('app.color.text_secondary'))
                  Text('陕ICP备2026014636号-2A')
                    .fontSize(14).fontFamily($r('app.string.font_family'))
                    .fontColor($r('app.color.brand_primary'))
                    // 链接至工信部备案官网首页
                    .onClick((): void => {
                      this.openIcpBeian();
                    })
                    .accessibilityText('陕ICP备2026014636号-2A，点击打开工信部备案官网')
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)

                Row() {
                  Text('服务名称')
                    .fontSize(14).fontFamily($r('app.string.font_family'))
                    .fontColor($r('app.color.text_secondary'))
                  Text('有据')
                    .fontSize(14).fontFamily($r('app.string.font_family'))
                    .fontColor($r('app.color.text_primary'))
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)

                Row() {
                  Text('域名')
                    .fontSize(14).fontFamily($r('app.string.font_family'))
                    .fontColor($r('app.color.text_secondary'))
                  Text('youju.chat')
                    .fontSize(14).fontFamily($r('app.string.font_family'))
                    .fontColor($r('app.color.text_primary'))
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)

                Row() {
                  Text('服务负责人')
                    .fontSize(14).fontFamily($r('app.string.font_family'))
                    .fontColor($r('app.color.text_secondary'))
                  Text('白逸飞')
                    .fontSize(14).fontFamily($r('app.string.font_family'))
                    .fontColor($r('app.color.text_primary'))
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 16, bottom: 16 })
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(8);
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
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .titleBar(this.aboutTitleBarOptions())
    .bindToScrollable([this.pageScroller])
    // 穿底绘制链路：自身不裁切，内容才能画到栏下被模糊采样
    .clip(false)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
}