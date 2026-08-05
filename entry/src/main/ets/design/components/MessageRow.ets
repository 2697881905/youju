import { Avatar } from './Avatar';
import { IconTile } from './IconTile';
import { Pressable } from '../motion/Pressable';
import { ColorTokens } from '../tokens/color';
import { IconTokens } from '../tokens/icon';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';

@Component
export struct MessageRow {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop time: string = '';
  @Prop avatar: string = '';
  @Prop name: string = '';
  @Prop useIcon: boolean = false;
  @Prop icon: Resource = $r('app.media.notification_system');
  @Prop unread: boolean = false;
  @Prop unreadCount: number = 0;
  @Prop titleMaxLines: number = 1;
  @Prop subtitleMaxLines: number = 1;
  @StorageLink('reduceMotion') appReduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;

  action?: () => void = undefined;
  avatarAction?: () => void = undefined;

  private safeTitle(): string {
    return this.title ?? '';
  }

  private safeSubtitle(): string {
    return this.subtitle ?? '';
  }

  private safeTime(): string {
    return this.time ?? '';
  }

  private safeAvatar(): string {
    return this.avatar ?? '';
  }

  private safeName(): string {
    return this.name ?? '';
  }

  private displayBadge(): string {
    if (this.unreadCount > 99) {
      return '99+';
    }
    return String(this.unreadCount);
  }

  private shouldReduceMotion(): boolean {
    return this.appReduceMotion || this.systemReduceMotion;
  }

  @Builder
  leadingVisual(): void {
    if (this.useIcon) {
      IconTile({
        icon: this.icon,
        tileSize: IconTokens.empty,
        iconSize: IconTokens.standard,
      })
    } else {
      Avatar({
        avatar: this.safeAvatar(),
        name: this.safeName(),
        avatarSize: IconTokens.empty,
      })
    }
  }

  @Builder
  leadingSlot(): void {
    if (this.avatarAction !== undefined) {
      Pressable({
        visualHeight: IconTokens.empty,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        action: (): void => {
          if (this.avatarAction !== undefined) {
            this.avatarAction();
          }
        },
      }) {
        this.leadingVisual()
      }
    } else {
      this.leadingVisual()
    }
  }

  @Builder
  trailingSlot(): void {
    Column({ space: SpaceTokens.inlineTight }) {
      if (this.safeTime().length > 0) {
        Text(this.safeTime())
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.overline.lineHeight)
          .letterSpacing(TypeTokens.overline.tracking)
          .fontColor(ColorTokens.tertiary)
          .maxLines(1)
      }
      if (this.unreadCount > 0) {
        Text(this.displayBadge())
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.overline.weight)
          .lineHeight(TypeTokens.overline.lineHeight)
          .fontColor(ColorTokens.onBrand)
          .backgroundColor(ColorTokens.danger)
          .borderRadius(RadiusTokens.pill)
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.xs })
          .constraintSize({ minWidth: IconTokens.small })
          .textAlign(TextAlign.Center)
      } else {
        Circle({ width: SpaceTokens.sm, height: SpaceTokens.sm })
          .fill(ColorTokens.danger)
          .opacity(this.unread ? 1 : 0)
          .scale({
            x: this.unread && !this.shouldReduceMotion() ? 1 : 0,
            y: this.unread && !this.shouldReduceMotion() ? 1 : 0,
          })
          .animation({
            duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.fast,
            curve: MotionCurves.spring,
          })
      }
    }
    .alignItems(HorizontalAlign.End)
  }

  build() {
    Pressable({
      fillWidth: true,
      visualHeight: LayoutTokens.minTouchTarget,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: (): void => {
        if (this.action !== undefined) {
          this.action();
        }
      },
    }) {
      Column() {
        Row({ space: SpaceTokens.item }) {
          this.leadingSlot()
          Column({ space: SpaceTokens.xs }) {
            Text(this.safeTitle())
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .lineHeight(TypeTokens.body.lineHeight)
              .letterSpacing(TypeTokens.body.tracking)
              .fontColor(ColorTokens.primary)
              .maxLines(this.titleMaxLines)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.safeSubtitle().length > 0) {
              Text(this.safeSubtitle())
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.callout.weight)
                .lineHeight(TypeTokens.callout.lineHeight)
                .letterSpacing(TypeTokens.callout.tracking)
                .fontColor(ColorTokens.secondary)
                .maxLines(this.subtitleMaxLines)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          this.trailingSlot()
        }
        .width('100%')
        .padding({ top: SpaceTokens.item, bottom: SpaceTokens.item })
        .alignItems(VerticalAlign.Center)
        Divider()
          .height(LayoutTokens.hairlineWidth)
          .color(ColorTokens.separator)
      }
      .width('100%')
    }
  }
}
