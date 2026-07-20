// 关于页：纯静态信息展示，无后端调用

import { buildPageTransition } from '../utils/styles';

@Entry
@Component
export struct AboutPage {
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
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
        Text('关于')
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
        Column({ space: 20 }) {
          // App 图标占位
          Column() {
            Text('📘')
              .fontSize(48);
            Text('大蓝书')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ top: 8 });
            Text('版本 1.0.0')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 });
          }
          .width('100%')
          .padding({ top: 24, bottom: 24 });

          // 简介卡片
          Column() {
            Text('简介')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
              .padding({ left: 4, bottom: 8 });
            Column() {
              Text('大蓝书是一个男性生活经验分享社区。在这里，你可以分享购物测评、避坑指南、实用教程和生活心得，与志同道合的朋友互相学习、共同成长。')
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .lineHeight(24)
                .padding({ left: 16, right: 16, top: 16, bottom: 16 });
            }
            .width('100%')
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(12);
          }
          .width('100%');

          // 开发者信息
          Column() {
            Text('开发者')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start)
              .padding({ left: 4, bottom: 8 });
            Column() {
              Text('大蓝书团队')
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .padding({ left: 16, right: 16, top: 16, bottom: 8 });
              Text('© 2026 BigBlueBook. All rights reserved.')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .padding({ left: 16, right: 16, bottom: 16 });
            }
            .width('100%')
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(12);
          }
          .width('100%');
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 32 });
      }
      .layoutWeight(1)
      .width('100%');
    }
    .width('100%')
    .padding({ top: this.statusBarHeight })
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
}
