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
import { Collapse } from '../motion/Collapse';
import { CountRoll } from '../motion/CountRoll';
import { Pressable } from '../motion/Pressable';
import { Reveal } from '../motion/Reveal';
import { SharedSlide } from '../motion/SharedSlide';
import { Skeleton } from '../motion/Skeleton';
import { ColorTokens } from '../tokens/color';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
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
  { key: 'home', title: '首页', icon: $r('app.media.nav_home'), color: '#0A84FF' },
  { key: 'circle', title: '圈子', icon: $r('app.media.nav_circle'), color: '#34C759' },
  { key: 'publish', title: '发布', icon: $r('app.media.nav_publish'), color: '#FF9500' },
  { key: 'message', title: '消息', icon: $r('app.media.nav_message'), color: '#AF52DE' },
  { key: 'profile', title: '我的', icon: $r('app.media.nav_profile'), color: '#FF2D55' },
];

@Preview
@Component
export struct FoundationPreview {
  @State selectedIndex: number = 0;
  @State chipIndex: number = 0;
  @State bottomIndex: number = 0;
  @State count: number = 12;
  @State expanded: boolean = true;

  build() {
    Scroll() {
      Column({ space: SpaceTokens.section }) {
        Reveal({ index: 0 }) {
          BaseCard({ pressable: true }) {
            Column({ space: SpaceTokens.item }) {
              Text('黄金卡片基座')
                .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.headline.weight)
                .lineHeight(TypeTokens.headline.lineHeight)
                .fontColor(ColorTokens.primary)
              CountRoll({ value: this.count, prefix: '顶 ' })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }

        SegmentedControl({
          items: PREVIEW_SEGMENTS,
          selectedIndex: $selectedIndex,
          itemWidth: 56,
          onSelect: (_index: number): void => { this.count += 1; },
        })

        ChipRow({
          items: PREVIEW_CHIPS,
          selectedIndex: $chipIndex,
        })

        BaseCard() {
          Column({ space: SpaceTokens.item }) {
            Row({ space: SpaceTokens.item }) {
              IconTile({ icon: $r('app.media.tag_digital_shopping') })
              Column({ space: SpaceTokens.xs }) {
                Text('Phase 2 原子')
                  .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
                  .fontWeight(TypeTokens.headline.weight)
                  .fontColor(ColorTokens.primary)
                AuthorRow({ name: '科技老张', meta: '12天前' })
              }
              .layoutWeight(1)
            }
            PollBlock({ planA: '小米', planB: '华为' })
            StatRow({
              liked: this.count % 2 === 0,
              likeCount: this.count,
              commentCount: 2,
              onLike: (): void => { this.count += 1; },
            })
            Row({ space: SpaceTokens.inline }) {
              DesignButton({ label: '主按钮' })
              DesignButton({ label: '次按钮', variant: 'ghost' })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        Stack() {
          SharedSlide({
            selectedIndex: this.selectedIndex,
            itemCount: 2,
            controlHeight: LayoutTokens.segmentedHeight,
          })
          Row() {
            ForEach(['左', '右'], (label: string, index: number) => {
              Column() {
                Pressable({
                  action: () => {
                    this.selectedIndex = index;
                    this.count += 1;
                  }
                }) {
                  Text(label)
                    .width('100%')
                    .height(LayoutTokens.segmentedHeight)
                    .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                    .fontColor(ColorTokens.primary)
                    .textAlign(TextAlign.Center)
                }
              }
              .layoutWeight(1)
            })
          }
        }
        .width('100%')
        .height(LayoutTokens.segmentedHeight)
        .padding(SpaceTokens.xs)
        .backgroundColor(ColorTokens.sunken)
        .borderRadius(RadiusTokens.md)

        Skeleton({ skeletonHeight: SpaceTokens.x3l * 2, radius: RadiusTokens.md })

        Pressable({ action: () => { this.expanded = !this.expanded; } }) {
          Text(this.expanded ? '收起' : '展开')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brand)
        }
        Collapse({ expanded: this.expanded }) {
          EmptyState({ title: '暂无内容', message: '内容出现后会显示在这里' })
        }

        BottomTabBar({
          items: PREVIEW_TABS,
          currentIndex: $bottomIndex,
          unreadCount: 3,
        })
      }
      .width('100%')
      .padding(SpaceTokens.pageCompact)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
  }
}
