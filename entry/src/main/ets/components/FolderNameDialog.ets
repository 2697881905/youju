// 收藏夹命名弹窗：新建/重命名共用一个输入弹窗，回调返回输入名
import { SpringPanel } from '../design/motion/SpringPanel';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { Pressable } from '../design/motion/Pressable';

@CustomDialog
export struct FolderNameDialog {
  controller: CustomDialogController;
  title: string = '新建收藏夹';
  placeholder: string = '输入收藏夹名称（最多 20 字）';
  initial: string = '';
  onSubmit: (name: string) => void = (_name: string): void => {};

  @State text: string = '';

  aboutToAppear(): void {
    this.text = this.initial;
  }

  private submit(): void {
    const name: string = this.text.trim();
    if (name.length === 0) {
      return;
    }
    this.controller.close();
    this.onSubmit(name);
  }

  build() {
    SpringPanel({ panelWidth: 344, panelPadding: SpaceTokens.lg }) {
      Column({ space: SpaceTokens.base }) {
        Row({ space: SpaceTokens.sm }) {
          Text(this.title)
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.headline.lineHeight)
            .fontColor(ColorTokens.primary)
            .layoutWeight(1)
          Pressable({
            visualHeight: IconTokens.compact,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.controller.close(); },
          }) {
            Image(resolveActionIcon('close'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        TextInput({ placeholder: this.placeholder, text: this.text })
          .fontFamily(TypeTokens.fontFamily)
          .fontSize(TypeTokens.body.size)
          .maxLength(20)
          .height(44)
          .backgroundColor(ColorTokens.sunken)
          .borderRadius(RadiusTokens.md)
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
          .onChange((value: string): void => { this.text = value; })

        Text('确定')
          .width('100%')
          .height(LayoutTokens.minTouchTarget)
          .textAlign(TextAlign.Center)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.onBrand)
          .backgroundColor(ColorTokens.brand)
          .borderRadius(RadiusTokens.md)
          .onClick((): void => { this.submit(); })
      }
      .width('100%')
    }
  }
}
