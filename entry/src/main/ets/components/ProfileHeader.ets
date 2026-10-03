import { ProfileIdentity } from './ProfileIdentity';
import { ProfileStatItem } from './ProfileStatItem';
import { resolveActionIcon } from '../utils/actionIcons';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { isImmersiveLightSenseSupported, GlassBlurStyle, TopButtonMaterialModifier, isSystemMaterialActive } from '../utils/immersiveMaterial';

// 个人资料区只负责呈现与操作意图；页面决定跳转、分享和数据加载等领域行为。
// 本组件当前唯一宿主是 Navigation 标题栏（首页/我的顶栏迁入方案）——
// 因此三处按钮（编辑资料 / 草稿箱 / 废纸篓）直接挂系统材质（uiMaterial 沉浸光感，
// 仅标题栏等官方生效区域会渲染；低版本设备门禁不通过时保留原玻璃/描边样式）。
@Component
export struct ProfileHeader {
  @Prop avatar: string = '';
  @Prop name: string = '';
  @Prop gender: number = 0;
  @Prop bio: string = '';
  @Prop userId: number = 0;
  @Prop isLoggedIn: boolean = false;
  @Prop followingCount: number = 0;
  @Prop followerCount: number = 0;
  @Prop totalLikes: number = 0;
  @Prop onBackground: boolean = false;
  onOpenFollowing: () => void = (): void => {};
  onOpenFollowers: () => void = (): void => {};
  onEdit: () => void = (): void => {};
  onOpenDrafts: () => void = (): void => {};
  onOpenTrash: () => void = (): void => {};
  onLogin: () => void = (): void => {};

  private materialModifier: TopButtonMaterialModifier = new TopButtonMaterialModifier();

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
          action: (): void => { this.isLoggedIn ? this.onEdit() : this.onLogin(); },
        }) {
          Text(this.isLoggedIn ? '编辑资料' : '去登录')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .fontColor(this.isLoggedIn ? ColorTokens.primary : ColorTokens.brand)
            .width(76)
            .height(LayoutTokens.segmentedHeight)
            .textAlign(TextAlign.Center)
            // 材质生效时撤掉自绘毛玻璃与阴影：背景模糊会遮挡材质（官方 FAQ），自绘阴影会与材质阴影叠加；
            // 低版本（材质不生效）保留原玻璃底 + 阴影样式。
            .backgroundBlurStyle(isSystemMaterialActive() ? BlurStyle.NONE : GlassBlurStyle.Press)
            .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : (this.isLoggedIn ? ColorTokens.barSurface : ColorTokens.brandTint))
            .border({ width: LayoutTokens.glassBorderWidth, color: this.isLoggedIn ? ColorTokens.barBorder : ColorTokens.brand, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.floatingBar)
            .shadow({
              radius: isSystemMaterialActive() ? 0 : 12,
              color: isSystemMaterialActive() ? Color.Transparent : ColorTokens.barShadow,
              offsetY: isSystemMaterialActive() ? 0 : 4,
            })
            // 沉浸光感：标题栏内由系统材质接管表面（低版本自动跳过，保留上面的玻璃/描边样式）
            .attributeModifier(this.materialModifier)
        }
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.sm })

      if (this.isLoggedIn) {
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
                .fillColor(ColorTokens.icon)
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
            // 材质生效时撤掉自绘毛玻璃与阴影：背景模糊会遮挡材质（官方 FAQ），自绘阴影会与材质阴影叠加；
            // 低版本（材质不生效）保留原玻璃底 + 阴影样式。
            .backgroundBlurStyle(isSystemMaterialActive() ? BlurStyle.NONE : GlassBlurStyle.Press)
            .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
            .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.floatingBar)
            .shadow({
              radius: isSystemMaterialActive() ? 0 : 12,
              color: isSystemMaterialActive() ? Color.Transparent : ColorTokens.barShadow,
              offsetY: isSystemMaterialActive() ? 0 : 4,
            })
            // 沉浸光感：标题栏内由系统材质接管表面（低版本自动跳过，保留上面的玻璃/描边样式）
            .attributeModifier(this.materialModifier)
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
                .fillColor(ColorTokens.icon)
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
            // 材质生效时撤掉自绘毛玻璃与阴影：背景模糊会遮挡材质（官方 FAQ），自绘阴影会与材质阴影叠加；
            // 低版本（材质不生效）保留原玻璃底 + 阴影样式。
            .backgroundBlurStyle(isSystemMaterialActive() ? BlurStyle.NONE : GlassBlurStyle.Press)
            .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
            .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.floatingBar)
            .shadow({
              radius: isSystemMaterialActive() ? 0 : 12,
              color: isSystemMaterialActive() ? Color.Transparent : ColorTokens.barShadow,
              offsetY: isSystemMaterialActive() ? 0 : 4,
            })
            // 沉浸光感：标题栏内由系统材质接管表面（低版本自动跳过，保留上面的玻璃/描边样式）
            .attributeModifier(this.materialModifier)
          }
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.xs })
      }
    }
    .width('100%')
  }
}
