import { Avatar } from '../design/components/Avatar';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 资料身份信息不包含关注、编辑或私信等权限动作，可由本人和他人主页安全复用。
@Component
export struct ProfileIdentity {
  @Prop avatar: string = '';
  @Prop name: string = '';
  @Prop gender: number = 0;
  @Prop bio: string = '';
  @Prop userId: number = 0;
  @Prop deleted: boolean = false;
  @Prop onBackground: boolean = false;

  private genderLabel(): string {
    return this.gender === 1 ? '男' : this.gender === 2 ? '女' : '保密';
  }

  private genderColor(): ResourceColor {
    return this.gender === 1 ? ColorTokens.brand : this.gender === 2 ? '#D94F87' : ColorTokens.secondary;
  }

  private genderSurface(): ResourceColor {
    return this.gender === 1 ? ColorTokens.brandTint : this.gender === 2 ? '#FFF0F5' : ColorTokens.sunken;
  }

  build() {
    Row({ space: SpaceTokens.sm }) {
      Stack() {
        if (this.deleted) {
          Text('?')
            .width(this.onBackground ? 94 : 114)
            .height(this.onBackground ? 94 : 114)
            .borderRadius(RadiusTokens.pill)
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.onBrand)
            .backgroundColor(ColorTokens.quaternary)
            .textAlign(TextAlign.Center)
        } else {
          Column()
            .width(this.onBackground ? 124 : 150)
            .height(this.onBackground ? 124 : 150)
            .position({ x: -9, y: -7 })
            .radialGradient({
              center: [70, 74],
              radius: 74,
              colors: [['#5CFF84B4', 0.0], ['#28FF9BC3', 0.48], [ColorTokens.glassClear, 1.0]],
            })
            .borderRadius(RadiusTokens.pill)
            .clip(true)
            .hitTestBehavior(HitTestMode.None)
          Avatar({ avatar: this.avatar, name: this.name, avatarSize: this.onBackground ? 94 : 114 })
            .position({ x: this.onBackground ? 10 : 12, y: this.onBackground ? 12 : 16 })
        }
      }
      .width(this.onBackground ? 124 : 150)
      .height(this.onBackground ? 118 : 146)

      Column({ space: SpaceTokens.inlineTight }) {
        Row({ space: SpaceTokens.inline }) {
          Text(this.deleted ? '已注销用户' : this.name)
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.headline.lineHeight)
            .letterSpacing(TypeTokens.headline.tracking)
            .fontColor(this.onBackground ? '#FFFFFFFF' : ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (!this.deleted) {
            Text(this.genderLabel())
              .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.overline.weight)
              .lineHeight(TypeTokens.overline.lineHeight)
              .letterSpacing(TypeTokens.overline.tracking)
              .fontColor(this.genderColor())
              .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
              .backgroundColor(this.genderSurface())
              .borderRadius(RadiusTokens.pill)
          }
        }
        if (this.bio.length > 0) {
          Text(this.bio)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .letterSpacing(TypeTokens.caption.tracking)
            .fontColor(this.onBackground ? '#E6FFFFFF' : ColorTokens.secondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text('ID: ' + String(this.userId > 0 ? this.userId : '-'))
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.caption.lineHeight)
          .letterSpacing(TypeTokens.caption.tracking)
          .fontFeature(TypeTokens.tabularFeature)
          .fontColor(this.onBackground ? '#CCFFFFFF' : ColorTokens.tertiary)
      }
      .alignItems(HorizontalAlign.End)
      .layoutWeight(1)
    }
    .width('100%')
    .height(this.onBackground ? 118 : 146)
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.xs })
  }
}
