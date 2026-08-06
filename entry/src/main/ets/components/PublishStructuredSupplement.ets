import { Genre, StructuredData } from '../models/types';
import { isLongStructuredField, genreStructuredFields, readStructuredField, StructuredFieldDef } from '../utils/structuredFields';
import { Collapse } from '../design/motion/Collapse';
import { Pressable } from '../design/motion/Pressable';
import { IconTile } from '../design/components/IconTile';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 发布器的结构化补充区只呈现字段和回调输入，草稿/预览状态继续由各发布页独立管理。
@Component
export struct PublishStructuredSupplement {
  @Prop genre: Genre = 'review';
  @Prop hint: string = '';
  @Prop data: StructuredData = {};
  @Link expanded: boolean;
  onChange: (key: keyof StructuredData, value: string) => void = (_key: keyof StructuredData, _value: string): void => {};

  @Builder
  private fieldInput(item: StructuredFieldDef): void {
    Column({ space: SpaceTokens.inline }) {
      Text(item[1])
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.caption.weight)
        .lineHeight(TypeTokens.caption.lineHeight)
        .fontColor(ColorTokens.secondary)
        .width('100%')
      if (isLongStructuredField(item[0])) {
        TextArea({ text: String(readStructuredField(this.data, item[0]) ?? ''), placeholder: item[1] })
          .width('100%')
          .height(LayoutTokens.composerFieldHeight)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.quaternary)
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.sm)
          .padding(SpaceTokens.item)
          .onChange((value: string): void => { this.onChange(item[0], value); })
      } else {
        TextInput({ text: String(readStructuredField(this.data, item[0]) ?? ''), placeholder: item[1] })
          .width('100%')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.quaternary)
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.sm)
          .padding(SpaceTokens.item)
          .onChange((value: string): void => { this.onChange(item[0], value); })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: SpaceTokens.sm }) {
      Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
      Pressable({
        fillWidth: true,
        visualHeight: LayoutTokens.minTouchTarget,
        action: (): void => { this.expanded = !this.expanded; },
      }) {
        Row({ space: SpaceTokens.sm }) {
          IconTile({ icon: $r('app.media.set_edit'), tileSize: 36, iconSize: IconTokens.compact, showBackground: false })
          Column({ space: SpaceTokens.inlineTight }) {
            Text('结构化补充')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .lineHeight(TypeTokens.callout.lineHeight)
              .letterSpacing(TypeTokens.callout.tracking)
              .fontColor(ColorTokens.primary)
            Text(this.hint)
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.caption.weight)
              .lineHeight(TypeTokens.caption.lineHeight)
              .letterSpacing(TypeTokens.caption.tracking)
              .fontColor(ColorTokens.secondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Image(this.expanded ? resolveActionIcon('chevronUp') : resolveActionIcon('chevronDown'))
            .width(IconTokens.compact)
            .height(IconTokens.compact)
            .fillColor(ColorTokens.brand)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      Collapse({ expanded: this.expanded }) {
        Column({ space: SpaceTokens.sm }) {
          Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
          ForEach(genreStructuredFields(this.genre), (item: StructuredFieldDef) => {
            this.fieldInput(item)
          }, (item: StructuredFieldDef) => item[0] as string)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
