// 发布页分区卡片：一个发布环节 = 一张卡（衬线小节标题 + 右侧元信息 + 错峰入场）。
// 取代旧的「一整张巨卡 + 5 条 Divider」排版：Divider 只能切开字段，切不出层级。
import { BaseCard } from '../design/components/BaseCard';
import { Reveal } from '../design/motion/Reveal';
import { AiAssistChip } from './AiAssistChip';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct PublishSection {
  // 唯一 @BuilderParam：尾随闭包调用要求组件恰好一个 @BuilderParam（ArkTS 10905102），
  // 故卡头动作位走 props 驱动，不能加成第二个 @BuilderParam。
  @BuilderParam content: () => void = this.emptyContent;
  @Prop title: string = '';
  @Prop meta: string = '';
  // Reveal 的错峰序号：页面按渲染顺序传 0..n，越靠下的卡片越晚入场
  @Prop index: number = 0;
  // 卡标题行右端动作（如「AI 优化」）：actionLabel 非空时渲染，44vp 命中包装托住胶囊。
  @Prop actionLabel: string = '';
  @Prop actionBusy: boolean = false;
  @Prop actionAvailable: boolean = true;
  onAction: () => void = () => {};

  @Builder
  emptyContent(): void {}

  build() {
    Reveal({ index: this.index }) {
      BaseCard({ cardPadding: SpaceTokens.item, radius: RadiusTokens.lg, elevation: 1 }) {
        Column({ space: SpaceTokens.sm }) {
          Row() {
            Text(this.title)
              .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
              .fontWeight(TypeTokens.headline.weight)
              .lineHeight(TypeTokens.headline.lineHeight)
              .letterSpacing(TypeTokens.headline.tracking)
              .fontColor(ColorTokens.primary)
            Blank()
            if (this.meta.length > 0) {
              Text(this.meta)
                .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.overline.weight)
                .lineHeight(TypeTokens.overline.lineHeight)
                .letterSpacing(TypeTokens.overline.tracking)
                .fontColor(ColorTokens.tertiary)
                .margin({ right: SpaceTokens.sm })
            }
            if (this.actionLabel.length > 0) {
              Row() {
                AiAssistChip({
                  label: this.actionLabel,
                  busy: this.actionBusy,
                  available: this.actionAvailable,
                  action: this.onAction,
                })
              }
              .height(LayoutTokens.minTouchTarget)
              .alignItems(VerticalAlign.Center)
              .onClick((): void => { this.onAction(); })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          this.content()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
  }
}