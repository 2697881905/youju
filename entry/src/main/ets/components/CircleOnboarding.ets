import { Tag } from '../models/types';
import { TagIcon } from './TagIcon';
import { DesignButton } from '../design/components/DesignButton';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 新账号首次进入 Tab 页时展示的圈子选择层；实际加入仍走既有的标签关注接口。
@Component
export struct CircleOnboarding {
  @Prop tags: Tag[] = [];
  @Prop selectedNames: string[] = [];
  @Prop loading: boolean = false;
  @Prop submitting: boolean = false;
  onToggle: (name: string) => void = (): void => {};
  onSkip: () => void = (): void => {};
  onConfirm: () => void = (): void => {};

  private isSelected(name: string): boolean {
    return this.selectedNames.indexOf(name) >= 0;
  }

  private confirmLabel(): string {
    if (this.selectedNames.length === 0) {
      return '进入首页';
    }
    return this.submitting ? '正在加入...' : '加入 ' + this.selectedNames.length + ' 个圈子';
  }

  @Builder
  circleItem(tag: Tag): void {
    Pressable({
      fillWidth: true,
      visualHeight: 96,
      action: (): void => { this.onToggle(tag.name ?? ''); },
    }) {
      Column({ space: SpaceTokens.xs }) {
        TagIcon({
          name: tag.name ?? '',
          iconSize: IconTokens.standard,
          tint: this.isSelected(tag.name ?? '') ? ColorTokens.onBrand : ColorTokens.brand,
          colorful: !this.isSelected(tag.name ?? ''),
        })
        Text(tag.name ?? '')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(this.isSelected(tag.name ?? '') ? TypeTokens.headline.weight : TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .fontColor(this.isSelected(tag.name ?? '') ? ColorTokens.onBrand : ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height(96)
      .padding(SpaceTokens.sm)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.isSelected(tag.name ?? '') ? ColorTokens.brand : ColorTokens.barSurface)
      .backdropBlur(this.isSelected(tag.name ?? '') ? 0 : LayoutTokens.glassBlur)
      .border({
        width: LayoutTokens.glassBorderWidth,
        color: this.isSelected(tag.name ?? '') ? ColorTokens.brand : ColorTokens.barBorder,
        style: BorderStyle.Solid,
      })
      .borderRadius(RadiusTokens.md)
    }
  }

  build() {
    Column({ space: SpaceTokens.md }) {
      Column({ space: SpaceTokens.xs }) {
        Text('选择感兴趣的圈子')
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .fontColor(ColorTokens.primary)
        Text(this.selectedNames.length > 0 ? '已选择 ' + this.selectedNames.length + ' 个' : '可多选')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.secondary)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.loading) {
        Column() {
          LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Grid() {
            ForEach(this.tags, (tag: Tag) => {
              GridItem() {
                this.circleItem(tag)
              }
            }, (tag: Tag) => tag.name ?? '')
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(SpaceTokens.sm)
          .rowsGap(SpaceTokens.sm)
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }

      Row({ space: SpaceTokens.sm }) {
        DesignButton({
          label: '稍后再选',
          variant: 'glass',
          action: this.onSkip,
        })
        .layoutWeight(1)
        DesignButton({
          label: this.confirmLabel(),
          disabled: this.loading || this.submitting,
          action: this.onConfirm,
        })
        .layoutWeight(2)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.x2l, bottom: SpaceTokens.x2l })
    .backgroundColor(ColorTokens.canvas)
    .alignItems(HorizontalAlign.Start)
  }
}
