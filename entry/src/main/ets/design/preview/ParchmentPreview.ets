import { AuthorRow } from '../components/AuthorRow';
import { BaseCard } from '../components/BaseCard';
import { BottomTabBar, BottomTabItem } from '../components/BottomTabBar';
import { ChipItem, ChipRow } from '../components/ChipRow';
import { DesignButton } from '../components/DesignButton';
import { EmptyState } from '../components/EmptyState';
import { IconTile } from '../components/IconTile';
import { PollBlock } from '../components/PollBlock';
import { SegmentedControl, SegmentedItem } from '../components/SegmentedControl';
import { StatRow } from '../components/StatRow';
import { Reveal } from '../motion/Reveal';
import { ColorTokens } from '../tokens/color';
import { RadiusTokens } from '../tokens/radius';
import { SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

const PREVIEW_CHIPS: ChipItem[] = [
  { key: 'all', label: '全部', iconName: '全部' },
  { key: 'digital', label: '数码选购', iconName: '数码选购' },
  { key: 'car', label: '汽车买卖', iconName: '汽车买卖' },
  { key: 'home', label: '家电评测', iconName: '家电评测' },
];

const PREVIEW_SEGMENTS: SegmentedItem[] = [
  { key: 'recommend', label: '推荐' },
  { key: 'follow', label: '关注' },
  { key: 'hot', label: '每日一帖' },
];

const PREVIEW_TABS: BottomTabItem[] = [
  { key: 'home', title: '首页', icon: $r('app.media.nav_home'), color: '#1677FF' },
  { key: 'circle', title: '圈子', icon: $r('app.media.nav_circle'), color: '#E8940B' },
  { key: 'publish', title: '发布', icon: $r('app.media.nav_publish'), color: '#D6604E' },
  { key: 'message', title: '消息', icon: $r('app.media.nav_message'), color: '#8A6F3D' },
  { key: 'profile', title: '我的', icon: $r('app.media.nav_profile'), color: '#B0563A' },
];

interface SwatchItem {
  label: string;
  color: ResourceColor;
}

@Preview
@Component
export struct ParchmentPreview {
  @State selectedIndex: number = 0;
  @State chipIndex: number = 0;
  @State count: number = 12;

  private swatches(): SwatchItem[] {
    return [
      { label: '羊皮纸底', color: ColorTokens.canvas },
      { label: '卡纸面', color: ColorTokens.elevated },
      { label: '浅纸', color: ColorTokens.subtle },
      { label: '纸纹沉', color: ColorTokens.sunken },
      { label: '墨', color: ColorTokens.primary },
      { label: '品牌蓝', color: ColorTokens.brand },
    ];
  }

  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .fontSize(TypeTokens.titleSerif.size)
      .fontFamily(TypeTokens.fontFamilySerif)
      .fontWeight(TypeTokens.titleSerif.weight)
      .lineHeight(TypeTokens.titleSerif.lineHeight)
      .fontColor(ColorTokens.primary)
      .alignSelf(ItemAlign.Start)
      .padding({ left: SpaceTokens.inlineTight });
  }

  build() {
    Column()
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 135,
        colors: [[ColorTokens.canvas, 0], [ColorTokens.sunken, 1]],
      })
      .borderRadius(0)
    {
      Scroll() {
        Column({ space: SpaceTokens.xl }) {
          // ===== 主视觉 =====
          BaseCard({ elevation: 0 }) {
            Column({ space: SpaceTokens.md }) {
              Text('有据 · 设计系统 先行版')
                .fontSize(TypeTokens.overline.size)
                .fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.overline.weight)
                .letterSpacing(3)
                .fontColor(ColorTokens.brand)
              Text('真实经验，有据可循')
                .fontSize(TypeTokens.displaySerif.size)
                .fontFamily(TypeTokens.fontFamilySerif)
                .fontWeight(700)
                .lineHeight(TypeTokens.displaySerif.lineHeight)
                .fontColor(ColorTokens.primary)
              Text('标题用宋体衬线压住信服，正文以轻盈无衬线承接阅读，品牌蓝只出现在该被记住的地方。')
                .fontSize(TypeTokens.body.size)
                .fontFamily(TypeTokens.fontFamily)
                .lineHeight(TypeTokens.body.lineHeight)
                .fontColor(ColorTokens.secondary)
                .textAlign(TextAlign.Start)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          // ===== 羊皮纸色板 =====
          Column({ space: SpaceTokens.sm }) {
            this.sectionTitle('羊皮纸 · 色板')
            BaseCard({ cardPadding: SpaceTokens.block }) {
              Row({ space: SpaceTokens.inline }) {
                ForEach(this.swatches(), (item: SwatchItem) => {
                  Column({ space: SpaceTokens.xs }) {
                    Circle({ width: SpaceTokens.x2l, height: SpaceTokens.x2l })
                      .fill(item.color)
                      .stroke(ColorTokens.sunken)
                      .strokeWidth(1)
                    Text(item.label)
                      .fontSize(TypeTokens.caption.size)
                      .fontFamily(TypeTokens.fontFamily)
                      .fontColor(ColorTokens.secondary)
                  }
                  .layoutWeight(1)
                })
              }
              .width('100%')
            }
          }
          .width('100%')

          // ===== 字阶 =====
          Column({ space: SpaceTokens.sm }) {
            this.sectionTitle('宋体 · 字阶')
            BaseCard({ cardPadding: SpaceTokens.block }) {
              Column({ space: SpaceTokens.block }) {
                Text('大标 · 真实经验，有据可循')
                  .fontSize(TypeTokens.displaySerif.size)
                  .fontFamily(TypeTokens.fontFamilySerif)
                  .fontWeight(700)
                  .lineHeight(TypeTokens.displaySerif.lineHeight)
                  .fontColor(ColorTokens.primary)
                Text('标题 · 拒绝标题党，把经验讲清楚')
                  .fontSize(TypeTokens.titleSerif.size)
                  .fontFamily(TypeTokens.fontFamilySerif)
                  .fontWeight(700)
                  .lineHeight(TypeTokens.titleSerif.lineHeight)
                  .fontColor(ColorTokens.primary)
                Text('正文 · 一个有据可查的理性内容社区，上架在即，敬请期待。')
                  .fontSize(TypeTokens.body.size)
                  .fontFamily(TypeTokens.fontFamily)
                  .lineHeight(TypeTokens.body.lineHeight)
                  .fontColor(ColorTokens.secondary)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')

          // ===== 羊皮纸渐变 =====
          Column({ space: SpaceTokens.sm }) {
            this.sectionTitle('羊皮纸 · 渐变')
            Column()
              .linearGradient({
                angle: 135,
                colors: [[ColorTokens.canvas, 0], [ColorTokens.brandTint, 1]],
              })
              .borderRadius(RadiusTokens.lg)
              .height(140)
              .width('100%')
          }
          .width('100%')

          // ===== 组件示例 =====
          Column({ space: SpaceTokens.sm }) {
            this.sectionTitle('组件 · 示例')
            Reveal({ index: 0 }) {
              BaseCard({ pressable: true }) {
                Column({ space: SpaceTokens.item }) {
                  Text('黄金卡片基座')
                    .fontSize(TypeTokens.headline.size)
                    .fontFamily(TypeTokens.fontFamilySerif)
                    .fontWeight(700)
                    .lineHeight(TypeTokens.headline.lineHeight)
                    .fontColor(ColorTokens.primary)
                    .alignSelf(ItemAlign.Start)
                  SegmentedControl({
                    items: PREVIEW_SEGMENTS,
                    selectedIndex: $selectedIndex,
                    itemWidth: 56,
                    onSelect: (_index: number): void => { this.count += 1; },
                  })
                  ChipRow({ items: PREVIEW_CHIPS, selectedIndex: $chipIndex })
                  Row({ space: SpaceTokens.item }) {
                    IconTile({ icon: $r('app.media.tag_digital_shopping') })
                    Column({ space: SpaceTokens.xs }) {
                      Text('数码短片 · 理性测评')
                        .fontSize(TypeTokens.headline.size)
                        .fontFamily(TypeTokens.fontFamilySerif)
                        .fontWeight(700)
                        .fontColor(ColorTokens.primary)
                      AuthorRow({ name: '科技老张', meta: '12天前' })
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  PollBlock({ planA: '小米', planB: '华为' })
                  StatRow({
                    liked: this.count % 2 === 0,
                    likeCount: this.count,
                    commentCount: 2,
                    onLike: (): void => { this.count += 1; },
                  })
                  Row({ space: SpaceTokens.inline }) {
                    DesignButton({ label: '有据可循', action: (): void => { this.count += 1; } })
                    DesignButton({ label: '次按钮', variant: 'ghost', action: (): void => { this.count += 1; } })
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }

            EmptyState({ title: '暂无推文', message: '好经验，值得被更多人看见' })

            BottomTabBar({ items: PREVIEW_TABS, currentIndex: $selectedIndex, unreadCount: 3 })
          }
          .width('100%')
        }
        .width('100%')
        .padding(SpaceTokens.base)
      }
      .width('100%')
      .height('100%')
    }
  }
}