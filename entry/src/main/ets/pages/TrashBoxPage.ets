import { Post } from '../models/types';
import { listTrashedPosts, permanentlyDeletePost, restorePost } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { BackButton } from '../design/components/BackButton';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { PostCard } from '../components/PostCard';
import { openPostDetail } from '../utils/nav';

@Entry
@Component
struct TrashBoxPage {
  @State posts: Post[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.reload();
  }

  private async reload(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const result = await listTrashedPosts(1, 50);
      this.posts = result.list;
    } catch (e) {
      this.error = (e as Error).message;
    } finally {
      this.loading = false;
    }
  }

  private postForDisplay(post: Post): Post {
    const images: string[] = post.images ?? [];
    const existingCover: string = post.coverImage ?? '';
    const videoCover: string = post.videoCover ?? '';
    const imageCover: string = images.length > 0 ? images[0] : '';
    const coverImage: string = existingCover.length > 0 ? existingCover
      : (videoCover.length > 0 ? videoCover : imageCover);
    return {
      id: post.id,
      userId: post.userId,
      title: post.title,
      content: post.content,
      coverImage: coverImage,
      videoUrl: post.videoUrl,
      videoCover: post.videoCover,
      videoAspectRatio: post.videoAspectRatio,
      images: images,
      genre: post.genre,
      tags: post.tags,
      structuredData: post.structuredData,
      upCount: post.upCount,
      bookmarkCount: post.bookmarkCount,
      commentCount: post.commentCount,
      myUp: post.myUp,
      myBookmark: post.myBookmark,
      myVote: post.myVote,
      status: post.status,
      deletedAt: post.deletedAt,
      createdAt: post.createdAt,
      user: post.user,
    };
  }

  private restore(post: Post): void {
    if (post.id === undefined) {
      return;
    }
    const id: number = post.id;
    restorePost(id).then((): void => {
      safeShowToast(this.getUIContext(), { message: '帖子已恢复' });
      this.reload();
    }).catch((e: Error): void => {
      safeShowToast(this.getUIContext(), { message: e.message });
    });
  }

  private permanentlyRemove(post: Post): void {
    if (post.id === undefined) {
      return;
    }
    const id: number = post.id;
    this.getUIContext().showAlertDialog({
      title: '彻底删除帖子？',
      message: '彻底删除后无法恢复，帖子相关评论和互动也会被清除。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '彻底删除',
        fontColor: ColorTokens.danger,
        action: (): void => {
          permanentlyDeletePost(id).then((): void => {
            safeShowToast(this.getUIContext(), { message: '帖子已彻底删除' });
            this.reload();
          }).catch((e: Error): void => {
            safeShowToast(this.getUIContext(), { message: e.message });
          });
        },
      },
    });
  }

  @Builder
  trashActionBar(post: Post): void {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Pressable({
          fillWidth: true,
          visualHeight: IconTokens.small,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => { this.restore(post); },
        }) {
          Text('恢复')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.primary)
            .width(48)
            .height(IconTokens.small)
            .textAlign(TextAlign.Center)
            .backgroundColor(ColorTokens.barSelectionSurface)
            .backdropBlur(LayoutTokens.glassBlur)
            .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barSelectionBorder, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.pill)
            .shadow({ radius: 6, color: ColorTokens.shadowSegmented, offsetY: 2 });
        }
      }
      .width(52)
      .height(IconTokens.small);
      Blank().layoutWeight(1);
      Stack({ alignContent: Alignment.Center }) {
        Pressable({
          fillWidth: true,
          visualHeight: IconTokens.small,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => { this.permanentlyRemove(post); },
        }) {
          Row() {
            Image($r('app.media.set_trash'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
              .fillColor(ColorTokens.secondary)
          }
          .width(28)
          .height(IconTokens.small)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(ColorTokens.barSelectionSurface)
          .backdropBlur(LayoutTokens.glassBlur)
          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barSelectionBorder, style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.pill)
          .shadow({ radius: 6, color: ColorTokens.shadowSegmented, offsetY: 2 });
        }
      }
      .width(LayoutTokens.minTouchTarget)
      .height(IconTokens.small);
    }
    .width('100%')
    .padding({
      left: SpaceTokens.xs,
      right: SpaceTokens.xs,
      top: SpaceTokens.inlineTight,
      bottom: SpaceTokens.inlineTight,
    })
    .backgroundColor(ColorTokens.elevated)
    .backdropBlur(LayoutTokens.glassBlur)
    .border({
      width: {
        left: LayoutTokens.glassBorderWidth,
        right: LayoutTokens.glassBorderWidth,
        bottom: LayoutTokens.glassBorderWidth,
        top: 0,
      },
      color: ColorTokens.barBorder,
      style: BorderStyle.Solid,
    })
    .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: RadiusTokens.xs, bottomRight: RadiusTokens.xs })
    .clip(true)
  }

  @Builder
  trashItem(post: Post): void {
    Column({ space: SpaceTokens.none }) {
      Stack() {
        PostCard({
          post: this.postForDisplay(post),
          compact: true,
          allowLike: false,
          showStats: false,
          showAuthor: false,
          onOpen: (): void => { this.openDetail(post); },
        });
        Text('已删除')
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.primary)
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
          .backgroundColor(ColorTokens.barSurface)
          .backdropBlur(LayoutTokens.glassBlur)
          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.floatingBar)
          .position({ top: SpaceTokens.sm, left: SpaceTokens.sm });
      }
      .width('100%');
      this.trashActionBar(post);
    }
    .width('100%')
  }

  private openDetail(post: Post): void {
    if (post.id === undefined) {
      return;
    }
    openPostDetail(post.id.toString());
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
  }

  build() {
    Column({ space: SpaceTokens.md }) {
      Row({ space: SpaceTokens.sm }) {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Text('废纸篓')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .fontColor(ColorTokens.primary);
      }
      .width('100%')
      .height(LayoutTokens.minTouchTarget)
      .alignItems(VerticalAlign.Center);

      if (this.loading) {
        Column() {
          Text('正在加载…')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary);
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else if (this.error.length > 0) {
        Column({ space: SpaceTokens.sm }) {
          Text(this.error)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.danger)
            .textAlign(TextAlign.Center);
          Pressable({ action: (): void => { this.reload(); } }) {
            Text('重新加载')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.primary);
          }
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else if (this.posts.length === 0) {
        Column({ space: SpaceTokens.sm }) {
          Text('废纸篓为空')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.callout.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.secondary);
          Text('删除的帖子会暂存在这里')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary);
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else {
        Grid() {
          ForEach(this.posts, (post: Post) => {
            GridItem() {
              this.trashItem(post);
            }
          }, (post: Post): string => String(post.id ?? ''));
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(SpaceTokens.sm)
        .rowsGap(SpaceTokens.md)
        .padding({ bottom: SpaceTokens.x3l })
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off);
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: this.statusBarHeight + SpaceTokens.sm, bottom: SpaceTokens.md })
    .backgroundColor(ColorTokens.canvas);
  }
}
