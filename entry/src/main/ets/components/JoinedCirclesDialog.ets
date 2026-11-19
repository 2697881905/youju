import { TagIcon } from './TagIcon';
import { Pressable } from '../design/motion/Pressable';
import { IconButton } from '../design/components/IconButton';
import { DesignButton } from '../design/components/DesignButton';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 已加入圈子只负责弹层内容；CircleTab 持有数据加载和跳转意图。
// 从「三列图标墙」改成列表：名称之外补成员数、未读数、近期活跃，先给信息再给入口。
// 2026-11-20：从 @CustomDialog + SpringPanel 改为 bindSheet 内容（表面由 SheetOptions.systemMaterial
// 提供，本组件不再自绘面板底/描边/阴影——那层会盖住系统材质）。关闭走 onClose 回调。
interface JoinedCircle {
  name: string;
  category?: string;
  members?: number;
  unread?: number;
  hasActivity?: boolean;
}

@Component
export struct JoinedCirclesDialog {
  getCircles: () => JoinedCircle[] = (): JoinedCircle[] => [];
  onOpenCircle: (name: string) => void = (_name: string): void => {};
  onExplore: () => void = (): void => {};
  onClose: () => void = (): void => {};

  private circles(): JoinedCircle[] {
    return this.getCircles();
  }

  private statusText(circle: JoinedCircle): string {
    const members: number = circle.members ?? 0;
    const unread: number = circle.unread ?? 0;
    if (unread > 0) {
      return members + ' 人 · ' + unread + ' 条新帖';
    }
    return members + ' 人 · ' + (circle.hasActivity ? '近 7 天有新帖' : '近期安静');
  }

  @Builder
  private circleRow(circle: JoinedCircle, isLast: boolean): void {
    Pressable({
      fillWidth: true,
      fullResponseRegion: true,
      action: (): void => {
        this.onClose();
        this.onOpenCircle(circle.name);
      },
    }) {
      Row({ space: SpaceTokens.md }) {
        TagIcon({ name: circle.name, category: circle.category ?? '', iconSize: 24, tint: ColorTokens.brand })
          .width(34)
          .height(34)
        Column({ space: 2 }) {
          Text(circle.name)
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.statusText(circle))
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontColor((circle.unread ?? 0) > 0 ? ColorTokens.brand : ColorTokens.secondary)
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('›')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
      }
      .width('100%')
      .padding({ top: SpaceTokens.sm, bottom: isLast ? SpaceTokens.none : SpaceTokens.sm })
      .alignItems(VerticalAlign.Center)
    }
  }

  build() {
    Column({ space: SpaceTokens.base }) {
      Row({ space: SpaceTokens.sm }) {
        Column({ space: 2 }) {
          Text('已加入的圈子')
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.headline.lineHeight)
            .fontColor(ColorTokens.primary)
          Text(String(this.circles().length) + ' 个圈子')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        IconButton({ icon: 'close', a11yText: '关闭', action: (): void => { this.onClose(); } })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.circles().length > 0) {
        Scroll() {
          Column() {
            ForEach(this.circles(), (circle: JoinedCircle, index: number) => {
              this.circleRow(circle, index === this.circles().length - 1)
              if (index < this.circles().length - 1) {
                Divider().color(ColorTokens.separator).strokeWidth(LayoutTokens.hairlineWidth)
              }
            }, (circle: JoinedCircle) => circle.name)
          }
          .width('100%')
        }
        // 半模态内的高度上限：比原居中弹窗(336)放宽，贴着 sheet 的 MEDIUM 档滚动。
        .constraintSize({ maxHeight: 420 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.TopStart)
        .width('100%')
      } else {
        Column({ space: SpaceTokens.md }) {
          Text('暂未加入圈子')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .width('100%')
            .textAlign(TextAlign.Center)
          DesignButton({
            label: '去发现圈子',
            variant: 'outlined',
            action: (): void => {
              this.onClose();
              this.onExplore();
            },
          })
            .width('100%')
        }
        .width('100%')
        .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.sm })
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    // 顶部留窄：sheet 自带 dragBar 与关闭钮在右上，标题行要与它同一水平中线。
    .padding({ left: SpaceTokens.xl, right: SpaceTokens.xl, top: SpaceTokens.sm, bottom: SpaceTokens.xl })
    .alignItems(HorizontalAlign.Start)
  }
}
