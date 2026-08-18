import { getCurrentUser, getUserId } from '../utils/auth';
import { removePostDraft, listPostDrafts, SavedPostDraft, subscribePostDrafts } from '../utils/postDraftStore';
import { Post } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { BackButton } from '../design/components/BackButton';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { publishFlowStore } from '../utils/publishFlowStore';
import { PublishMode } from '../components/PublishModeSheet';
import { PostCard } from '../components/PostCard';

@Entry
@Component
struct DraftBoxPage {
  @State drafts: SavedPostDraft[] = [];
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  private unsubscribeDrafts: () => void = () => {};

  aboutToAppear(): void {
    this.unsubscribeDrafts();
    this.unsubscribeDrafts = subscribePostDrafts((): void => { this.reload(); });
    this.reload();
  }

  aboutToDisappear(): void {
    this.unsubscribeDrafts();
    this.unsubscribeDrafts = () => {};
  }

  private reload(): void {
    this.drafts = listPostDrafts(getUserId());
  }

  private continueEdit(draft: SavedPostDraft): void {
    publishFlowStore.editSavedDraft(draft.id, draft);
    const mode: PublishMode = draft.mode ?? ((draft.videoUrl !== undefined && draft.videoUrl.length > 0) ? 'video'
      : (draft.images.length === 0 ? 'text' : 'photo'));
    const url: string = mode === 'video' ? 'pages/VideoPublishPage'
      : (mode === 'text' ? 'pages/TextPublishPage' : 'pages/PhotoPublishPage');
    this.getUIContext().getRouter().pushUrl({ url: url });
  }

  private remove(draft: SavedPostDraft): void {
    this.getUIContext().showAlertDialog({
      title: '删除草稿',
      message: '确定删除“' + (draft.title.length > 0 ? draft.title : '未命名草稿') + '”吗？',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '删除',
        fontColor: ColorTokens.danger,
        action: (): void => {
          removePostDraft(getUserId(), draft.id);
          safeShowToast(this.getUIContext(), { message: '草稿已删除' });
        },
      },
    });
  }

  private postForDraft(draft: SavedPostDraft): Post {
    const videoUrl: string = draft.videoUrl ?? '';
    const videoCover: string = draft.videoCover ?? '';
    const imageCover: string = draft.images.length > 0 ? draft.images[0] : '';
    const coverImage: string = videoCover.length > 0 ? videoCover : imageCover;
    return {
      userId: getUserId(),
      title: draft.title.length > 0 ? draft.title : '未命名草稿',
      content: draft.content,
      coverImage: coverImage,
      images: [...draft.images],
      videoUrl: videoUrl,
      videoCover: videoCover,
      videoAspectRatio: draft.videoAspectRatio,
      genre: draft.genre,
      tags: [...draft.tags],
      structuredData: draft.structuredData,
      upCount: 0,
      commentCount: 0,
      user: getCurrentUser() ?? undefined,
    };
  }

  @Builder
  draftActionBar(draft: SavedPostDraft): void {
    Row() {
      Blank().layoutWeight(1)
      Stack({ alignContent: Alignment.Center }) {
        Pressable({
          fillWidth: true,
          visualHeight: IconTokens.small,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => { this.remove(draft); },
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
          .shadow({ radius: 6, color: ColorTokens.shadowSegmented, offsetY: 2 })
          .alignSelf(ItemAlign.Center)
        }
      }
      .width(LayoutTokens.minTouchTarget)
      .height(IconTokens.small)
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
  draftItem(draft: SavedPostDraft): void {
    Column({ space: SpaceTokens.none }) {
      Stack() {
        PostCard({
          post: this.postForDraft(draft),
          compact: true,
          allowLike: false,
          showStats: false,
          showAuthor: false,
          onOpen: (): void => { this.continueEdit(draft); },
        })
        Text('草稿')
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.primary)
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
          .backgroundColor(ColorTokens.barSurface)
          .backdropBlur(LayoutTokens.glassBlur)
          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.floatingBar)
          .position({ top: SpaceTokens.sm, left: SpaceTokens.sm })
      }
      .width('100%')
      this.draftActionBar(draft)
    }
    .width('100%')
  }

  build() {
    Column({ space: SpaceTokens.md }) {
      Row({ space: SpaceTokens.sm }) {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Text('草稿箱')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .fontColor(ColorTokens.primary)
      }
      .width('100%')
      .height(LayoutTokens.minTouchTarget)
      .alignItems(VerticalAlign.Center)

      if (this.drafts.length === 0) {
        Column({ space: SpaceTokens.sm }) {
          Text('暂无草稿')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.callout.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.secondary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Grid() {
          ForEach(this.drafts, (draft: SavedPostDraft) => {
            GridItem() {
              this.draftItem(draft)
            }
          }, (draft: SavedPostDraft) => draft.id)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(SpaceTokens.sm)
        .rowsGap(SpaceTokens.md)
        .padding({ bottom: SpaceTokens.x3l })
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: this.statusBarHeight + SpaceTokens.sm, bottom: SpaceTokens.md })
    .backgroundColor(ColorTokens.canvas)
  }
}
