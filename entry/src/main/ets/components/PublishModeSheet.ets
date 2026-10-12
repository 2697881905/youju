import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { resolveActionIcon } from '../utils/actionIcons';

export type PublishMode = 'photo' | 'text' | 'video';

// 半模态面板宽度（CENTER 形态，内容自适应）。三宫格据此均分。
const SHEET_WIDTH: number = 344;
// 图标徽章边长。
const BADGE_SIZE: number = 52;
// 单个瓦片高度：徽章 + 标题 + 副标题 + 呼吸间距。
const TILE_HEIGHT: number = 116;

// 选择发布方式面板：由 Index 的 bindSheet（SheetType.CENTER + detents FIT_CONTENT）承载。
//
// 版式（本次美化）：横向三宫格，但去掉「方框卡套方框卡」的厚重描边与双层阴影（那是显丑的主因）。
// 每个方式改为一枚**实心品牌色圆角徽章 + 白色图标**（与全 app 既有惯例一致：AtMentionSuggest、
// DesignButton primary 都是 brand 实色 + onBrand 白），下方标题 + 一行短副标题，整体轻盈留白。
// 徽章带一层极淡接触阴影把它从面板上「托起来」，交互靠 Pressable 的按压缩放/透明度反馈。
//
// 承载与表面归属：面板整体的可读底/毛玻璃/圆角/描边及高版本沉浸光感由 SheetOptions 原生参数负责
// （见 Index.ets）；内容区不自绘面板底、不在 Column 上挂 systemMaterial。
// 关闭只由 showPublishSheet + onDisappear 驱动，不引入 CustomDialogController.close()。
@Component
export struct PublishModeSheet {
  onSelect: (mode: PublishMode) => void = (_mode: PublishMode): void => {};
  dismiss: () => void = (): void => {};

  // 单个发布方式：中性软质徽章 + 各自主题色的图标（三方式各一种色相，做出身份区分又不刺眼），
  // 下方居中文字。整枚瓦片可点。徽章底用 subtle（中性灰，深浅色都可见），图标用 accent
  // （brand/warm/mention 均为深浅成对 token，叠在灰底上两种主题下对比都够）。
  @Builder
  modeTile(mode: PublishMode, icon: Resource, label: string, subtitle: string, accent: ResourceColor): void {
    Pressable({
      fillWidth: true,
      visualHeight: TILE_HEIGHT,
      touchTargetHeight: TILE_HEIGHT,
      fullResponseRegion: true,
      action: (): void => {
        this.dismiss();
        this.onSelect(mode);
      },
    }) {
      Column({ space: SpaceTokens.base }) {
        // 中性软质徽章 + 主题色图标。
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
      // 瓦片本身不加底/描边/阴影——轻盈留白，表面完全交给面板 SheetOptions。
      .backgroundColor(Color.Transparent)
    }
  }

  build() {
    Column({ space: SpaceTokens.xl }) {
      // 标题区：title 级衬线主标题 + 一句引导副标题，右侧圆形关闭靶（44 触控）。
      Row() {
        Column({ space: SpaceTokens.xs }) {
          Text('选择发布方式')
            .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.title.weight)
            .lineHeight(TypeTokens.title.lineHeight)
            .fontColor(ColorTokens.primary)
          Text('记录此刻，选择一种方式开始创作')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.callout.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.secondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Pressable({
          visualHeight: LayoutTokens.segmentedHeight,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => { this.dismiss(); },
        }) {
          Row() {
            Image(resolveActionIcon('close'))
              .width(IconTokens.small)
              .height(IconTokens.small)
              .fillColor(ColorTokens.icon)
          }
          .width(LayoutTokens.segmentedHeight)
          .height(LayoutTokens.segmentedHeight)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.pill)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 横向三宫格：三枚等宽瓦片并排，靠 layoutWeight 严格均分，之间留间隙。
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
    }
    .width(SHEET_WIDTH)
    .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, top: SpaceTokens.xl, bottom: SpaceTokens.x2l })
    // 表面材质交给 bindSheet 的 SheetOptions，内容区只负责排布（不自绘面板底、不挂通用属性材质）。
    .backgroundColor(Color.Transparent)
  }
}
