import { Avatar } from '../design/components/Avatar';
import { Pressable } from '../design/motion/Pressable';
import { SpringPanel } from '../design/motion/SpringPanel';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { TypeTokens } from '../design/tokens/type';
import { resolveActionIcon } from '../utils/actionIcons';

export interface ProfileShareData {
  avatar: string;
  nickname: string;
  bio: string;
  followingCount: number;
  followerCount: number;
  likeCount: number;
  profileUrl: string;
}

@CustomDialog
export struct ProfileShareSheet {
  controller: CustomDialogController;
  getProfile: () => ProfileShareData = (): ProfileShareData => ({
    avatar: '',
    nickname: '有据用户',
    bio: '',
    followingCount: 0,
    followerCount: 0,
    likeCount: 0,
    profileUrl: '',
  });
  onCopyLink: () => void = (): void => {};
  onCopyCardText: () => void = (): void => {};
  onSystemShare: () => void = (): void => {};

  private data(): ProfileShareData {
    return this.getProfile();
  }

  private bio(): string {
    const value: string = this.data().bio.trim();
    return value.length > 0 ? value : '在有据分享真实经验与生活灵感';
  }

  build() {
    SpringPanel({ panelWidth: 344, panelPadding: SpaceTokens.lg }) {
      Column({ space: SpaceTokens.base }) {
        Row() {
          Text('分享主页')
            .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.title.weight)
            .fontColor(ColorTokens.primary)
          Blank()
          Pressable({
            visualHeight: LayoutTokens.segmentedHeight,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.controller.close(); },
          }) {
            Text('取消')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
              .height(LayoutTokens.segmentedHeight)
              .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')

        Column({ space: 12 }) {
          Text('有据 · 个人主页')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.brand)

          Row({ space: 12 }) {
            Avatar({
              avatar: this.data().avatar,
              name: this.data().nickname,
              avatarSize: 56,
            })
            Column({ space: 4 }) {
              Text(this.data().nickname)
                .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
                .fontWeight(TypeTokens.headline.weight)
                .fontColor(ColorTokens.primary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.bio())
                .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.secondary)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')

          Divider().color(ColorTokens.separator)

          Row() {
            this.stat(String(this.data().followingCount), '关注')
            this.stat(String(this.data().followerCount), '粉丝')
            this.stat(String(this.data().likeCount), '获赞')
          }
          .width('100%')

          Text(this.data().profileUrl)
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .width('100%')
        .padding(SpaceTokens.base)
        .backgroundColor(ColorTokens.sunken)
        .borderRadius(RadiusTokens.lg)

        this.shareRow()
      }
      .width('100%')
    }
  }

  // 横向分享按钮：微信/系统、链接、文案
  @Builder
  shareRow() {
    Row({ space: SpaceTokens.md }) {
      this.shareActionButton('微信 / 更多', 'shareWechat', this.onSystemShare)
      this.shareActionButton('复制链接', 'shareLink', this.onCopyLink)
      this.shareActionButton('复制文案', 'book', this.onCopyCardText)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceAround)
  }

  @Builder
  shareActionButton(label: string, iconName: string, action: () => void) {
    Pressable({
      visualHeight: 64,
      touchTargetHeight: 64,
      action: (): void => {
        action();
      },
    }) {
      Column({ space: SpaceTokens.xs }) {
        Column() {
          Image(resolveActionIcon(iconName))
            .width(24).height(24)
            .fillColor(ColorTokens.primary)
        }
        .width(48).height(48)
        .backgroundColor(ColorTokens.sunken)
        .borderRadius(RadiusTokens.pill)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        Text(label)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(76)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private stat(value: string, label: string): void {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.primary)
      Text(label)
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.tertiary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}