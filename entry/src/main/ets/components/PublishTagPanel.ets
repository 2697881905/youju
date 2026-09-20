import { LengthMetrics } from '@kit.ArkUI';
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

// —— 应用整体纸面卡片材质（与 GlassPanel/内容卡片同语言）——
// 暖白纸面 elevated 底 + ds_separator 细描边 + 柔和阴影，无玻璃模糊；
// 与整款软件的暖纸/棕金/墨色体系一致。
const SEGMENT_PAPER_BG: ResourceColor = ColorTokens.elevated;
const SEGMENT_PAPER_BORDER: ResourceColor = ColorTokens.separator;

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
      .padding({ left: SpaceTokens.item, right: SpaceTokens.item })
      .backgroundColor(this.isSelected(tag) ? ColorTokens.brand : ColorTokens.sunken)
      .borderRadius(RadiusTokens.sm)
      .alignItems(VerticalAlign.Center)
      .animation({ duration: MotionTokens.fast, curve: MotionCurves.standard })
    }
  }

  build() {
    Column() {
      // 标题行：选择圈子 + 已选计数 + 完成按钮
      Row({ space: SpaceTokens.item }) {
        Column({ space: SpaceTokens.xs }) {
          Text('选择圈子')
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.headline.lineHeight)
            .fontColor(ColorTokens.primary)
          Text('已选择 ' + this.selectedTags.length + '/' + this.maxSelected)
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
      // 顶部留白加大：弹层内容距上缘更宽松，避免紧贴 sheet 顶部
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.lg, bottom: SpaceTokens.xs })

      Scroll() {
        Column({ space: SpaceTokens.md }) {
          if (this.categoryList.length === 0) {
            Text('圈子加载中，稍后再试')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
              .width('100%')
              .padding(SpaceTokens.xl)
              .textAlign(TextAlign.Center)
          }
          ForEach(this.categoryList, (category: string) => {
            Column({ space: SpaceTokens.sm }) {
              Text(category)
                .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.overline.weight)
                .lineHeight(TypeTokens.overline.lineHeight)
                .letterSpacing(TypeTokens.overline.tracking)
                .fontColor(ColorTokens.secondary)
                .width('100%')
              Flex({
                wrap: FlexWrap.Wrap,
                space: { main: LengthMetrics.px(SpaceTokens.inline), cross: LengthMetrics.px(SpaceTokens.inline) },
              }) {
                ForEach(this.tagsByCategory[category] ?? [], (tag: Tag) => {
                  this.tagChoice(tag)
                }, (tag: Tag) => tag.name ?? '')
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }, (category: string) => category)
          Row().height(SpaceTokens.x2l).width('100%')
        }
        .width('100%')
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.md })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .padding({ bottom: barBottomReserve() })
    }
    .width('100%')
    .height('100%')
    // 纸面卡片样式（应用整体统一语言）：暖白纸底 + ds_separator 细描边 + 柔和阴影，无玻璃模糊
    .backgroundColor(SEGMENT_PAPER_BG)
    .border({ width: 1, color: SEGMENT_PAPER_BORDER, style: BorderStyle.Solid })
    .borderRadius(RadiusTokens.lg)
    .shadow(ShadowTokens.cardAmbient)
    .clip(true)
  }
}
