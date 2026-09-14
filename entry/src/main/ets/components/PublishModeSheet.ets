import { Pressable } from '../design/motion/Pressable';
import { SpringPanel } from '../design/motion/SpringPanel';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

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
        Image(icon)
          .width(IconTokens.standard)
          .height(IconTokens.standard)
          .objectFit(ImageFit.Contain)
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
        Image($r('app.media.chevron_right'))
          .width(IconTokens.compact)
          .height(IconTokens.compact)
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
    // 面板参数与「已加入的圈子」等弹窗统一：panelPadding lg / 默认 radius(lg) / 内部 space base。
    // outlined=true：面板本身也走项目的描边规格（透明底 + 细描边，去背景模糊与外阴影），
    // 与首页分段栏同一套语言。immersive 已由 outlined 隐含关闭，不再叠 HDS 流光与蒙层。
    SpringPanel({ panelWidth: 344, panelPadding: SpaceTokens.lg, outlined: true, immersive: false }) {
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
            Image($r('app.media.close_x'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 三个选项共用一个描边容器（分段栏同构）：容器 1 条 barBorder 描边 + lg 圆角 + clip，
        // 条目本身无边框，之间用发丝分隔线。
        Column() {
          this.modeOption('photo', $r('app.media.publish_photo_outline'), '图文发布', '图片 + 文字，记录此刻所见')
          Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
          this.modeOption('video', $r('app.media.publish_video_outline'), '视频发布', '短片叙事，直观传递现场感')
          Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
          this.modeOption('text', $r('app.media.publish_text_outline'), '长文发布', '深度经验，娓娓道来')
        }
        .width('100%')
        .backgroundColor(Color.Transparent)
        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.lg)
        .clip(true)
      }
      .width('100%')
    }
  }
}
