import { Post } from '../models/types';
import { upPost, cancelUpPost } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { likeStore } from '../utils/likeStore';
import { StatRow } from '../design/components/StatRow';
import { PostCardAuthor } from './PostCardAuthor';
import { PostCardMedia } from './PostCardMedia';
import { PostCardTitle } from './PostCardTitle';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { openUserProfile } from '../utils/nav';

@Component
export struct PostCard {
  @Prop post: Post = {};
  // 首页信息流以更高的信息密度呈现；个人页等场景维持默认尺寸。
  @Prop compact: boolean = false;
  // 所有帖子列表共用同一张信息流卡片；管理页可保留统计展示但关闭点赞写操作。
  @Prop variant: 'feed' | 'draft' | 'preview' = 'feed';
  @Prop allowLike: boolean = true;
  @Prop showStats: boolean = true;
  @Prop showAuthor: boolean = true;

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
    const authorId: number | undefined = this.authorId();
    if (this.isDeletedUser()) {
      return;
    }
    if (authorId !== undefined) {
      openUserProfile(authorId);
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
    return this.coverImage().length > 0 || (this.post.videoUrl ?? '').length > 0;
  }

  private hasAuthor(): boolean {
    return this.authorId() !== undefined;
  }

  private hasFooter(): boolean {
    return this.showStats || (this.showAuthor && this.hasAuthor()) || this.onCancelBookmark !== undefined;
  }

  private authorId(): number | undefined {
    if (typeof this.post.user?.id === 'number') {
      return this.post.user.id;
    }
    return typeof this.post.userId === 'number' ? this.post.userId : undefined;
  }

  private authorName(): string {
    if (this.isDeletedUser()) {
      return '已注销用户';
    }
    return this.post.user?.nickname ?? (this.authorId() !== undefined ? '贴主' : '匿名');
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
  statSlot(): void {
    StatRow({
      liked: this.liked,
      likeCount: this.likeCount,
      commentCount: this.post.commentCount ?? 0,
      showComment: false,
      compact: this.compact,
      onLike: this.allowLike ? (): void => { this.onLike(); } : undefined,
    })
  }

  // 互动面是与内容面紧贴拼接的独立区域，不再嵌套在正文卡片内。
  @Builder
  footerSlot(): void {
    Column({ space: SpaceTokens.inlineTight }) {
      Row() {
        if (this.showStats) {
          this.statSlot()
        }
        Blank().layoutWeight(1)
        if (this.showAuthor && this.hasAuthor()) {
          PostCardAuthor({
            name: this.authorName(),
            avatar: this.authorAvatar(),
            compact: this.compact,
            onOpen: (): void => { this.goUser(); },
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.cancelBookmarkSlot()
    }
    .width('100%')
    .padding({
      left: this.compact ? SpaceTokens.xs : SpaceTokens.sm,
      right: this.compact ? SpaceTokens.xs : SpaceTokens.sm,
      top: SpaceTokens.inlineTight,
      bottom: SpaceTokens.inlineTight,
    })
    .backgroundColor(ColorTokens.elevated)
    // 互动栏与标题区保持同一张纸，只用两侧和底部的细分隔线收口。
    .border({
      width: {
        left: 1,
        right: 1,
        bottom: 1,
        top: 0,
      },
      color: ColorTokens.separator,
      style: BorderStyle.Solid,
    })
    .borderRadius({
      topLeft: 0,
      topRight: 0,
      bottomLeft: this.compact ? RadiusTokens.xs : RadiusTokens.lg,
      bottomRight: this.compact ? RadiusTokens.xs : RadiusTokens.lg,
    })
    .clip(true)
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
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.caption.weight)
            .fontColor(ColorTokens.secondary)
        }
        .alignItems(VerticalAlign.Center)
      }
    }
  }

  build() {
    // 三层结构：封面图（上传图或文字海报）→ 标题 → 玻璃互动/作者栏。
    Pressable({
      fillWidth: true,
      fullResponseRegion: true,
      action: () => { this.openCard(); },
    }) {
      Column({ space: SpaceTokens.none }) {
        PostCardMedia({
          imageUrl: this.coverImage(),
          videoUrl: this.post.videoUrl ?? '',
          videoCover: this.post.videoCover ?? '',
          compact: this.compact,
        })
        PostCardTitle({ title: this.post.title ?? '', hasMedia: this.hasCover(), compact: this.compact })
        if (this.variant === 'feed' && this.hasFooter()) {
          this.footerSlot()
        }
      }
      .width('100%')
      .shadow({ radius: 12, color: ColorTokens.barShadow, offsetY: 4 })
    }
  }
}
