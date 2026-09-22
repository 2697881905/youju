import { Genre, StructuredData } from '../models/types';
import { genreFieldMeta, isMultilineKind, readStructuredField, StructuredFieldMeta } from '../utils/structuredFields';
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

  // 字段控件完全由元数据驱动：kind 决定单行/多行，maxLength 决定上限，hint 作为示例占位。
  // 过去 placeholder 直接复用字段名（「优点」），对从没写过测评的人是零信息；
  // 换成示例（「续航强、系统流畅」）既降低起步门槛，也把内容粒度收敛到一致。
  @Builder
  private fieldInput(item: StructuredFieldMeta): void {
    Column({ space: SpaceTokens.inline }) {
      Row({ space: SpaceTokens.inlineTight }) {
        Text(item.label)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .fontColor(ColorTokens.secondary)
        // 核心字段只做「建议」标注，不做必填拦截 —— 冷启动期发布率比完整率更贵
        if (item.essential) {
          Text('建议填写')
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.overline.weight)
            .letterSpacing(TypeTokens.overline.tracking)
            .fontColor(ColorTokens.tertiary)
            .border({ width: LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.pill)
            .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 1, bottom: 1 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 多行/单行由 kind 决定（longText 与 steps 走 TextArea：步骤需要按行输入）
      if (isMultilineKind(item.kind)) {
        TextArea({ text: String(readStructuredField(this.data, item.key) ?? ''), placeholder: item.hint })
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
          .maxLength(item.maxLength)
          .onChange((value: string): void => { this.onChange(item.key, value); })
      } else {
        TextInput({ text: String(readStructuredField(this.data, item.key) ?? ''), placeholder: item.hint })
          .width('100%')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.quaternary)
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.sm)
          .padding(SpaceTokens.item)
          .maxLength(item.maxLength)
          .onChange((value: string): void => { this.onChange(item.key, value); })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    // 无结构化字段的体裁（如分享）不渲染整个补充区，避免出现空标题栏。
    if (genreFieldMeta(this.genre).length > 0) {
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
              .fillColor(ColorTokens.secondary)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        Collapse({ expanded: this.expanded }) {
          Column({ space: SpaceTokens.sm }) {
            Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
            ForEach(genreFieldMeta(this.genre), (item: StructuredFieldMeta) => {
              this.fieldInput(item)
            }, (item: StructuredFieldMeta) => item.key as string)
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
