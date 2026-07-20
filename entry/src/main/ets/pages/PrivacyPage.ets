// 隐私政策页：内置静态隐私政策文本，无后端调用
import { router } from '@kit.ArkUI';

@Entry
@Component
export struct PrivacyPage {
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
        Text('隐私政策')
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
        Column({ space: 16 }) {
          Text('更新日期：2026 年 7 月 20 日\n生效日期：2026 年 7 月 20 日')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ left: 16, right: 16 });

          Text('大蓝书（以下简称"我们"）深知个人信息对你的重要性，并将按法律法规要求，采取相应的安全保护措施，尽力保护你的个人信息安全可控。')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(24)
            .width('100%')
            .padding({ left: 16, right: 16 });

          this.section('1. 我们收集的信息', [
            '账号信息：当你注册账号时，我们会收集你的鸿蒙账号 OpenID 或华为账号 UnionID、昵称和头像。',
            '内容信息：你在平台上发布的帖子、评论、收藏等操作记录。',
            '设备信息：为保障服务安全稳定，我们会收集设备型号、操作系统版本等基础信息。',
          ]);

          this.section('2. 信息的使用', [
            '向你展示推荐内容和个性化服务。',
            '用于改善产品体验和功能优化。',
            '保障平台秩序，识别和阻止违规行为。',
          ]);

          this.section('3. 信息的存储与保护', [
            '你的个人信息存储于中国境内的服务器。',
            '我们采用加密传输（HTTPS）、访问控制等技术手段保护你的数据安全。',
            '除非法律法规要求，我们不会主动向第三方提供你的个人信息。',
          ]);

          this.section('4. 你的权利', [
            '你可随时编辑或删除你的个人信息（设置 → 编辑资料）。',
            '你可随时注销你的账号（设置 → 账号注销），注销后你的昵称和头像将被匿名化。',
            '你可通过数据导出功能获取你的数据副本（设置 → 数据导出）。',
          ]);

          this.section('5. 联系我们', [
            '如有任何隐私相关问题或建议，请联系我们：',
            '邮箱：privacy@bigbluebook.com',
          ]);

          Text('本隐私政策可能适时更新。如发生重大变更，我们将通过应用内通知的方式告知你。')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(20)
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 32 });
        }
        .width('100%')
        .padding({ top: 8 });
      }
      .layoutWeight(1)
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(TransitionEffect.OPACITY
      .animation({ duration: 300, curve: Curve.EaseOut })
      .combine(TransitionEffect.translate({ x: 50 })
        .animation({ duration: 350, curve: Curve.EaseOut })))
  }

  @Builder
  section(title: string, items: string[]): void {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)
        .padding({ bottom: 8 });

      ForEach(items, (item: string) => {
        Text('• ' + item)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(24)
          .padding({ bottom: 4 })
          .width('100%');
      });
    }
    .width('100%')
    .padding({ left: 16, right: 16 });
  }
}
