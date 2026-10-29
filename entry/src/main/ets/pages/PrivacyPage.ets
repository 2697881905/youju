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
          Text('版本：V1.2\n更新日期：2026 年 10 月 30 日\n生效日期：2026 年 10 月 30 日')
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
            '位置信息：仅当你主动使用圈子「同城」页的定位功能时，为自动识别你所在的城市，我们会在本地获取粗略/精确位置并仅用于匹配城市白名单；不缓存、不上传坐标，拒绝授权后可手动选择城市。',
            '剪贴板信息：当你在其他应用复制了有据帖子的分享链接、再回到本应用时，我们会读取一次剪贴板，仅用于识别形如 youju.chat/post/编号 的链接并询问你是否打开对应帖子。该读取需要你单独授权（系统会弹出申请），最长 30 秒才检查一次；内容只在你的手机上比对，不上传、不存储、不读取与他人内容无关的剪贴板项。拒绝后不影响任何功能，你仍可正常浏览与搜索。',
            '握持姿态信息：为把操作按钮移动到你实际握持手机的那一侧、便于单手使用，本应用会监听设备的握持手变化。该信息只在本机内存里转换成一个「左手 / 右手」排版开关，不上传、不落盘、不与其他个人信息关联，也不用于任何用户画像或内容推荐。',
            '消息推送标识：为把顶帖、收藏、评论、私信等互动提醒送达你的设备，我们会向华为推送服务申请推送令牌（Push Token），并在你已登录时把该令牌与你的账号在服务端绑定。你可在「设置 → 通知设置」逐项关闭通知；退出登录时本应用会先解绑该令牌再清除本机登录态，停止向本机下发任何通知。',
          ]);

          this.section('2. 信息的使用与权限', [
            '向你展示推荐内容和个性化服务。',
            '用于改善产品体验和功能优化。',
            '保障平台秩序，识别和阻止违规行为；图片和视频通过系统相册选择器选择，我们不直接申请相册或相机权限。',
            '本应用申请的权限共 5 项，与清单一致：网络访问（INTERNET，用于加载内容）；粗略位置与精确位置（APPROXIMATELY_LOCATION / LOCATION，仅同城选城市）；剪贴板读取（READ_PASTEBOARD，仅识别你复制的分享链接）；握持姿态识别（DETECT_GESTURE，仅单手排版）。除网络访问外均为可拒绝的可选权限，拒绝后对应功能退化为手动方式，不影响其他功能的使用。我们不申请、也不收集你的通讯录 / 联系人信息。',
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
            '登录凭据在本机的存储方式：你的登录令牌不以明文写入本机存储，而是用与本机设备标识（ODID）绑定的一次性随机数生成的密钥流在本机加密封存。该设备标识只在你手机上参与运算，不上传给我们、不上传给第三方、不出现在任何网络请求中；把加密结果拷贝到另一台设备或因还原备份换机，都会因设备标识不同而不可解，凭据因此不可被复用。',
          ]);

          this.section('5. 第三方服务与 SDK', [
            '华为账号服务 SDK（Huawei Account Kit）：用于华为账号登录，处理授权码、OpenID、UnionID、昵称和头像。',
            '华为推送服务（Push Kit）：用于向你的设备送达互动提醒，处理推送令牌（Push Token）及其与你账号的绑定关系；退出登录或关闭对应通知开关后解除绑定或停止下发。',
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
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
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
