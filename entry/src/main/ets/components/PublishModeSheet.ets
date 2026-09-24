import { Pressable } from '../design/motion/Pressable';
import { SpringPanel } from '../design/motion/SpringPanel';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { resolveActionIcon } from '../utils/actionIcons';

export type PublishMode = 'photo' | 'text' | 'video';

@CustomDialog
export struct PublishModeSheet {
  controller: CustomDialogController;
  onSelect: (mode: PublishMode) => void = (_mode: PublishMode): void => {};

  @Builder
  modeOption(mode: PublishMode, icon: Resource, label: string, subtitle: string): void {
    Pressable({
      fillWidth: true,
      visualHeight: 68,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: (): void => {
        this.controller.close();
        this.onSelect(mode);
      },
    }) {
      Row({ space: SpaceTokens.md }) {
        // 图标统一走 currentColor + fillColor 主题化（不再依赖 base/dark 双份写死板）
        Image(icon)
          .width(IconTokens.standard)
          .height(IconTokens.standard)
          .objectFit(ImageFit.Contain)
          .fillColor(ColorTokens.icon)
        Column({ space: SpaceTokens.inlineTight }) {
          Text(label)
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.body.lineHeight)
            .fontColor(ColorTokens.primary)
          Text(subtitle)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .fontColor(ColorTokens.tertiary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Image(resolveActionIcon('chevronRight'))
          .width(IconTokens.compact)
          .height(IconTokens.compact)
          .fillColor(ColorTokens.icon)
      }
      .width('100%')
      .height(68)
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
      .alignItems(VerticalAlign.Center)
      // 条目自身不再描边：改由外层「选项容器」统一一条描边（与分段栏「1 条容器描边 + 内部无边框」同构）
      .backgroundColor(Color.Transparent)
    }
  }

  build() {
    // 面板材质与应用内容卡 / PostStatsDialog 同语言：elevated 实色暖纸底 + separator 1px
    // 发丝描边 + cardAmbient 阴影，无背景模糊、无流光（solid 档）。承载文字的浮层不用
    // 半透明玻璃 —— 半透明只保留给悬浮底栏/分段栏这类刻意透底的表面（与 @提及候选条同一约定）。
    // 尺寸维持应用标准：宽度 344 / 内边距 lg=20 / 圆角 lg。
    SpringPanel({ panelWidth: 344, panelPadding: SpaceTokens.lg, solid: true }) {
      Column({ space: SpaceTokens.base }) {
        Row() {
          Text('选择发布方式')
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.headline.lineHeight)
            .fontColor(ColorTokens.primary)
          Blank().layoutWeight(1)
          Pressable({
            visualHeight: LayoutTokens.segmentedHeight,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.controller.close(); },
          }) {
            Image(resolveActionIcon('close'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
              .fillColor(ColorTokens.icon)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 三个选项共用一个描边容器（分段栏同构）：容器 1 条发丝描边 + lg 圆角 + clip，
        // 条目本身无边框，之间用发丝分隔线。描边色与面板一致走 separator（elevated 底上
        // 不再用 barBorder 玻璃描边，避免玻璃语言混进实色面板）。
        Column() {
          this.modeOption('photo', $r('app.media.publish_photo_outline'), '图文发布', '图片 + 文字，记录此刻所见')
          Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
          this.modeOption('video', $r('app.media.publish_video_outline'), '视频发布', '短片叙事，直观传递现场感')
          Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
          this.modeOption('text', $r('app.media.publish_text_outline'), '长文发布', '深度经验，娓娓道来')
        }
        .width('100%')
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.lg)
        .clip(true)
      }
      .width('100%')
    }
  }
}
