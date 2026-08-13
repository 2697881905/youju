import { getUserId } from '../utils/auth';
import { removePostDraft, listPostDrafts, SavedPostDraft, subscribePostDrafts } from '../utils/postDraftStore';
import { resolveDisplayImageUrl } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { BackButton } from '../design/components/BackButton';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { TEXT_POSTER_ASPECT_RATIO, resolveTextPosterStyle, TextPosterStyleOption } from '../utils/textPoster';
import { publishFlowStore } from '../utils/publishFlowStore';
import { PublishMode } from '../components/PublishModeSheet';

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

  private isTextDraft(draft: SavedPostDraft): boolean {
    return (draft.mode ?? (draft.images.length === 0 ? 'text' : 'photo')) === 'text';
  }

  private textPosterStyle(draft: SavedPostDraft): TextPosterStyleOption {
    return resolveTextPosterStyle(draft.textPosterStyle);
  }

  @Builder
  draftTitleBlock(draft: SavedPostDraft): void {
    Column() {
      Text(draft.title.length > 0 ? draft.title : '未命名草稿')
        .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(TypeTokens.body.lineHeight)
        .fontColor(ColorTokens.primary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
    .backgroundColor(ColorTokens.barSurface)
    .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
    .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: RadiusTokens.xs, bottomRight: RadiusTokens.xs });
  }

  @Builder
  textPosterPreview(draft: SavedPostDraft): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('88%')
        .height('90%')
        .backgroundColor(this.textPosterStyle(draft).surface)
        .borderRadius(RadiusTokens.lg)
        .shadow({ radius: 10, color: '#26000000', offsetY: 6 });
      Column()
        .width('84%')
        .height('84%')
        .backgroundColor(this.textPosterStyle(draft).innerSurface)
        .borderRadius(RadiusTokens.md);
      Column({ space: SpaceTokens.sm }) {
        Text('“')
          .fontSize(44).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.display.weight)
          .fontColor(this.textPosterStyle(draft).accent)
          .height(42)
          .alignSelf(ItemAlign.Start);
        Text(draft.content.trim().length > 0 ? draft.content.trim() : '写下你的观点，让更多人看见。')
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .fontColor(this.textPosterStyle(draft).text)
          .maxLines(6)
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('88%');
        Text('”')
          .fontSize(44).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.display.weight)
          .fontColor(this.textPosterStyle(draft).accent)
          .height(42)
          .alignSelf(ItemAlign.End);
        Column()
          .width('92%')
          .height(3)
          .backgroundColor(this.textPosterStyle(draft).accent)
          .borderRadius(RadiusTokens.pill)
          .margin({ top: SpaceTokens.xs });
      }
      .width('76%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .aspectRatio(TEXT_POSTER_ASPECT_RATIO)
    .backgroundColor(this.textPosterStyle(draft).background)
    .borderRadius({
      topLeft: RadiusTokens.xs,
      topRight: RadiusTokens.xs,
      bottomLeft: 0,
      bottomRight: 0,
    })
    .clip(true);
  }

  @Builder
  textDraftCard(draft: SavedPostDraft): void {
    Pressable({
      fillWidth: true,
      fullResponseRegion: true,
      action: (): void => { this.continueEdit(draft); },
    }) {
      Column({ space: SpaceTokens.none }) {
        this.textPosterPreview(draft)
        this.draftTitleBlock(draft)
      }
      .width('100%')
      .shadow({ radius: 18, color: ColorTokens.barShadow, offsetY: 8 });
    }
  }

  @Builder
  imageDraftCard(draft: SavedPostDraft): void {
    Pressable({
      fillWidth: true,
      fullResponseRegion: true,
      action: (): void => { this.continueEdit(draft); },
    }) {
      Column({ space: SpaceTokens.none }) {
        Image(resolveDisplayImageUrl(draft.images[0]))
          .width('100%')
          .aspectRatio(LayoutTokens.cardMediaAspectRatio)
          .objectFit(ImageFit.Contain)
          .backgroundColor(ColorTokens.sunken)
          .borderRadius({ topLeft: RadiusTokens.xs, topRight: RadiusTokens.xs, bottomLeft: 0, bottomRight: 0 })
          .clip(true)
        this.draftTitleBlock(draft)
      }
      .width('100%')
      .shadow({ radius: 18, color: ColorTokens.barShadow, offsetY: 8 });
    }
  }

  @Builder
  draftItem(draft: SavedPostDraft): void {
    Stack() {
      if (this.isTextDraft(draft)) {
        this.textDraftCard(draft)
      } else {
        this.imageDraftCard(draft)
      }
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
      Stack({ alignContent: Alignment.Center }) {
        Pressable({
          fillWidth: true,
          visualHeight: LayoutTokens.minTouchTarget,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => { this.remove(draft); },
        }) {
          Row() {
            Image($r('app.media.set_trash'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
          }
          .width(LayoutTokens.segmentedHeight)
          .height(LayoutTokens.segmentedHeight)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(ColorTokens.barSurface)
          .backdropBlur(LayoutTokens.glassBlur)
          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
          .borderRadius(RadiusTokens.lg)
          .alignSelf(ItemAlign.Center)
        }
      }
      .width(LayoutTokens.minTouchTarget)
      .height(LayoutTokens.minTouchTarget)
      .position({ top: SpaceTokens.xs, right: SpaceTokens.xs })
      .zIndex(2)
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
        .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.x3l })
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
