import { ProfileIdentity } from './ProfileIdentity';
import { ProfileStatItem } from './ProfileStatItem';
import { resolveActionIcon } from '../utils/actionIcons';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 个人资料区只负责呈现与操作意图；页面决定跳转、分享和数据加载等领域行为。
@Component
export struct ProfileHeader {
  @Prop avatar: string = '';
  @Prop name: string = '';
  @Prop gender: number = 0;
  @Prop bio: string = '';
  @Prop userId: number = 0;
  @Prop followingCount: number = 0;
  @Prop followerCount: number = 0;
  @Prop totalLikes: number = 0;
  @Prop onBackground: boolean = false;
  onOpenFollowing: () => void = (): void => {};
  onOpenFollowers: () => void = (): void => {};
  onEdit: () => void = (): void => {};
  onOpenDrafts: () => void = (): void => {};
  onOpenTrash: () => void = (): void => {};

  build() {
    Column() {
      ProfileIdentity({
        avatar: this.avatar,
        name: this.name,
        gender: this.gender,
        bio: this.bio,
        userId: this.userId,
        onBackground: this.onBackground,
      })
      Row({ space: SpaceTokens.sm }) {
        ProfileStatItem({
          value: this.followingCount,
          label: '关注',
          onBackground: this.onBackground,
          clickable: true,
          onOpen: (): void => { this.onOpenFollowing(); },
        })
        ProfileStatItem({
          value: this.followerCount,
          label: '粉丝',
          onBackground: this.onBackground,
          clickable: true,
          onOpen: (): void => { this.onOpenFollowers(); },
        })
        ProfileStatItem({ value: this.totalLikes, label: '获赞', onBackground: this.onBackground })
        Blank().layoutWeight(1)
        Pressable({
          visualHeight: LayoutTokens.segmentedHeight,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => { this.onEdit(); },
        }) {
          Text('编辑资料')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .fontColor(ColorTokens.primary)
            .width(76)
            .height(LayoutTokens.segmentedHeight)
            .textAlign(TextAlign.Center)
            .backgroundColor(ColorTokens.barSurface)
            .backdropBlur(LayoutTokens.glassBlur)
            .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.floatingBar)
            .shadow({ radius: 12, color: ColorTokens.barShadow, offsetY: 4 })
        }
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.sm })

      Row({ space: SpaceTokens.sm }) {
        Column() {
          Pressable({
            fillWidth: true,
            visualHeight: LayoutTokens.segmentedHeight,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.onOpenDrafts(); },
          }) {
            Row({ space: SpaceTokens.inlineTight }) {
              Image(resolveActionIcon('draftBox'))
                .width(IconTokens.compact)
                .height(IconTokens.compact)
              Text('草稿箱')
                .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.headline.weight)
                .lineHeight(TypeTokens.caption.lineHeight)
                .fontColor(ColorTokens.primary)
            }
            .width('100%')
            .height(LayoutTokens.segmentedHeight)
            .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(ColorTokens.barSurface)
            .backdropBlur(LayoutTokens.glassBlur)
            .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.floatingBar)
            .shadow({ radius: 12, color: ColorTokens.barShadow, offsetY: 4 })
          }
        }
        .layoutWeight(1)
        Column() {
          Pressable({
            fillWidth: true,
            visualHeight: LayoutTokens.segmentedHeight,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.onOpenTrash(); },
          }) {
            Row({ space: SpaceTokens.inlineTight }) {
              Image($r('app.media.set_trash'))
                .width(IconTokens.compact)
                .height(IconTokens.compact)
              Text('废纸篓')
                .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.headline.weight)
                .lineHeight(TypeTokens.caption.lineHeight)
                .fontColor(ColorTokens.primary)
            }
            .width('100%')
            .height(LayoutTokens.segmentedHeight)
            .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(ColorTokens.barSurface)
            .backdropBlur(LayoutTokens.glassBlur)
            .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.floatingBar)
            .shadow({ radius: 12, color: ColorTokens.barShadow, offsetY: 4 })
          }
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.xs })
    }
    .width('100%')
  }
}
