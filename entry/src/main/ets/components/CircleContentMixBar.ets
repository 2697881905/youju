// 圈子「内容构成条」：近 7 天五种体裁的占比条 + 图例。
//
// 设计约束：
// - 五段宽度按 count/total 分配，段之和恒等于 total（后端保证 contentMix 五键之和 == recentPostCount）
// - count 为 0 的段不渲染，段间 gap 从 2 收到 1（否则会出现 0 宽的空隙）
// - 颜色是「体裁语义色」，不进 ColorTokens（与圈子分类色同性质：一次性映射，不是主题色）
// - 深色下 教程绿 会偏暗，单独提亮一档
import { CircleContentMix } from '../services/api';
import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

interface MixSegment {
  key: string;
  label: string;
  count: number;
  color: string;
}

const EMPTY_MIX: CircleContentMix = { review: 0, pitfall: 0, tutorial: 0, debate: 0, share: 0 };

@Component
export struct CircleContentMixBar {
  @Prop mix: CircleContentMix = EMPTY_MIX;
  @Prop total: number = 0;
  @Prop isDarkMode: boolean = false;

  private segments(): MixSegment[] {
    return [
      // 深色档整体提亮一档：品牌蓝/暖金在 #1E1E1E 上偏暗，分享的浅灰直接糊成底色
      { key: 'review', label: '测评', count: this.mix.review, color: this.isDarkMode ? '#4D9AFF' : '#0066CC' },
      { key: 'pitfall', label: '踩坑', count: this.mix.pitfall, color: this.isDarkMode ? '#D89A3C' : '#A06400' },
      { key: 'tutorial', label: '教程', count: this.mix.tutorial, color: this.isDarkMode ? '#4CAF87' : '#2E7D5B' },
      { key: 'debate', label: '观点', count: this.mix.debate, color: this.isDarkMode ? '#9A9AA0' : '#8A8A90' },
      { key: 'share', label: '分享', count: this.mix.share, color: this.isDarkMode ? '#6E6E76' : '#C9C9CE' },
    ];
  }

  private visibleSegments(): MixSegment[] {
    return this.segments().filter((item: MixSegment) => item.count > 0);
  }

  private hasData(): boolean {
    return this.total > 0 && this.visibleSegments().length > 0;
  }

  @Builder
  bar(): void {
    Row({ space: 2 }) {
      ForEach(this.visibleSegments(), (item: MixSegment) => {
        Row()
          .layoutWeight(item.count)
          .height(6)
          .backgroundColor(item.color)
          .borderRadius(3)
      }, (item: MixSegment) => item.key)
    }
    .width('100%')
    .height(6)
  }

  @Builder
  legend(): void {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(this.visibleSegments(), (item: MixSegment) => {
        Row({ space: SpaceTokens.xs }) {
          Row()
            .width(5)
            .height(5)
            .borderRadius(2.5)
            .backgroundColor(item.color)
          Text(String(item.count) + ' ' + item.label)
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        .margin({ right: SpaceTokens.md, top: 2 })
        .alignItems(VerticalAlign.Center)
      }, (item: MixSegment) => item.key)
    }
    .width('100%')
  }

  build() {
    Column({ space: SpaceTokens.xs }) {
      if (this.hasData()) {
        this.bar()
        this.legend()
      } else {
        // 与「近期 N 篇」同一份样本：没帖时两边同时归零，不会一边说没有、一边说有
        Text('近 7 天还没有新帖')
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
