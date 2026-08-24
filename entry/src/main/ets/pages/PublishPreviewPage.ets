import { createPost, resolveDisplayImageUrl } from '../services/api';
import { LengthMetrics } from '@kit.ArkUI';
import { ensureLogin, getUserId } from '../utils/auth';
import { Genre, StructuredData, User } from '../models/types';
import { PublishDraft } from '../utils/publishDraft';
import { savePostDraft, SavedPostDraft } from '../utils/postDraftStore';
import { publishFlowStore } from '../utils/publishFlowStore';
import { uploadTextPoster, layoutPosterText, PosterTextItem, resolveTextPosterStyle, TEXT_POSTER_ASPECT_RATIO, TEXT_POSTER_STYLES, TextPosterStyleOption } from '../utils/textPoster';
import { image } from '@kit.ImageKit';
import { safeShowToast } from '../utils/toast';
import { VideoPlayer } from '../components/VideoPlayer';
import { GlassPanel } from '../design/components/GlassPanel';
import { BackButton } from '../design/components/BackButton';
import { DesignButton } from '../design/components/DesignButton';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { withCoverOnlyTextPoster } from '../utils/structuredFields';
import { FALLBACK_VIDEO_ASPECT_RATIO, normalizeVideoAspectRatio } from '../utils/video';

const TEXT_POSTER_TIMEOUT: number = 20000;

type FieldDef = [keyof StructuredData, string];
type PreviewField = [string, string];

function genreLabel(genre: Genre): string {
  switch (genre) {
    case 'pitfall': return '避坑';
    case 'tutorial': return '教程';
    case 'debate': return '辩论';
    case 'share': return '分享';
    default: return '测评';
  }
}

function genreFieldDefs(genre: Genre): FieldDef[] {
  switch (genre) {
    case 'review': return [['pros', '优点'], ['cons', '缺点'], ['rating', '推荐指数'], ['targetAudience', '适合人群']];
    case 'pitfall': return [['pitfallExperience', '踩坑经历'], ['lossAmount', '损失金额'], ['correctApproach', '正确做法']];
    case 'tutorial': return [['tools', '准备工具'], ['steps', '步骤拆解'], ['timeDifficulty', '耗时/难度']];
    case 'debate': return [['planA', '方案 A'], ['planB', '方案 B']];
    default: return [];
  }
}

function readField(sd: StructuredData, key: keyof StructuredData): string | number | undefined {
  switch (key) {
    case 'pros': return sd.pros;
    case 'cons': return sd.cons;
    case 'rating': return sd.rating;
    case 'targetAudience': return sd.targetAudience;
    case 'pitfallExperience': return sd.pitfallExperience;
    case 'lossAmount': return sd.lossAmount;
    case 'correctApproach': return sd.correctApproach;
    case 'tools': return sd.tools;
    case 'steps': return sd.steps;
    case 'timeDifficulty': return sd.timeDifficulty;
    case 'planA': return sd.planA;
    case 'planB': return sd.planB;
    default: return undefined;
  }
}

@Entry
@Component
struct PublishPreviewPage {
  @State draft: PublishDraft | null = null;
  @State textPosterStyleIndex: number = 0;
  @State previewImageIndex: number = 0;
  @State publishing: boolean = false;
  @State error: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.draft = publishFlowStore.getSession().previewDraft;
    if (this.draft === null) {
      this.error = '草稿已失效，请返回编辑页重新预览';
    } else {
      this.textPosterStyleIndex = this.posterStyleIndex(this.draft.textPosterStyle);
      this.previewImageIndex = 0;
    }
  }

  private currentDraft(): PublishDraft {
    return this.draft ?? {
      mode: 'photo', title: '', content: '', genre: 'share', tags: [], structuredData: {}, images: [], videoUrl: '', videoCover: '', videoAspectRatio: FALLBACK_VIDEO_ASPECT_RATIO,
    };
  }

  private hasPreviewVideo(): boolean {
    const videoUrl: string = this.currentDraft().videoUrl ?? '';
    return videoUrl.length > 0;
  }

  private previewFields(): PreviewField[] {
    const draft: PublishDraft = this.currentDraft();
    const rows: PreviewField[] = [];
    for (const field of genreFieldDefs(draft.genre)) {
      const value: string | number | undefined = readField(draft.structuredData, field[0]);
      if (value !== undefined && String(value).length > 0) {
        rows.push([field[1], String(value)]);
      }
    }
    return rows;
  }

  // 用「已注册的 UI 宋体 Text + 截图」生成文字覆盖层。
  // 使用实心背景(#FAF7EF 素纸色)替代透明背景，确保 componentSnapshot 渲染后文字深黑不褪色。
  // 采用三层渲染：阴影层 + 高光层 + 主文字层，增强立体感。
  @Builder
  posterOverlayBuilder(items: PosterTextItem[]) {
    Stack() {
      // 阴影层：向右下偏移 4vp 的半透明黑色(#8C000000)
      ForEach(items, (it: PosterTextItem) => {
        Text(it.text)
          .fontSize(it.size)
          .fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(it.weight)
          .fontColor('#8C000000')
          .position({ x: it.x + 4, y: it.y + 6 })
      }, (it: PosterTextItem) => 'shadow_' + it.text + '_' + it.x + '_' + it.y)
      // 高光层：向左上偏移 2vp 的白色(#50FFFFFF)
      ForEach(items, (it: PosterTextItem) => {
        Text(it.text)
          .fontSize(it.size)
          .fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(it.weight)
          .fontColor('#50FFFFFF')
          .position({ x: it.x - 2, y: it.y - 2 })
      }, (it: PosterTextItem) => 'highlight_' + it.text + '_' + it.x + '_' + it.y)
      // 主文字层：纯色文字
      ForEach(items, (it: PosterTextItem) => {
        Text(it.text)
          .fontSize(it.size)
          .fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(it.weight)
          .fontColor(it.color)
          .position({ x: it.x, y: it.y })
      }, (it: PosterTextItem) => 'main_' + it.text + '_' + it.x + '_' + it.y)
    }
    .width(1080)
    .height(1440)
    .backgroundColor('#FAF7EF') // 素纸色背景，保证文字清晰渲染
  }

  private async buildPosterOverlay(draft: PublishDraft): Promise<image.PixelMap | undefined> {
    // componentSnapshot 会导致文字颜色失真，已改为 canvas 直接绘制
    return undefined;
  }

  private uploadTextPosterWithTimeout(draft: PublishDraft): Promise<string> {
    return new Promise<string>((resolve: (url: string) => void, reject: (reason: Error) => void): void => {
      let settled: boolean = false;
      let timer: number = 0;
      const finish = (error?: Error, url?: string): void => {
        if (settled) {
          return;
        }
        settled = true;
        clearTimeout(timer);
        if (error !== undefined) {
          reject(error);
        } else {
          resolve(url ?? '');
        }
      };
      timer = setTimeout((): void => {
        finish(new Error('文字海报生成超时'));
      }, TEXT_POSTER_TIMEOUT) as number;
      this.buildPosterOverlay(draft)
        .then((overlay: image.PixelMap | undefined) => uploadTextPoster(draft.title, draft.content, draft.genre, draft.textPosterStyle, overlay))
        .then((url: string): void => { finish(undefined, url); })
        .catch((e: Error): void => { finish(e); });
    });
  }

  private async publish(): Promise<void> {
    if (this.publishing || this.draft === null) {
      return;
    }
    let user: User | null = null;
    try {
      user = await ensureLogin();
    } catch (e) {
      const message: string = e instanceof Error && e.message.length > 0 ? e.message : '未知错误';
      safeShowToast(this.getUIContext(), { message: '登录失败：' + message });
      return;
    }
    if (user === null) {
      return;
    }
    this.publishing = true;
    const draft: PublishDraft = this.currentDraft();
    try {
      let images: string[] = draft.images;
      let coverImage: string | undefined = images.length > 0 ? images[0] : undefined;
      const coverOnlyTextPoster: boolean = draft.mode === 'photo' && images.length === 0;
      let videoUrl: string | undefined;
      let videoCover: string | undefined;
      let videoAspectRatio: number | undefined;
      if (draft.videoUrl && draft.videoUrl.length > 0) {
        // 视频模式：不生成文字海报，封面取首帧抓图
        videoUrl = draft.videoUrl;
        videoCover = draft.videoCover;
        videoAspectRatio = normalizeVideoAspectRatio(draft.videoAspectRatio ?? FALLBACK_VIDEO_ASPECT_RATIO);
        images = [];
      } else if (images.length === 0) {
        safeShowToast(this.getUIContext(), { message: '正在生成文字海报…' });
        try {
          const posterUrl: string = await this.uploadTextPosterWithTimeout(draft);
          if (posterUrl.length === 0) {
            throw new Error('文字海报地址为空');
          }
          // The generated poster is an information-flow cover, not detail media.
          coverImage = posterUrl;
        } catch (e) {
          const message: string = e instanceof Error && e.message.length > 0 ? e.message : '未知错误';
          safeShowToast(this.getUIContext(), { message: '文字海报失败，已按纯文字发布：' + message });
        }
      }
      const post = await createPost({
        title: draft.title,
        publishMode: draft.mode,
        content: draft.content,
        genre: draft.genre,
        tags: draft.tags,
        structuredData: withCoverOnlyTextPoster(draft.structuredData, coverOnlyTextPoster),
        images: images,
        videoUrl: videoUrl,
        videoCover: videoCover,
        videoAspectRatio: videoAspectRatio,
        coverImage: videoCover && videoCover.length > 0 ? videoCover : coverImage,
      });
      publishFlowStore.completePublish();
      safeShowToast(this.getUIContext(), { message: '发布成功！帖子ID=' + (post.id ?? '') });
      this.getUIContext().getRouter().back();
    } catch (e) {
      const message: string = e instanceof Error && e.message.length > 0 ? e.message : '未知错误';
      safeShowToast(this.getUIContext(), { message: '发布失败：' + message });
    } finally {
      this.publishing = false;
    }
  }

  private saveCurrentDraft(): void {
    if (this.draft === null) {
      return;
    }
    const draft: PublishDraft = this.currentDraft();
    const savedDraftId: string = publishFlowStore.getSession().activeDraftId;
    const saved: SavedPostDraft = savePostDraft(getUserId(), draft, savedDraftId);
    publishFlowStore.setActiveDraftId(saved.id);
    safeShowToast(this.getUIContext(), { message: '草稿已保存' });
  }

  private posterStyleIndex(styleKey?: string): number {
    for (let i = 0; i < TEXT_POSTER_STYLES.length; i++) {
      if (TEXT_POSTER_STYLES[i].key === styleKey) {
        return i;
      }
    }
    return 0;
  }

  private selectTextPosterStyle(index: number): void {
    if (this.draft === null || this.draft.images.length > 0
      || (this.draft.videoUrl !== undefined && this.draft.videoUrl.length > 0)
      || index < 0 || index >= TEXT_POSTER_STYLES.length) {
      return;
    }
    const style: TextPosterStyleOption = TEXT_POSTER_STYLES[index];
    const current: PublishDraft = this.draft;
    const next: PublishDraft = {
      mode: current.mode,
      title: current.title,
      content: current.content,
      genre: current.genre,
      tags: current.tags,
      structuredData: current.structuredData,
      images: current.images,
      textPosterStyle: style.key,
    };
    this.textPosterStyleIndex = index;
    this.draft = next;
    publishFlowStore.updatePreview(next);
  }

  @Builder
  topBar(): void {
    Row({ space: SpaceTokens.sm }) {
      BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
      Text('发布预览')
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(TypeTokens.headline.lineHeight)
        .fontColor(ColorTokens.primary)
      Text('返回编辑可继续修改')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.caption.weight)
        .lineHeight(TypeTokens.caption.lineHeight)
        .fontColor(ColorTokens.secondary)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(LayoutTokens.minTouchTarget)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  textPosterPreview(draft: PublishDraft, style: TextPosterStyleOption): void {
    Stack({ alignContent: Alignment.Center }) {
      // 预览与端侧绘制器保持同一层级：底色、材质、正文，而不是一个纯色占位卡片。
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(style.background)
      Column()
        .width(style.texture === 'sticky' ? '88%' : '88%')
        .height(style.texture === 'sticky' ? '86%' : '90%')
        .backgroundColor(style.surface)
        .borderRadius(style.texture === 'sticky' ? RadiusTokens.sm : RadiusTokens.lg)
        .shadow({ radius: 10, color: '#26000000', offsetY: 6 });
      Column()
        .width(style.texture === 'film' ? '78%' : '84%')
        .height(style.texture === 'sticky' ? '80%' : '84%')
        .backgroundColor(style.innerSurface)
        .borderRadius(RadiusTokens.md);
      if (style.texture === 'film') {
        Row() {
          Column({ space: 12 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7], (leftHole: number, leftIndex: number) => {
              Circle().width(10).height(10).fill('#CC202832')
            }, (leftKey: number, leftKeyIndex: number) => 'film-left-' + leftKeyIndex)
          }
          Column({ space: 12 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7], (rightHole: number, rightIndex: number) => {
              Circle().width(10).height(10).fill('#CC202832')
            }, (rightKey: number, rightKeyIndex: number) => 'film-right-' + rightKeyIndex)
          }
        }
        .width('88%')
        .height('78%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      if (style.texture === 'kraft') {
        Column({ space: 10 }) {
          ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], (grainRow: number, grainRowIndex: number) => {
            Row({ space: 24 }) {
              ForEach([0, 1, 2, 3, 4, 5], (grainDot: number, grainDotIndex: number) => {
                Circle().width(3).height(3).fill('#552E1E')
              }, (grainDotKey: number, grainDotKeyIndex: number) => 'kraft-dot-' + grainRowIndex + '-' + grainDotKeyIndex)
            }
          }, (grainKey: number, grainKeyIndex: number) => 'kraft-row-' + grainKeyIndex)
        }
        .width('74%')
        .height('72%')
        .opacity(0.28)
      }
      if (style.texture === 'sticky') {
        Column()
          .width('26%')
          .height(12)
          .backgroundColor('#A8FFFFFF')
          .position({ x: 150, y: 18 })
      }
      Column({ space: SpaceTokens.sm }) {
        Text(draft.title.trim().length > 0 ? draft.title.trim() : '有据 · 文字帖')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(style.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('78%')
          .textAlign(TextAlign.Center)
          .opacity(0.72)
        Text('“')
          .fontSize(56).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.display.weight)
          .fontColor(style.accent)
          .height(52)
          .alignSelf(ItemAlign.Start);
        Text(draft.content.trim().length > 0 ? draft.content.trim() : '写下你的观点，让更多人看见。')
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .fontColor(style.text)
          .maxLines(6)
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('88%');
        Text('”')
          .fontSize(56).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.display.weight)
          .fontColor(style.accent)
          .height(52)
          .alignSelf(ItemAlign.End);
        Column()
          .width('92%')
          .height(4)
          .backgroundColor(style.accent)
          .borderRadius(RadiusTokens.pill)
          .margin({ top: SpaceTokens.sm });
      }
        .width('76%')
      .height('86%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .borderRadius(style.texture === 'film' ? RadiusTokens.sm : RadiusTokens.md)
    .clip(true)
  }

  @Builder
  coverPreview(draft: PublishDraft): void {
    if (draft.videoUrl && draft.videoUrl.length > 0) {
      Stack({ alignContent: Alignment.Center }) {
        VideoPlayer({ src: draft.videoUrl, poster: draft.videoCover })
      }
      .width('100%')
      .aspectRatio(normalizeVideoAspectRatio(draft.videoAspectRatio ?? FALLBACK_VIDEO_ASPECT_RATIO))
      .backgroundColor(ColorTokens.sunken)
      .borderRadius(RadiusTokens.md)
      .clip(true)
    } else if (draft.images.length > 0) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Swiper() {
          ForEach(draft.images, (url: string) => {
            Image(resolveDisplayImageUrl(url))
              .width('100%')
              .height('100%')
              // 与信息流卡片封面一致：固定 3:4 容器 + Cover 裁切填满（长图不再缩小失调）
              .objectFit(ImageFit.Cover)
              .backgroundColor(ColorTokens.sunken)
          }, (url: string) => url)
        }
        .width('100%')
        .height('100%')
        .indicator(false)
        .loop(false)
        .onChange((index: number): void => { this.previewImageIndex = index; })

        if (draft.images.length > 1) {
          Text((this.previewImageIndex + 1) + ' / ' + draft.images.length)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(Color.White)
            .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
            .backgroundColor('#99000000')
            .borderRadius(RadiusTokens.pill)
            .margin({ right: SpaceTokens.sm, bottom: SpaceTokens.sm })
        }
      }
        .width('100%')
        .aspectRatio(LayoutTokens.cardMediaAspectRatio)
        .backgroundColor(ColorTokens.sunken)
        .borderRadius(RadiusTokens.md)
        .clip(true)
    } else {
      Swiper() {
        ForEach(TEXT_POSTER_STYLES, (style: TextPosterStyleOption) => {
          this.textPosterPreview(draft, style)
        }, (style: TextPosterStyleOption) => style.key)
      }
      .width('100%')
      .aspectRatio(TEXT_POSTER_ASPECT_RATIO)
      .indicator(true)
      .loop(false)
      .index(this.textPosterStyleIndex)
      .onChange((index: number): void => { this.selectTextPosterStyle(index); })
      .borderRadius(RadiusTokens.md)
      .clip(true)
    }
  }

  @Builder
  videoPreview(draft: PublishDraft): void {
    VideoPlayer({ src: draft.videoUrl ?? '', poster: draft.videoCover ?? '' })
      .width('100%')
      .aspectRatio(normalizeVideoAspectRatio(draft.videoAspectRatio ?? FALLBACK_VIDEO_ASPECT_RATIO))
      .backgroundColor(Color.Black)
  }

  @Builder
  postPreview(draft: PublishDraft): void {
    GlassPanel({ panelPadding: SpaceTokens.md, radius: RadiusTokens.lg }) {
      Column({ space: SpaceTokens.md }) {
        if (!draft.videoUrl || draft.videoUrl.length === 0) {
          this.coverPreview(draft)
        }
        Row({ space: SpaceTokens.sm }) {
          Text(genreLabel(draft.genre))
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .fontColor(ColorTokens.brand)
            .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
            .backgroundColor(ColorTokens.brandTint)
            .borderRadius(RadiusTokens.sm)
          if (draft.videoUrl && draft.videoUrl.length > 0) {
            Text('含视频')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
          }
          if (draft.images.length > 1) {
            Text('含 ' + draft.images.length + ' 张图片')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
          }
        }
        Text(draft.title)
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .fontColor(ColorTokens.primary)
        if (draft.content.trim().length > 0) {
          Text(draft.content)
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.body.weight)
            .lineHeight(TypeTokens.body.lineHeight)
            .fontColor(ColorTokens.secondary)
            .maxLines(8)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (draft.tags.length > 0) {
          Flex({
            wrap: FlexWrap.Wrap,
            space: { main: LengthMetrics.px(SpaceTokens.inline), cross: LengthMetrics.px(SpaceTokens.inline) },
          }) {
            ForEach(draft.tags, (tag: string) => {
              Text('# ' + tag)
                .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.caption.weight)
                .lineHeight(TypeTokens.caption.lineHeight)
                .fontColor(ColorTokens.brand)
                .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.inlineTight, bottom: SpaceTokens.inlineTight })
                .backgroundColor(ColorTokens.subtle)
                .borderRadius(RadiusTokens.sm)
            }, (tag: string) => tag)
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  structuredPreview(): void {
    if (this.previewFields().length > 0) {
      GlassPanel({ panelPadding: SpaceTokens.md, radius: RadiusTokens.md }) {
        Column({ space: SpaceTokens.sm }) {
          Text('结构化补充')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.primary)
          ForEach(this.previewFields(), (row: PreviewField) => {
            Row({ space: SpaceTokens.md }) {
              Text(row[0])
                .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.caption.weight)
                .lineHeight(TypeTokens.caption.lineHeight)
                .fontColor(ColorTokens.secondary)
                .width(88)
              Text(row[1])
                .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.callout.weight)
                .lineHeight(TypeTokens.callout.lineHeight)
                .fontColor(ColorTokens.primary)
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }, (row: PreviewField) => row[0])
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
  }

  build() {
    Column({ space: SpaceTokens.md }) {
      Column() {
        this.topBar()
      }
      .width('100%')
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      if (this.draft !== null) {
        Scroll() {
          Column({ space: SpaceTokens.md }) {
            if (this.hasPreviewVideo()) {
              this.videoPreview(this.currentDraft())
            }
            Column({ space: SpaceTokens.md }) {
              this.postPreview(this.currentDraft())
              this.structuredPreview()
              Row().height(LayoutTokens.minTouchTarget).width('100%')
            }
            .width('100%')
            .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        Row({ space: SpaceTokens.sm }) {
          DesignButton({
            label: '存草稿',
            variant: 'glass',
            fillWidth: true,
            disabled: this.publishing,
            action: (): void => { this.saveCurrentDraft(); },
          })
          .layoutWeight(1)
          DesignButton({
            label: this.publishing ? '发布中' : '确认发布',
            variant: 'glass',
            fillWidth: true,
            disabled: this.publishing,
            action: (): void => { this.publish(); },
          })
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
        .alignItems(VerticalAlign.Center)
      } else {
        Column({ space: SpaceTokens.md }) {
          Text(this.error)
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .textAlign(TextAlign.Center)
          DesignButton({ label: '返回编辑', variant: 'ghost', action: (): void => { this.getUIContext().getRouter().back(); } })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarHeight + SpaceTokens.sm, bottom: SpaceTokens.md })
    .backgroundColor(ColorTokens.canvas)
  }
}
