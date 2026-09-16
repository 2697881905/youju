import { createPost, resolveDisplayImageUrl } from '../services/api';
import { LengthMetrics } from '@kit.ArkUI';
import { ensureLogin, getUserId } from '../utils/auth';
import { Genre, StructuredData, User } from '../models/types';
import { PublishDraft } from '../utils/publishDraft';
import { savePostDraft, SavedPostDraft } from '../utils/postDraftStore';
import { publishFlowStore } from '../utils/publishFlowStore';
import { uploadTextPoster, renderPosterPixelMap, isSerifTypefaceReady, TEXT_POSTER_ASPECT_RATIO, TEXT_POSTER_STYLES, TextPosterStyleOption } from '../utils/textPoster';
import { image } from '@kit.ImageKit';
import { safeShowToast } from '../utils/toast';
import { VideoPlayer } from '../components/VideoPlayer';
import { GlassPanel } from '../design/components/GlassPanel';
import { BackButton } from '../design/components/BackButton';
import { DesignButton } from '../design/components/DesignButton';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { bottomNavInset } from '../utils/cardTokens';
import { TypeTokens } from '../design/tokens/type';
import { withCoverOnlyTextPoster } from '../utils/structuredFields';
import { FALLBACK_VIDEO_ASPECT_RATIO, normalizeVideoAspectRatio } from '../utils/video';

const TEXT_POSTER_TIMEOUT: number = 20000;
// 预览倍率必须恒为 1，不能为省内存调小——这是「预览即发布产物」的前提。
// 尺寸关系（已实测）：预览页海报容器的实际显示宽度约 310vp，在主流 3x 屏上约 930 物理像素；
// 而发布产物本身是 1080×1440，在信息流卡片里同样缩小显示（1080 → 约 930px，缩小约 0.86 倍）。
//   · scale 0.5 → 540×720：930/540 ≈ 放大 1.7 倍，drawGrain 半径仅 1–3 逻辑像素的颗粒、
//     以及正文细笔画会被放大糊掉，明显比发布产物虚；
//   · scale 0.75 → 810×1080：930/810 ≈ 放大 1.15 倍，仍有轻微放大与颗粒损失；
//   · scale 1.0 → 1080×1440：930/1080 ≈ 缩小 0.86 倍，锐利，与发布产物像素级同源、观感一致。
// 即：只有 1.0 才能让预览与发布同为「缩小显示」，否则预览是「放大显示」必然比发布糊，
// 与用户要求的「所见即所得」直接冲突。内存代价见 prepareTextPosterPreviews 注释，仍可接受。
const TEXT_POSTER_PREVIEW_SCALE: number = 1;
// 字体未就绪时的兜底重绘：最多轮询 10 次、每次间隔 200ms（最多 ~2s）。
const TEXT_POSTER_FONT_RETRY_MAX: number = 10;
const TEXT_POSTER_FONT_RETRY_INTERVAL: number = 200;

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
  // 四种文字海报样式的真实渲染产物（由 renderPosterPixelMap 生成），与发布产物同源。
  @State textPosterPixelMaps: image.PixelMap[] = [];
  // 递增版本号：PixelMap 数组为引用类型，替换数组后配合版本号变更可靠触发 @State 刷新。
  @State textPosterRenderVersion: number = 0;
  // 页面销毁标记：防止字体兜底重绘在 aboutToDisappear 之后仍创建 PixelMap 造成内存泄漏。
  private previewDisposed: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.draft = publishFlowStore.getSession().previewDraft;
    if (this.draft === null) {
      this.error = '草稿已失效，请返回编辑页重新预览';
    } else {
      this.textPosterStyleIndex = this.posterStyleIndex(this.draft.textPosterStyle);
      this.previewImageIndex = 0;
      // 仅「无图纯文字帖」会走 coverPreview 的 else 分支展示文字海报；图文帖 / 视频帖跳过预渲染，
      // 避免无谓的 23.7MiB 图形内存占用与 4 次满分辨率主线程栅格化推迟首帧。
      if (this.needsTextPosterPreview(this.draft)) {
        // 首次进入即预渲染全部四种样式，滑动切换零等待。
        this.prepareTextPosterPreviews(this.currentDraft());
        // 字体（Index.ets 启动时注册）尚未就绪时，兜底延迟重绘，避免用默认字体渲染出错误字形。
        if (!isSerifTypefaceReady()) {
          this.retryPreviewsForFont(0);
        }
      }
    }
  }

  aboutToDisappear(): void {
    this.previewDisposed = true;
    this.releaseTextPosterPreviews();
  }

  // 单一事实源：判定草稿是否需要文字海报预览。与 coverPreview 的 else 分支条件严格一致——
  // 仅当「无视频且无图片」（即无图纯文字帖）时，文字海报才会被渲染展示；其余（图文帖 / 视频帖）不需要。
  // 集中在此处，避免 aboutToAppear、字体兜底轮询、prepareTextPosterPreviews 三处条件各写一份后失配。
  private needsTextPosterPreview(draft: PublishDraft): boolean {
    const hasVideo: boolean = draft.videoUrl !== undefined && draft.videoUrl.length > 0;
    return !hasVideo && draft.images.length === 0;
  }

  // 预渲染四种样式的海报 PixelMap。先释放旧图再生成新图，避免重绘时泄漏。
  // 内存代价（scale = 1，RGBA_8888）：单张 1080×1440×4 ≈ 5.93MiB，四张合计 ≈ 23.7MiB。
  // 该量级仅在「发布预览页存活期间」常驻，aboutToDisappear 会 release 全部 PixelMap，
  // 属于可接受的瞬时峰值（远低于现代中端机单进程图形内存预算），故不再为省内存而降低 scale。
  private prepareTextPosterPreviews(draft: PublishDraft): void {
    if (this.previewDisposed) {
      return;
    }
    this.releaseTextPosterPreviews();
    // 兜底防线：图文帖 / 视频帖即便调用方漏判，也绝不创建 PixelMap、不占主线程（零渲染、零内存）。
    if (!this.needsTextPosterPreview(draft)) {
      return;
    }
    const maps: image.PixelMap[] = [];
    for (const style of TEXT_POSTER_STYLES) {
      try {
        maps.push(renderPosterPixelMap(draft.title, draft.content, style.key, TEXT_POSTER_PREVIEW_SCALE));
      } catch {
        // 单一样式渲染失败不阻断其余样式；该样式页回退为纯色占位。
      }
    }
    // 渲染期间页面可能已销毁：此时立即释放刚生成的 PixelMap，避免泄漏。
    if (this.previewDisposed) {
      for (const map of maps) {
        map.release().catch((): void => {});
      }
      return;
    }
    this.textPosterPixelMaps = maps;
    this.textPosterRenderVersion = this.textPosterRenderVersion + 1;
  }

  // 释放当前持有的全部 PixelMap 并清空引用。可重复调用（数组清空后为空循环）。
  private releaseTextPosterPreviews(): void {
    for (const map of this.textPosterPixelMaps) {
      map.release().catch((): void => {});
    }
    if (this.textPosterPixelMaps.length > 0) {
      this.textPosterPixelMaps = [];
    }
  }

  // 字体未就绪时轮询等待，就绪后重绘一次；超过上限则放弃（保持默认字形）。
  private retryPreviewsForFont(attempt: number): void {
    if (this.previewDisposed || attempt >= TEXT_POSTER_FONT_RETRY_MAX) {
      return;
    }
    setTimeout((): void => {
      if (this.previewDisposed || this.draft === null) {
        return;
      }
      // 草稿可能在轮询期间变化：条件不再满足（如已不需文字海报）时立即停止，既不空转也不误重绘。
      if (!this.needsTextPosterPreview(this.currentDraft())) {
        return;
      }
      if (isSerifTypefaceReady()) {
        this.prepareTextPosterPreviews(this.currentDraft());
      } else {
        this.retryPreviewsForFont(attempt + 1);
      }
    }, TEXT_POSTER_FONT_RETRY_INTERVAL) as number;
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
      uploadTextPoster(draft.title, draft.content, draft.genre, draft.textPosterStyle)
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
        mentions: draft.mentions,
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

  // 单页文字海报预览：直接展示 renderPosterPixelMap 的产出，做到「预览即发布产物」。
  // 注意：像素图数组通过 this.textPosterPixelMaps[index] 读取，数组被整体替换时会触发刷新；
  // 同时以 this.textPosterRenderVersion 参与 ForEach key，保证 PixelMap 更新后强制重建。
  @Builder
  textPosterSlide(index: number): void {
    Stack({ alignContent: Alignment.Center }) {
      if (index < this.textPosterPixelMaps.length) {
        Image(this.textPosterPixelMaps[index])
          .width('100%')
          .height('100%')
          // 海报本身即 3:4，与卡片容器一致，Cover 不产生裁切或留白。
          .objectFit(ImageFit.Cover)
          .interpolation(ImageInterpolation.High)
      } else {
        // 渲染尚未完成（或失败）时的占位：与海报底色一致，避免闪白。
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(TEXT_POSTER_STYLES[index].background)
      }
    }
    .width('100%')
    .height('100%')
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
        // 单图无翻页语义：仅当多于 1 张时才允许滑动，避免单图出现阻尼回弹/内容位移。
        .disableSwipe(draft.images.length <= 1)
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
        ForEach(TEXT_POSTER_STYLES, (style: TextPosterStyleOption, index: number) => {
          this.textPosterSlide(index)
        }, (style: TextPosterStyleOption) => style.key + '_' + this.textPosterRenderVersion)
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
          // 次级操作 → outlined；主级 CTA → primary（与 CircleOnboarding 确认 / PublishTagPanel 完成同档）
          DesignButton({
            label: '存草稿',
            variant: 'outlined',
            fillWidth: true,
            disabled: this.publishing,
            action: (): void => { this.saveCurrentDraft(); },
          })
          .layoutWeight(1)
          DesignButton({
            label: this.publishing ? '发布中' : '确认发布',
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
    // 底部操作区抬升避让三键导航条（审核问题③）；手势导航 navInset=0 不影响。
    .padding({ top: this.statusBarHeight + SpaceTokens.sm, bottom: SpaceTokens.md + bottomNavInset() })
    .backgroundColor(ColorTokens.canvas)
  }
}
