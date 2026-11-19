// 发布页分区卡片：一个发布环节 = 一张卡（衬线小节标题 + 右侧元信息 + 错峰入场）。
// 发布页改版后仅用于「发布设置」托盘与结构化卡；写作区（标题/正文/媒体）直接落在纸面上，不再套卡。
import { BaseCard } from '../design/components/BaseCard';
import { Reveal } from '../design/motion/Reveal';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct PublishSection {
  // 唯一 @BuilderParam：尾随闭包调用要求组件恰好一个 @BuilderParam（ArkTS 10905102）。
  @BuilderParam content: () => void = this.emptyContent;
  @Prop title: string = '';
  @Prop meta: string = '';
  // Reveal 的错峰序号：页面按渲染顺序传 0..n，越靠下的卡片越晚入场
  @Prop index: number = 0;

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