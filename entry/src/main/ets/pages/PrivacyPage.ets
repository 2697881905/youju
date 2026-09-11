// 隐私政策页：内置静态隐私政策文本，无后端调用

import { buildPageTransition } from '../utils/styles';
import { BackButton } from '../design/components/BackButton';

@Entry
@Component
export struct PrivacyPage {
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  build() {
    Column() {
      // 顶栏
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Text('隐私政策')
          .fontSize(17).fontFamily($r('app.string.font_family'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Text('')
          .width(44);
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 });

      Scroll() {
        Column({ space: 16 }) {
          Text('版本：V1.1\n更新日期：2026 年 9 月 11 日\n生效日期：2026 年 9 月 11 日')
            .fontSize(12).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ left: 16, right: 16 });

          Text('有据由白逸飞（以下简称"我们"）提供，是用于分享购物测评、避坑指南、实用教程与生活心得并进行理性交流的社区应用。我们将按法律法规要求处理并保护你的个人信息。')
            .fontSize(15).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_primary'))
            .lineHeight(24)
            .width('100%')
            .padding({ left: 16, right: 16 });

          this.section('1. 我们收集和使用的信息', [
            '账号信息：当你注册账号时，我们会收集你的鸿蒙账号 OpenID 或华为账号 UnionID、昵称和头像。',
            '内容信息：你在平台上发布的帖子、评论、收藏等操作记录。',
            '设备与日志信息：为保障服务安全稳定，我们会处理设备型号、系统版本、IP 地址和操作日志等基础信息。',
          ]);

          this.section('2. 信息的使用与权限', [
            '向你展示推荐内容和个性化服务。',
            '用于改善产品体验和功能优化。',
            '保障平台秩序，识别和阻止违规行为；图片和视频通过系统相册选择器选择，我们不直接申请相册或相机权限。',
          ]);

          this.section('3. 个性化推荐与自动化决策', [
            '基本原理与目的：我们通过算法分析你的兴趣偏好，为你排序并推荐更可能感兴趣的内容（如首页「每日一贴」）。推荐结果仅用于提升你的内容获取效率，不影响你浏览全部公开内容。',
            '使用的信息：你在应用内关注的兴趣标签、浏览与点击等互动记录、搜索关键词，以及内容自身的互动热度与发布时间。我们不会将上述信息用于本政策未说明的其他目的。',
            '便捷关闭：你可随时通过「我的 → 设置 → 隐私设置 → 接收个性化推荐」关闭个性化推荐。关闭后我们不再依据你的浏览与互动记录生成推荐，「每日一贴」将按内容热度与时间排序。关闭操作不影响其他功能的使用。',
            '自动化决策的说明与拒绝：上述推荐属于自动化决策，但不会对你的信用、财产等作出具有重大影响的决定。若你对推荐结果有疑问，可随时关闭个性化推荐，或按第 8 节的方式要求我们作出说明。',
            '我们会持续评估推荐算法对内容生态的影响，避免产生诱导沉迷、流量造假等不当后果。',
          ]);

          this.section('4. 信息的存储与保护', [
            '你的个人信息存储于中国境内的服务器。',
            '我们采用加密传输（HTTPS）、访问控制等技术手段保护你的数据安全。',
            '除法律法规要求或为提供服务所必需外，我们不会向第三方提供你的个人信息。',
            '行为记录类数据（浏览与互动记录、搜索关键词）的保存期限不超过实现上述目的所必需的最短时间，到期后将先行汇总统计、再删除明细。',
          ]);

          this.section('5. 第三方服务与 SDK', [
            '华为账号服务 SDK（Huawei Account Kit）：用于华为账号登录，处理授权码、OpenID、UnionID、昵称和头像。',
            '腾讯云 COS：由服务端用于图片、视频等素材的上传和存储，处理你主动上传的媒体文件。',
          ]);

          this.section('6. 未成年人保护', [
            '若你是未成年人，请在监护人指导下使用本应用。我们不会主动收集不满 14 周岁未成年人的个人信息；如发现不当收集，请联系我们处理。',
          ]);

          this.section('7. 管理你的个人信息', [
            '你可随时编辑或删除你的个人信息（设置 → 编辑资料）。',
            '你可随时注销你的账号（设置 → 账号注销）；注销后我们将停止提供服务，并依法律法规处理相关信息。',
            '你可通过数据导出功能获取你的数据副本（设置 → 数据导出）。',
            '你可随时关闭个性化推荐，或联系我们删除用于推荐的兴趣标签。',
          ]);

          this.section('8. 联系我们', [
            '如有任何隐私相关问题或建议，请联系我们：',
            '运营主体：白逸飞',
            '邮箱：2697881905@qq.com',
          ]);

          Text('本隐私政策可能适时更新。如发生重大变更，我们将通过应用内通知的方式告知你。')
            .fontSize(13).fontFamily($r('app.string.font_family'))
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
        .fontSize(16).fontFamily($r('app.string.font_family'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)
        .padding({ bottom: 8 });

      ForEach(items, (item: string) => {
        Text('• ' + item)
          .fontSize(15).fontFamily($r('app.string.font_family'))
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
