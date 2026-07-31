import { Post, User } from '../models/types';
import { upPost, cancelUpPost } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { likeStore } from '../utils/likeStore';
import { Avatar } from '../design/components/Avatar';
import { BaseCard } from '../design/components/BaseCard';
import { PollBlock } from '../design/components/PollBlock';
import { StatRow } from '../design/components/StatRow';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct PostCard {
  @Prop post: Post = {};
  // 首页信息流以更高的信息密度呈现；个人页等场景维持默认尺寸。
  @Prop compact: boolean = false;

  onOpen?: () => void = undefined;
  onCancelBookmark?: (id: number) => void = undefined;

  @State liked: boolean = false;
  @State likeCount: number = 0;
  private unsubLike: () => void = () => {};

  aboutToAppear(): void {
    const id: number | undefined = this.postId();
    if (id !== undefined) {
      // 从全局点赞仓库注册并读取（保证与详情页/个人主页同帖一致）
      likeStore.ensure(id, this.post.myUp ?? false, this.post.upCount ?? 0);
      const info = likeStore.get(id);
      if (info) {
        this.liked = info.liked;
        this.likeCount = info.count;
      }
      // 订阅该帖点赞态变化：首页点赞后，详情/个人主页的同帖会即时同步
      this.unsubLike = likeStore.subscribe((changedId: number): void => {
        if (changedId === id) {
          const i = likeStore.get(changedId);
          if (i) {
            this.liked = i.liked;
            this.likeCount = i.count;
          }
        }
      });
    } else {
      this.liked = this.post.myUp ?? false;
      this.likeCount = this.post.upCount ?? 0;
    }
  }

  aboutToDisappear(): void {
    this.unsubLike();
  }

  private isDeletedUser(): boolean {
    const u = this.post.user;
    if (u === undefined) {
      return false;
    }
    if (u.deleted === true) {
      return true;
    }
    if (u.nickname === '已注销用户') {
      return true;
    }
    return false;
  }

  private goUser(): void {
    const u: User | undefined = this.post.user;
    if (this.isDeletedUser()) {
      return;
    }
    if (u !== undefined && typeof u.id === 'number') {
      AppStorage.setOrCreate('targetUserId', String(u.id));
      this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
    }
  }

  private openCard(): void {
    if (this.onOpen !== undefined) {
      this.onOpen();
    }
  }

  async onLike(): Promise<void> {
    const id: number | undefined = this.postId();
    if (id === undefined) {
      return;
    }
    const willLike: boolean = !this.liked;
    // 乐观更新写入全局仓库（同步广播到所有展示该帖的组件，含本卡片）
    const prev = likeStore.applyOptimistic(id, willLike);
    try {
      if (willLike) {
        await upPost(id);
      } else {
        await cancelUpPost(id);
      }
    } catch (e) {
      likeStore.revert(id, prev);
      safeShowToast(this.getUIContext(), { message: '操作失败，请先登录' });
    }
  }

  private hasCover(): boolean {
    return this.coverImage().length > 0;
  }

  private hasPoll(): boolean {
    return this.pollPlanA().length > 0 || this.pollPlanB().length > 0;
  }

  private pollPlanA(): string {
    return this.post.structuredData?.planA ?? '';
  }

  private pollPlanB(): string {
    return this.post.structuredData?.planB ?? '';
  }

  private hasAuthor(): boolean {
    return this.post.user !== undefined && typeof this.post.user.id === 'number';
  }

  private authorName(): string {
    if (this.isDeletedUser()) {
      return '已注销用户';
    }
    return this.post.user?.nickname ?? '匿名';
  }

  private authorAvatar(): string {
    if (this.isDeletedUser()) {
      return '';
    }
    return this.post.user?.avatar ?? '';
  }

  private postId(): number | undefined {
    return typeof this.post.id === 'number' ? this.post.id : undefined;
  }

  private coverImage(): string {
    // 后端的无封面字段为 null；接口运行时值需在 UI 边界归一化。
    return typeof this.post.coverImage === 'string' ? this.post.coverImage : '';
  }

  @Builder
  mediaSlot(): void {
    if (this.hasCover()) {
      Image(this.coverImage())
        .width('100%')
        .aspectRatio(this.compact ? 1.28 : LayoutTokens.cardMediaAspectRatio)
        .objectFit(ImageFit.Cover)
        .borderRadius(RadiusTokens.xs)
        .clip(true)
    }
    // 无图状态按冻结后的卡片尺寸收紧媒体槽，不注入额外占位高度。
  }

  @Builder
  titleSlot(): void {
    // design tokens: type.headline / color.primary。
    Text(this.post.title ?? '')
      .fontSize(this.compact ? TypeTokens.body.size : TypeTokens.headline.size)
      .fontWeight(TypeTokens.headline.weight)
      .lineHeight(this.compact ? 20 : TypeTokens.headline.lineHeight)
      .letterSpacing(TypeTokens.headline.tracking)
      .fontColor(ColorTokens.primary)
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  pollSlot(): void {
    if (this.hasPoll()) {
      PollBlock({
        planA: this.pollPlanA(),
        planB: this.pollPlanB(),
        compact: this.compact,
      })
    }
  }

  @Builder
  statSlot(): void {
    StatRow({
      liked: this.liked,
      likeCount: this.likeCount,
      commentCount: this.post.commentCount ?? 0,
      showComment: false,
      compact: this.compact,
      onLike: () => { this.onLike(); },
    })
  }

  // 卡片底部采用单行布局：互动数据靠左，作者信息靠右，避免作者独占一整行。
  @Builder
  footerSlot(): void {
    Row() {
      this.statSlot()
      Blank().layoutWeight(1)
      if (this.hasAuthor()) {
        Pressable({
          visualHeight: IconTokens.compact,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => { this.goUser(); },
        }) {
          Row({ space: SpaceTokens.inlineTight }) {
            Avatar({
              avatar: this.authorAvatar(),
              name: this.authorName(),
              avatarSize: this.compact ? 20 : IconTokens.avatarCompact,
            })
            Text(this.authorName())
              .fontSize(this.compact ? TypeTokens.overline.size : TypeTokens.caption.size)
              .fontWeight(TypeTokens.caption.weight)
              .lineHeight(TypeTokens.caption.lineHeight)
              .letterSpacing(TypeTokens.caption.tracking)
              .fontColor(ColorTokens.secondary)
              .constraintSize({ maxWidth: this.compact ? 88 : 132 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(VerticalAlign.Center)
        }
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  cancelBookmarkSlot(): void {
    if (this.onCancelBookmark !== undefined) {
      Pressable({
        action: () => {
          const id: number | undefined = this.postId();
          if (id !== undefined) {
            this.onCancelBookmark!(id);
          }
        },
        visualHeight: TypeTokens.caption.lineHeight,
      }) {
        Row() {
          Text('取消收藏')
            .fontSize(TypeTokens.caption.size)
            .fontWeight(TypeTokens.caption.weight)
            .fontColor(ColorTokens.secondary)
        }
        .alignItems(VerticalAlign.Center)
      }
    }
  }

  build() {
    // design tokens: color.elevated / radius.lg / space.base / shadow.card。
    BaseCard({
      cardPadding: this.compact ? SpaceTokens.sm : SpaceTokens.base,
      radius: this.compact ? RadiusTokens.sm : RadiusTokens.lg,
      elevation: 1,
      pressable: this.onOpen !== undefined,
      action: () => { this.openCard(); },
    }) {
      Column({ space: this.compact ? SpaceTokens.xs : SpaceTokens.item }) {
        this.mediaSlot()
        this.titleSlot()
        this.pollSlot()
        this.footerSlot()
        this.cancelBookmarkSlot()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
