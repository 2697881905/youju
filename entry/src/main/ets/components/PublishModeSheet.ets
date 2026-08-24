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
  modeOption(mode: PublishMode, icon: Resource, label: string): void {
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
          .width(IconTokens.small)
          .height(IconTokens.small)
          .objectFit(ImageFit.Contain)
        Text(label)
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.body.lineHeight)
          .fontColor(ColorTokens.primary)
        Blank().layoutWeight(1)
        Image($r('app.media.chevron_right'))
          .width(IconTokens.compact)
          .height(IconTokens.compact)
          .fillColor(ColorTokens.secondary)
      }
      .width('100%')
      .height(68)
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(ColorTokens.barSelectionSurface)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.lg)
    }
  }

  build() {
    SpringPanel({ panelWidth: 344, panelPadding: SpaceTokens.md, radius: RadiusTokens.xl }) {
      Column({ space: SpaceTokens.sm }) {
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

        this.modeOption('photo', $r('app.media.publish_photo_outline'), '图文发布')
        this.modeOption('video', $r('app.media.publish_video_outline'), '视频发布')
        this.modeOption('text', $r('app.media.publish_text_outline'), '长文发布')
      }
      .width('100%')
    }
  }
}
