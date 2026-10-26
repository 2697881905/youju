// 发布方式页（原「发布方式」半模态面板改造）。
//
// 为什么从弹窗改成页面：底部 Dock 开放了整页左右滑动切页，而发布占位夹在圈子与消息中间 ——
// Tabs 的滑动是**相邻索引**逐格推进，`onContentWillChange` 对 index 2 返回 false 会同时挡住
// 点击与滑动（官方文档触发条件第 1 条即"用户滑动 TabContent"），结果是圈子↔消息之间永远滑不过去。
// 要让滑动链完整，发布必须成为一个可停靠的真实页面。
//
// 与面板版的差别：去掉固定 344 宽与右上角 ✕（页面不需要自己关，滑走或点别的页签即离开），
// 改为整宽排布；表面不再由 SheetOptions 承担，直接站在页面画布上。
//
// 避让：本页没有内嵌 HdsNavigation（其余四个主 Tab 都有），所以状态栏与悬浮 Dock 都要自己让 ——
// Dock 是 barOverlap 悬浮的，不让位最后一张瓦片会被压在玻璃底下。
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { resolveActionIcon } from '../utils/actionIcons';
import { bottomNavInset, DOCK_BAR_HEIGHT_VP, DOCK_BOTTOM_MARGIN_BASE } from '../utils/cardTokens';

export type PublishMode = 'photo' | 'text' | 'video';

// 图标徽章边长与单张瓦片高度（沿用面板版实测值）。
const BADGE_SIZE: number = 52;
const TILE_HEIGHT: number = 116;
// 标题行高度：与其余四个主 Tab 的 HdsNavigation 标题行同高，切页时标题不会上下跳。
const TITLE_ROW_VP: number = 56;

@Component
export struct PublishModePanel {
  onSelect: (mode: PublishMode) => void = (_mode: PublishMode): void => {};
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  // 单个发布方式：中性软质徽章 + 各自主题色图标（三方式各一种色相，做出身份区分又不刺眼），
  // 下方居中文字，整枚瓦片可点。徽章底用 panel（elevated 面），在画布上两种主题都浮得起。
  @Builder
  modeTile(mode: PublishMode, icon: Resource, label: string, subtitle: string, accent: ResourceColor): void {
    Pressable({
      fillWidth: true,
      visualHeight: TILE_HEIGHT,
      touchTargetHeight: TILE_HEIGHT,
      fullResponseRegion: true,
      action: (): void => {
        this.onSelect(mode);
      },
    }) {
      Column({ space: SpaceTokens.base }) {
        Row() {
          Image(icon)
            .width(26)
            .height(26)
            .objectFit(ImageFit.Contain)
            .fillColor(accent)
        }
        .width(BADGE_SIZE)
        .height(BADGE_SIZE)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(ColorTokens.panel)
        .borderRadius(RadiusTokens.lg)

        Column({ space: SpaceTokens.xs }) {
          Text(label)
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(subtitle)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .fontColor(ColorTokens.tertiary)
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height(TILE_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Color.Transparent)
    }
  }

  build() {
    Column() {
      // 标题行：衬线标题，位置对齐其余 Tab 的 HdsNavigation 标题行（状态栏 + 56vp）。
      Row() {
        Text('发布')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .fontColor(ColorTokens.primary)
      }
      .width('100%')
      .height(TITLE_ROW_VP)
      .alignItems(VerticalAlign.Center)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })

      Text('记录此刻，选择一种方式开始创作')
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.callout.weight)
        .lineHeight(TypeTokens.callout.lineHeight)
        .fontColor(ColorTokens.secondary)
        .width('100%')
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md })

      // 横向三宫格：三枚等宽瓦片严格均分。
      Row({ space: SpaceTokens.base }) {
        Column() {
          this.modeTile('photo', $r('app.media.publish_photo_outline'), '图文', '图片 + 文字', ColorTokens.brand)
        }
        .layoutWeight(1)

        Column() {
          this.modeTile('video', $r('app.media.publish_video_outline'), '视频', '短片叙事', ColorTokens.warm)
        }
        .layoutWeight(1)

        Column() {
          this.modeTile('text', $r('app.media.publish_text_outline'), '长文', '深度书写', ColorTokens.mention)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      .margin({ top: SpaceTokens.xl })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      top: this.statusBarHeight,
      // 让开整条悬浮 Dock：栏高 + 栏底间距 + 系统导航区，再留一档呼吸。
      bottom: DOCK_BAR_HEIGHT_VP + DOCK_BOTTOM_MARGIN_BASE + bottomNavInset() + SpaceTokens.xl,
    })
    .backgroundColor(ColorTokens.canvas)
  }
}
