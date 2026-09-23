// 个人主页分享面板（底部拉起式菜单栏）。
// 骨架与帖子分享面板 ShareSheet 完全同构：抓手 + 居中标题 + 单一 elevated 主卡片 +
// 独立「取消」卡片，外层左右/底部留边；内容区为「主页预览 + 分隔线 + 分享按钮行」。
// 调用侧须配 alignment=Bottom + customStyle=true（由面板自身提供背景与圆角）。
import { Avatar } from '../design/components/Avatar';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { TypeTokens } from '../design/tokens/type';
import { resolveActionIcon } from '../utils/actionIcons';

const AVATAR_SIZE: number = 56;
const BUTTON_WIDTH: number = 72;

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

  @Builder
  divider() {
    Divider()
      .color(ColorTokens.separator)
      .strokeWidth(LayoutTokens.hairlineWidth)
  }

  // 主页预览：头像 + 昵称/简介 + 统计 + 链接；直接铺在主卡片上（不另起下沉底色块）
  @Builder
  profileBlock() {
    Column({ space: SpaceTokens.md }) {
      Row({ space: SpaceTokens.md }) {
        Avatar({
          avatar: this.data().avatar,
          name: this.data().nickname,
          avatarSize: AVATAR_SIZE,
        })
        Column({ space: SpaceTokens.xs }) {
          Text(this.data().nickname)
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.bio())
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

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
    .padding({ bottom: SpaceTokens.md })
  }

  // 横向分享按钮：圆形浅底图标 + 下方文字（与 ShareSheet 同款尺寸）
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
            .fillColor(ColorTokens.icon)
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
          .constraintSize({ maxWidth: BUTTON_WIDTH })
      }
      .width(BUTTON_WIDTH)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private stat(value: string, label: string): void {
    Column({ space: SpaceTokens.xs }) {
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

  build() {
    Column() {
      // 主菜单卡片：抓手 + 标题 + 预览 + 分享按钮
      Column() {
        Row()
          .width(36)
          .height(4)
          .backgroundColor(ColorTokens.separator)
          .borderRadius(RadiusTokens.pill)
          .margin({ top: SpaceTokens.md, bottom: SpaceTokens.sm })

        Text('分享主页')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.secondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.md })

        this.profileBlock()

        this.divider()

        Row({ space: SpaceTokens.sm }) {
          this.shareActionButton('微信 / 更多', 'shareWechat', this.onSystemShare)
          this.shareActionButton('复制链接', 'shareLink', this.onCopyLink)
          this.shareActionButton('复制文案', 'book', this.onCopyCardText)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ top: SpaceTokens.md, bottom: SpaceTokens.md })
      }
      .width('100%')
      .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, bottom: SpaceTokens.sm })
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.lg)
      .clip(true)

      // 取消按钮：独立卡片，居中，点击即收起
      Column() {
        Pressable({
          fillWidth: true,
          visualHeight: LayoutTokens.minTouchTarget,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => {
            this.controller.close();
          },
        }) {
          Text('取消')
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.secondary)
            .width('100%')
            .height(LayoutTokens.minTouchTarget)
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.lg)
      .margin({ top: SpaceTokens.sm })
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.lg })
  }
}
