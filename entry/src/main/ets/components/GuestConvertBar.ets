// 游客转化引导条（首页信息流顶部，仅未登录时出现，可关闭）
//
// 为什么要它：激励计划按「去重活跃设备」计月活，而游客设备**没有 PushToken 就永远召回不到**
//   （实测 30 天约 211 个设备出口在用 App，库里只有 43 个用户注册过 token）。
//   游客能自由浏览（Index.ets 不再强制登录），但全站登录提示都只挂在动作闸门上
//   （私信 / 关注列表 / 发布），信息流里对游客零引导 —— 于是「打开一次就失联」。
//   这条引导的作用就是把游客推过注册这一步，让他进入可召回、可留存的池子。
//
// 设计约束：只用官方组件（Row/Column/Text/Button），颜色与字号一律走 design token，
//   不写十六进制硬值；关闭按钮用文本 ✕ 而不是 $r() 图标资源，避免引用不存在的资源名。
//   字号档位不会自带字族，必须显式 .fontFamily(TypeTokens.fontFamily)。
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct GuestConvertBar {
  // 点击「登录」：由宿主决定跳转（HomeTab 走 router.pushUrl pages/LoginPage）
  onLogin: () => void = (): void => {};
  // 点 ✕：本次会话内不再出现（状态由宿主持有）
  onDismiss: () => void = (): void => {};

  build() {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text('登录后可收藏、顶帖，每天一条值得看的经验')
          .fontSize(15)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(FontWeight.Medium)
          .fontColor(ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('华为账号一键登录，不用填资料')
          .fontSize(12)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('登录')
        .type(ButtonType.Capsule)
        .fontSize(13)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(ColorTokens.brand)
        .fontColor(ColorTokens.canvas)
        .height(30)
        .padding({ left: 14, right: 14 })
        .onClick((): void => {
          this.onLogin();
        })

      Text('✕')
        .fontSize(13)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.tertiary)
        .width(24)
        .height(24)
        .textAlign(TextAlign.Center)
        .onClick((): void => {
          this.onDismiss();
        })
    }
    .width('100%')
    .padding({ left: 12, right: 8, top: 8, bottom: 8 })
    .borderRadius(RadiusTokens.lg)
    .backgroundColor(ColorTokens.canvas)
    .border({ width: 1, color: ColorTokens.separator })
    .alignItems(VerticalAlign.Center)
  }
}
