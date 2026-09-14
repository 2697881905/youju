import { TagIcon } from './TagIcon';
import { Pressable } from '../design/motion/Pressable';
import { SpringPanel } from '../design/motion/SpringPanel';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 已加入圈子只负责弹层内的三列网格；CircleTab 持有数据加载和跳转意图。
interface JoinedCircle {
  name: string;
}

@CustomDialog
export struct JoinedCirclesDialog {
  controller: CustomDialogController;
  getCircles: () => JoinedCircle[] = (): JoinedCircle[] => [];
  onOpenCircle: (name: string) => void = (_name: string): void => {};

  private circles(): JoinedCircle[] {
    return this.getCircles();
  }

  private gridHeight(): number {
    const rows: number = Math.min(3, Math.max(1, Math.ceil(this.circles().length / 3)));
    return rows * 84;
  }

  @Builder
  private circleTile(circle: JoinedCircle): void {
    Pressable({
      fillWidth: true,
      visualHeight: 76,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: (): void => {
        this.controller.close();
        this.onOpenCircle(circle.name);
      },
    }) {
      Column({ space: SpaceTokens.xs }) {
        TagIcon({ name: circle.name, iconSize: 30 })
        Text(circle.name)
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.overline.lineHeight)
          .fontColor(ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height(76)
      .padding({ left: SpaceTokens.xs, right: SpaceTokens.xs, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      // 与首页分段栏「容器」同款描边规格：透明底 + glassBorderWidth 细描边 barBorder
      // + lg 圆角，无实色垫底、无阴影。面板本身是系统玻璃，透明格子落在玻璃上。
      .backgroundColor(Color.Transparent)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.lg)
    }
  }

  build() {
    // outlined=true：面板做成透明（无背景模糊、无外阴影，只留 barBorder 细描边），
    // 与发布弹窗的毛玻璃面板区分开；immersive 由 outlined 隐含关闭，不再叠 HDS 流光与蒙层。
    SpringPanel({ panelWidth: 344, panelPadding: SpaceTokens.lg, outlined: true, immersive: false }) {
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
          Pressable({
            visualHeight: IconTokens.compact,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.controller.close(); },
          }) {
            Image(resolveActionIcon('close'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
              .fillColor(ColorTokens.secondary)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.circles().length > 0) {
          Grid() {
            ForEach(this.circles(), (circle: JoinedCircle) => {
              GridItem() {
                this.circleTile(circle)
              }
            }, (circle: JoinedCircle) => circle.name)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(SpaceTokens.sm)
          .rowsGap(SpaceTokens.sm)
          .width('100%')
          .height(this.gridHeight())
          .scrollBar(BarState.Off)
        } else {
          Text('暂未加入圈子')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .width('100%')
            .height(76)
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
    }
  }
}
