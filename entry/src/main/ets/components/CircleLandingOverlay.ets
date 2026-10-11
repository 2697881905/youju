import { Post } from '../models/types';
import { listPosts, followTag, unfollowTag } from '../services/api';
import { getToken } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { TagIcon } from './TagIcon';
import { Reveal } from '../design/motion/Reveal';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 降落页（星图 Live 一期）：点行星后从底部滑入的轻详情层。
// 职责：圈子信息头部 + 加入/退出按钮（含成功后的点亮回调） + 帖子流「点灯」编舞 + 起飞返回。
// 语义边界：只读预览 + 加入转化；发帖/完整功能经「进入完整圈子页」跳 CircleDetailPage。
@Component
export struct CircleLandingOverlay {
  @Prop circleName: string = '';
  @Prop description: string = '';
  @Prop category: string = '';
  @Prop memberCount: number = 0;
  @Prop joined: boolean = false;
  @Prop @Watch('onVisibleChanged') visible: boolean = false;
  onTakeoff: () => void = (): void => {};
  onOpenFull: () => void = (): void => {};
  onOpenPost: (post: Post) => void = (_post: Post): void => {};
  // 加入态变更回报父页面（父页面统一维护 circles 数据与 membershipVersion 广播）
  onJoinChanged: (joined: boolean) => void = (_joined: boolean): void => {};

  @State posts: Post[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State joining: boolean = false;
  @State joinedNow: boolean = false;
  @State igniteScale: number = 1;
  @State igniteOpacity: number = 1;
  private listVersion: number = 0;

  aboutToAppear(): void {
    this.joinedNow = this.joined;
    if (this.visible && this.circleName.length > 0) {
      this.refresh();
    }
  }

  onVisibleChanged(): void {
    if (this.visible) {
      this.joinedNow = this.joined;
      this.refresh();
    }
  }

  private async refresh(): Promise<void> {
    const version: number = this.listVersion + 1;
    this.listVersion = version;
    this.loading = true;
    this.error = '';
    try {
      const result = await listPosts({ page: 1, limit: 6, sort: 'latest', tag: this.circleName });
      if (version !== this.listVersion) {
        return;
      }
      this.posts = result.list;
    } catch (e) {
      if (version === this.listVersion) {
        this.error = (e as Error).message;
      }
    } finally {
      if (version === this.listVersion) {
        this.loading = false;
      }
    }
  }

  // 加入/退出：登录门禁复用现有模式；成功后播放行星点亮编舞并回报父页面。
  private async toggleJoin(): Promise<void> {
    if (this.joining || this.circleName.length === 0) {
      return;
    }
    if (getToken() === '') {
      safeShowToast(this.getUIContext(), { message: '请先登录后再加入圈子' });
      return;
    }
    const wasJoined: boolean = this.joinedNow;
    this.joining = true;
    this.joinedNow = !wasJoined;
    try {
      if (wasJoined) {
        await unfollowTag(this.circleName);
      } else {
        await followTag(this.circleName);
        this.playIgnite();
      }
      this.onJoinChanged(!wasJoined);
      safeShowToast(this.getUIContext(), { message: wasJoined ? '已退出圈子' : '已加入圈子 · 新星已点亮' });
    } catch (e) {
      this.joinedNow = wasJoined;
      safeShowToast(this.getUIContext(), { message: '操作失败：' + (e as Error).message });
    } finally {
      this.joining = false;
    }
  }

  // 点亮编舞：图标 scale 0.55→1.38→1 + 透明度回稳（keyframeAnimateTo，仅 transform/opacity）
  private playIgnite(): void {
    this.getUIContext().keyframeAnimateTo({ iterations: 1 }, [
      { duration: MotionTokens.fast, curve: MotionCurves.accelerate, event: (): void => { this.igniteScale = 0.55; this.igniteOpacity = 0.3; } },
      { duration: MotionTokens.base, curve: MotionCurves.spring, event: (): void => { this.igniteScale = 1.38; this.igniteOpacity = 1; } },
      { duration: MotionTokens.slow, curve: MotionCurves.springSoft, event: (): void => { this.igniteScale = 1; } },
    ]);
  }

  private timeAgo(iso?: string): string {
    if (iso === undefined || iso.length === 0) {
      return '';
    }
    const t: number = Date.parse(iso);
    if (isNaN(t)) {
      return '';
    }
    const diff: number = Date.now() - t;
    const days: number = Math.floor(diff / 86400000);
    if (days > 0) {
      return days + ' 天前';
    }
    const hours: number = Math.floor(diff / 3600000);
    if (hours > 0) {
      return hours + ' 小时前';
    }
    return '刚刚';
  }

  @Builder
  postRow(post: Post, index: number): void {
    Reveal({ index: index, visible: this.visible }) {
      Row({ space: SpaceTokens.md }) {
        if (post.coverImage !== undefined && post.coverImage.length > 0) {
          Image(post.coverImage)
            .width(74)
            .height(74)
            .borderRadius(RadiusTokens.sm)
            .objectFit(ImageFit.Cover)
        } else {
          Column()
            .width(74)
            .height(74)
            .borderRadius(RadiusTokens.sm)
            .backgroundColor(ColorTokens.subtle)
        }
        Column({ space: SpaceTokens.xs }) {
          Text(post.title ?? '')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.primary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row({ space: SpaceTokens.sm }) {
            Text('@' + (post.user?.nickname ?? '匿名'))
              .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.tertiary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('▲ ' + String(post.upCount ?? 0))
              .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(ColorTokens.brand)
            Text(this.timeAgo(post.createdAt))
              .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.quaternary)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.sm })
      .onClick((): void => { this.onOpenPost(post); })
    }
  }

  build() {
    Column() {
      // 头部
      Column({ space: SpaceTokens.xs }) {
        Row() {
          Text(this.category.length > 0 ? this.category.toUpperCase() + ' · LANDING' : 'LANDING')
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.warm)
            .letterSpacing(2)
          Blank()
          Pressable({
            visualHeight: LayoutTokens.minTouchTarget,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.onTakeoff(); },
          }) {
            Text('‹ 起飞')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(ColorTokens.brand)
              .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
          }
        }
        .width('100%')

        Row({ space: SpaceTokens.sm }) {
          TagIcon({ name: this.circleName, iconSize: IconTokens.standard + 12, tint: ColorTokens.brand })
            .width(44)
            .height(44)
            .scale({ x: this.igniteScale, y: this.igniteScale })
            .opacity(this.igniteOpacity)
          Column({ space: 2 }) {
            Text(this.circleName)
              .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
              .fontWeight(TypeTokens.titleSerif.weight)
              .lineHeight(TypeTokens.titleSerif.lineHeight)
              .fontColor(ColorTokens.primary)
            Text(this.description)
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        Row({ space: SpaceTokens.md }) {
          Button(this.joinedNow ? '✓ 已加入 · 点击退出' : '＋ 加入圈子')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .type(ButtonType.Capsule)
            .controlSize(ControlSize.SMALL)
            .fontSize(TypeTokens.caption.size)
            .fontColor(this.joinedNow ? ColorTokens.warm : ColorTokens.onBrand)
            .backgroundColor(this.joinedNow ? Color.Transparent : ColorTokens.brand)
            .borderWidth(this.joinedNow ? 1 : 0)
            .borderColor(ColorTokens.warm)
            .enabled(!this.joining)
            .onClick((): void => { this.toggleJoin(); })
          Text('进入完整圈子页 ▸')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
            .onClick((): void => { this.onOpenFull(); })
        }
        .width('100%')
        .margin({ top: SpaceTokens.xs })
      }
      .width('100%')
      .padding({ left: SpaceTokens.xl, right: SpaceTokens.xl, top: SpaceTokens.md, bottom: SpaceTokens.md })

      // 帖子流（点灯编舞）
      Scroll() {
        Column() {
          if (this.loading && this.posts.length === 0) {
            LoadingProgress().width(IconTokens.empty).height(IconTokens.empty).margin({ top: SpaceTokens.x3l })
          } else if (this.error.length > 0 && this.posts.length === 0) {
            Text(this.error)
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.tertiary)
              .margin({ top: SpaceTokens.x3l })
          } else if (this.posts.length === 0) {
            Column({ space: SpaceTokens.sm }) {
              Text('🌙').fontSize(28)
              Text('这颗新星还没有帖子\n去发第一帖，点亮它的第一盏灯')
                .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.tertiary)
                .textAlign(TextAlign.Center)
                .lineHeight(20)
            }
            .width('100%')
            .margin({ top: SpaceTokens.x3l })
          } else {
            ForEach(this.posts, (post: Post, index: number) => {
              this.postRow(post, index)
              if (index < this.posts.length - 1) {
                Divider().color(ColorTokens.separator).strokeWidth(0.5)
              }
            }, (post: Post) => String(post.id ?? Math.random()))
          }
        }
        .width('100%')
        .padding({ left: SpaceTokens.xl, right: SpaceTokens.xl })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
      .animation({ duration: MotionTokens.page, curve: MotionCurves.emphasized }))
  }
}
