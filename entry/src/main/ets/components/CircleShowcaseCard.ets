// 发现页「内容橱窗卡」：一个圈子的身份 + 一句话 + 近 7 天体裁定 + 活跃度 + 加入。
//
// 设计依据（docs/superpowers/specs/2026-11-20-circle-discover-redesign-design.md §5.2）：
// - 五层结构固定：身份 / 一句话 / 构成条 / 分隔线 / 活跃+动作
// - 整卡点击进圈子详情；「加入」是卡内唯一带色的动作，用 Pressable 单独接手势（不与整卡点击打架）
// - 不展示帖子标题与封面（会变成第二个信息流，且多数圈子无图）
import { CircleOverviewItem } from '../services/api';
import { CircleContentMixBar } from './CircleContentMixBar';
import { TagIcon } from './TagIcon';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { TypeTokens } from '../design/tokens/type';

const EMPTY_ITEM: CircleOverviewItem = {
  name: '', emoji: '', category: '', cityCode: '', description: '',
  memberCount: 0, joined: false, creatorId: null, weight: 2, unread: 0,
  active7d: false, lastPostAt: null, latestPosts: [],
};

@Component
export struct CircleShowcaseCard {
  @Prop item: CircleOverviewItem = EMPTY_ITEM;
  @Prop isDarkMode: boolean = false;
  @Prop joining: boolean = false;
  onOpen: () => void = (): void => {};
  onJoin: () => void = (): void => {};

  private memberText(): string {
    const count: number = this.item.memberCount;
    if (count >= 10000) {
      return (count / 10000).toFixed(1) + ' 万人';
    }
    return String(count) + ' 人';
  }

  private metaText(): string {
    // 预置圈子的 description 多为空，卡片不能只剩人数：分类先补一档信息。
    // 也只在真有近 7 天帖子时才提活跃，避免冷启动期整卡写着「近期安静」劝退。
    const parts: string[] = [];
    if (this.item.category.length > 0) {
      parts.push(this.item.category);
    }
    parts.push(this.memberText());
    if (this.item.active7d) {
      parts.push('近 7 天有新帖');
    }
    return parts.join(' · ');
  }

  private hasPulse(): boolean {
    return (this.item.postCount7d ?? 0) > 0;
  }

  private actionLabel(): string {
    if (this.joining) {
      return '加入中';
    }
    return this.item.joined ? '已加入' : '加入';
  }

  @Builder
  actionPill(): void {
    Pressable({
      visualHeight: 28,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      disabled: this.item.joined || this.joining,
      action: (): void => { this.onJoin(); },
    }) {
      Text(this.actionLabel())
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(this.item.joined ? ColorTokens.tertiary : ColorTokens.brand)
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
    }
  }

  build() {
    Column() {
      Row({ space: SpaceTokens.md }) {
        Column() {
          TagIcon({ name: this.item.name, category: this.item.category, iconSize: 22 })
        }
        .width(40)
        .height(40)
        .backgroundColor(ColorTokens.elevated)
        .border({ width: LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.md)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Text(this.item.name)
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')

      if (this.item.description.length > 0) {
        Text(this.item.description)
          .width('100%')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .lineHeight(TypeTokens.caption.lineHeight)
          .fontColor(ColorTokens.secondary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: SpaceTokens.md })
      }

      // 有近 7 天数据才出构成条；没有就跳过，但底部分隔线 + 状态行两种形态都保留，
      // 让卡片骨架一致（名字 / 简介 / 状态 / 动作），不在推荐卡上摆「还没有新帖」这种劝退文案。
      if (this.hasPulse()) {
        CircleContentMixBar({
          mix: this.item.contentMix ?? { review: 0, pitfall: 0, tutorial: 0, debate: 0, share: 0 },
          total: this.item.postCount7d ?? 0,
          isDarkMode: this.isDarkMode,
        })
          .margin({ top: SpaceTokens.md })
      }

      Divider()
        .color(ColorTokens.separator)
        .strokeWidth(LayoutTokens.hairlineWidth)
        .margin({ top: SpaceTokens.md, bottom: SpaceTokens.sm })

      Row() {
        Text(this.hasPulse()
          ? '近 7 天 ' + String(this.item.postCount7d ?? 0) + ' 条'
          : this.metaText())
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        this.actionPill()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    // 留白按渲染图放宽一档：卡片里要装下「名字/简介/构成/状态」四层，紧凑 padding 会显得憋
    .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, top: SpaceTokens.base, bottom: SpaceTokens.base })
    .backgroundColor(ColorTokens.elevated)
    .border({ width: LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
    .borderRadius(RadiusTokens.lg)
    .alignItems(HorizontalAlign.Start)
    .onClick((): void => { this.onOpen(); })
  }
}
