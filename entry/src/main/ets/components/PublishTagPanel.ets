// 发布页「选择圈子」半模态内容：分类分组 + 多选胶囊。
//
// 排版：从「一整条 Scroll + 分类顺序堆叠」改为原生 List + ListItemGroup + 吸顶分组标题，
// 圈子很多时（真机 24 个）滚动中始终知道自己在哪一类，不用回到顶部找标题。
// 表面：材质载体是 SheetOptions.systemMaterial（见发布页 bindSheet），面板内部不再自绘
// 暖纸底/描边/阴影——那层自绘会盖住系统材质；低版本（材质门禁不通过）回退 elevated 实色。
import { Tag } from '../models/types';
import { TagIcon } from './TagIcon';
import { DesignButton } from '../design/components/DesignButton';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { ShadowTokens } from '../design/tokens/shadow';
import { barBottomReserve } from '../utils/cardTokens';
import { isSystemMaterialActive } from '../utils/immersiveMaterial';

const CHIP_LANES: number = 3;

@Component
export struct PublishTagPanel {
  @Prop categoryList: string[] = [];
  @Prop tagsByCategory: Record<string, Tag[]> = {};
  @Prop selectedTags: string[] = [];
  @Prop maxSelected: number = 3;
  onToggle: (name: string) => void = (_name: string): void => {};
  onClose: () => void = (): void => {};

  private tagName(tag: Tag): string {
    return tag.name ?? '';
  }

  private isSelected(tag: Tag): boolean {
    return this.selectedTags.indexOf(this.tagName(tag)) >= 0;
  }

  @Builder
  private tagChoice(tag: Tag): void {
    Pressable({
      visualHeight: LayoutTokens.segmentedHeight,
      fillWidth: true,
      action: (): void => { this.onToggle(this.tagName(tag)); },
    }) {
      Row({ space: SpaceTokens.inline }) {
        TagIcon({
          name: this.tagName(tag),
          iconSize: IconTokens.compact,
          tint: this.isSelected(tag) ? ColorTokens.onBrand : ColorTokens.primary,
          colorful: !this.isSelected(tag),
        })
        Text(this.tagName(tag))
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(this.isSelected(tag) ? TypeTokens.headline.weight : TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(this.isSelected(tag) ? ColorTokens.onBrand : ColorTokens.primary)
      }
      .height(LayoutTokens.segmentedHeight)
      .width('100%')
      .padding({ left: SpaceTokens.item, right: SpaceTokens.item })
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.isSelected(tag) ? ColorTokens.brandSolid : ColorTokens.sunken)
      .borderRadius(RadiusTokens.pill)
      .alignItems(VerticalAlign.Center)
      .animation({ duration: MotionTokens.fast, curve: MotionCurves.standard })
    }
  }

  // 吸顶分组标题：滚动时贴住弹层顶部，必须是不透明条，否则下方胶囊会透上来糊成一片
  @Builder
  private groupHeader(category: string): void {
    Row() {
      Text(category)
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.overline.weight)
        .lineHeight(TypeTokens.overline.lineHeight)
        .letterSpacing(TypeTokens.overline.tracking)
        .fontColor(ColorTokens.secondary)
    }
    .width('100%')
    .height(LayoutTokens.segmentedHeight)
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(ColorTokens.elevated)
  }

  build() {
    Column() {
      Row({ space: SpaceTokens.item }) {
        Column({ space: SpaceTokens.xs }) {
          Text('选择圈子')
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.headline.lineHeight)
            .fontColor(ColorTokens.primary)
          Text('已选 ' + this.selectedTags.length + '/' + this.maxSelected + '，可多选')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .fontColor(ColorTokens.secondary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        DesignButton({ label: '完成', action: (): void => { this.onClose(); } })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.base, bottom: SpaceTokens.sm })

      if (this.categoryList.length === 0) {
        Column() {
          Text('圈子加载中，稍后再试')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        List({ space: SpaceTokens.md }) {
          ForEach(this.categoryList, (category: string) => {
            ListItemGroup({ header: this.groupHeader(category), space: SpaceTokens.sm }) {
              // 每个圈子是独立 ListItem，交给 List.lanes 做原生多列；
              // 之前用 ListItem 包一层 Flex(wrap) 排版，真机上胶囊只绘制不进命中树，点击全被 List 吞掉。
              ForEach(this.tagsByCategory[category] ?? [], (tag: Tag) => {
                ListItem() {
                  this.tagChoice(tag)
                }
              }, (tag: Tag) => category + '_' + (tag.name ?? ''))
            }
          }, (category: string) => category)
          ListItem() {
            Row().height(barBottomReserve() + SpaceTokens.base).width('100%')
          }
        }
        .lanes(CHIP_LANES, SpaceTokens.sm)
        .layoutWeight(1)
        .width('100%')
        .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .sticky(StickyStyle.Header)
      }
    }
    .width('100%')
    .height('100%')
    // 系统材质生效时表面交给 SheetOptions.systemMaterial，自绘底/边框/阴影全部让位
    .backgroundColor(isSystemMaterialActive() ? Color.Transparent : ColorTokens.elevated)
    .border(isSystemMaterialActive()
      ? { width: 0, color: Color.Transparent, style: BorderStyle.Solid }
      : { width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
    .borderRadius(RadiusTokens.xl)
    .shadow(isSystemMaterialActive() ? ShadowTokens.none : ShadowTokens.floating)
    .clip(true)
  }
}
