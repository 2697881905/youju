import { image } from '@kit.ImageKit';
import { resolveDisplayImageUrl } from '../services/api';
import { Avatar } from '../design/components/Avatar';
import { resolveSettingsIcon } from '../utils/settingsIcons';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 编辑页预览复用主页资料区的层级，媒体仅在页面保存成功后由宿主提交。
@Component
export struct EditableProfilePreview {
  @Prop avatar: string = '';
  // 像素图预览用 @Link（父子共享引用）而非 @Prop（单向拷贝）：
  // @Prop 对 image.PixelMap 这类复杂对象只按引用比较，选图后父组件更新不一定驱动本组件重渲染，
  // 导致「修改背景不即时显示、点保存才渲染」（保存后改走 URL 分支 + string 变化才触发）。
  @Link avatarPreview: image.PixelMap | null;
  @Link profileBackgroundPreview: image.PixelMap | null;
  @Prop nickname: string = '';
  @Prop bio: string = '';
  @Prop selectedGender: string = '0';
  @Prop profileId: number = 0;
  @Prop followingCount: number = 0;
  @Prop followerCount: number = 0;
  @Prop totalLikes: number = 0;
  @Prop profileBackground: string = '';
  @Prop backgroundStatus: string = '';
  @Prop uploadingBackground: boolean = false;
  onPickBackground: () => void = (): void => {};
  onPickAvatar: () => void = (): void => {};

  private genderText(): string {
    return this.selectedGender === '1' ? '男' : (this.selectedGender === '2' ? '女' : '保密');
  }

  @Builder
  private previewStat(value: number, label: string): void {
    Column({ space: SpaceTokens.inlineTight }) {
      Text(String(value))
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.headline.weight).fontColor(Color.White)
        .margin({ left: 5 })
      Text(label)
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor('#E6FFFFFF')
    }
    .width(LayoutTokens.profileStatWidth)
    .alignItems(HorizontalAlign.Start)
    .margin({ left: SpaceTokens.xs })
  }

  @Builder
  private profileContent(): void {
    Column() {
      Row({ space: SpaceTokens.sm }) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(124).height(124).position({ x: -9, y: -7 })
            .radialGradient({
              center: [70, 74], radius: 74,
              colors: [['#5CFF84B4', 0.0], ['#28FF9BC3', 0.48], [ColorTokens.glassClear, 1.0]],
            })
            .borderRadius(RadiusTokens.pill).clip(true).hitTestBehavior(HitTestMode.None)
          if (this.avatarPreview) {
            Image(this.avatarPreview)
              .width(94).height(94).borderRadius(RadiusTokens.pill).objectFit(ImageFit.Cover).clip(true)
          } else {
            Avatar({ avatar: this.avatar, name: this.nickname, avatarSize: 94 })
          }
        }
        .width(124).height(110)

        Column({ space: SpaceTokens.inlineTight }) {
          Row({ space: SpaceTokens.inline }) {
            Text(this.nickname.length > 0 ? this.nickname : '你的昵称')
              .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
              .fontWeight(TypeTokens.headline.weight).fontColor(Color.White).maxLines(1)
            Text(this.genderText())
              .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.overline.weight)
              .fontColor(this.selectedGender === '1'
                ? ColorTokens.brand
                : this.selectedGender === '2' ? '#D94F87' : ColorTokens.secondary)
              .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
              .backgroundColor(this.selectedGender === '1'
                ? ColorTokens.brandTint
                : this.selectedGender === '2' ? '#FFF0F5' : ColorTokens.sunken)
              .borderRadius(RadiusTokens.pill)
          }
          Text(this.bio.length > 0 ? this.bio : '在这里写下你的个人介绍')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor('#E6FFFFFF').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('ID: ' + (this.profileId > 0 ? String(this.profileId) : '-'))
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily).fontColor('#CCFFFFFF')
        }
        .layoutWeight(1).alignItems(HorizontalAlign.End)
      }
      .width('100%').height(110)
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.xs })

      Row({ space: SpaceTokens.sm }) {
        this.previewStat(this.followingCount, '关注')
        this.previewStat(this.followerCount, '粉丝')
        this.previewStat(this.totalLikes, '获赞')
      }
      .width('100%').padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.sm })

      Row({ space: SpaceTokens.sm }) {
        Column() {
          this.editorAction('修改背景', (): void => { this.onPickBackground(); })
        }.layoutWeight(1)
        Column() {
          this.editorAction('修改头像', (): void => { this.onPickAvatar(); })
        }.layoutWeight(1)
      }
      .width('100%').padding({ bottom: SpaceTokens.xs })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.End)
    .backgroundColor('#52000000')
  }

  @Builder
  private editorAction(label: string, action: () => void): void {
    Pressable({
      fillWidth: true,
      visualHeight: LayoutTokens.segmentedHeight,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: action,
    }) {
      Row({ space: SpaceTokens.inlineTight }) {
        Image(resolveSettingsIcon('edit')).width(IconTokens.compact).height(IconTokens.compact).fillColor(ColorTokens.primary)
        Text(label)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight).fontColor(ColorTokens.primary)
      }
      .width(160).height(LayoutTokens.segmentedHeight)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
      .backgroundColor(ColorTokens.barSurface).backdropBlur(LayoutTokens.glassBlur)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.floatingBar)
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      if (this.profileBackgroundPreview) {
        Image(this.profileBackgroundPreview).width('100%').height('100%').objectFit(ImageFit.Cover)
      } else if (this.profileBackground) {
        Image(resolveDisplayImageUrl(this.profileBackground)).width('100%').height('100%').objectFit(ImageFit.Cover)
      } else {
        Column().width('100%').height('100%').backgroundColor(ColorTokens.sunken)
      }
      this.profileContent()
      if (this.backgroundStatus !== '') {
        Text(this.backgroundStatus)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(Color.White)
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.xs })
          .backgroundColor(this.backgroundStatus === '待保存' ? '#A80A84FF' : '#A8000000')
          .borderRadius(RadiusTokens.pill)
          .position({ top: SpaceTokens.sm, left: SpaceTokens.sm })
      }
      if (this.uploadingBackground) {
        Column() {
          Row({ space: SpaceTokens.sm }) {
            LoadingProgress().width(IconTokens.compact).height(IconTokens.compact).color(ColorTokens.brand)
            Text('正在保存背景图')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(Color.White)
          }
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
          .backgroundColor('#AA000000').backdropBlur(LayoutTokens.glassBlur)
          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.glassWhite, style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.floatingBar)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%').height('100%').justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .aspectRatio(16 / 10)
    .clip(true)
    .borderRadius(RadiusTokens.lg)
  }
}
