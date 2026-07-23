// 用户协议页：内置静态用户协议文本，无后端调用

import { buildPageTransition } from '../utils/styles';

@Entry
@Component
export struct UserAgreementPage {
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
        Text('用户协议')
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

          Text('欢迎使用大蓝书（以下简称"本应用"）。在使用本应用前，请您仔细阅读并充分理解本《用户协议》（以下简称"本协议"）。一旦您注册、登录或使用本应用，即表示您已阅读、理解并同意接受本协议的全部内容。')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(24)
            .width('100%')
            .padding({ left: 16, right: 16 });

          this.section('1. 服务条款', [
            '本应用为男性生活经验交流社区，提供内容发布、评论、收藏、关注等基础服务。',
            '我们保留随时修改、暂停或终止部分或全部服务的权利，并在合理范围内提前通知。',
            '您使用本应用应遵守中华人民共和国相关法律法规及平台社区规范。',
          ]);

          this.section('2. 账号注册与使用', [
            '您需通过华为账号或本应用提供的其他登录方式注册账号，并保证所填信息真实、合法、有效。',
            '您的账号由您本人妥善保管，因账号保管不善导致的损失由您自行承担。',
            '您同意不将账号转让、出借或售卖给第三方；我们有权对违规账号采取限制或封禁措施。',
          ]);

          this.section('3. 内容发布规范', [
            '您对所发布的内容（帖子、评论、图片等）的真实性、合法性负责。',
            '禁止发布违法、暴力、色情、诈骗、侵犯他人权益或扰乱社区秩序的内容。',
            '我们设有内容审核与用户举报机制，对违规内容可予以下架、删除等处理。',
          ]);

          this.section('4. 知识产权', [
            '本应用相关的商标、标识、软件代码及版面设计等知识产权归我们所有。',
            '您在本应用发布的内容，其著作权归您所有；您授予本应用在平台内展示、存储、分发的非独占许可。',
            '若您的内容侵犯第三方知识产权，由您承担相应责任。',
          ]);

          this.section('5. 免责声明', [
            '本应用按"现状"提供服务，除法定要求外，不对服务的连续性、适用性作出明示或默示担保。',
            '因不可抗力、网络故障或第三方原因导致的服务中断或数据损失，我们在法律允许范围内不承担责任。',
            '您因使用本应用产生的任何直接或间接损失，我们不承担超出法定范围的责任。',
          ]);

          this.section('6. 协议的变更与联系', [
            '我们可能适时修订本协议，重大变更将通过应用内通知等方式告知您。',
            '若您继续使用本应用，即视为接受修订后的协议。',
            '如有任何疑问，请联系我们：邮箱 agreement@bigbluebook.com',
          ]);

          Text('本协议的订立、效力、解释及争议解决均适用中华人民共和国法律。')
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
    .padding({ top: this.statusBarHeight })
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
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
