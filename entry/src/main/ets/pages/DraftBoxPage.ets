// 草稿箱：顶部标题（返回键 + 「草稿箱」）驻留 HdsNavigation 标题栏，下方为内容区。
// 返回键走官方 `content.backIcon`（40vp 玻璃圆，与「我的」/首页/聊天页同一套栏级材质），
// 不再自绘 —— 这是「普通 Navigation → HdsNavigation」的第一块试验田（基准 §7.6.31）。
// 列表复用 ManagedPostFeed —— 与首页信息流同款双列布局、卡片样式与入场错峰过渡。
//
// 草稿的 Post 没有 id，列表的稳定 key 由草稿 id 提供，因此点击/删除回调都按 key 反查草稿。
import { getCurrentUser, getUserId } from '../utils/auth';
import { removePostDraft, listPostDrafts, SavedPostDraft, subscribePostDrafts } from '../utils/postDraftStore';
import { Post } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { publishFlowStore } from '../utils/publishFlowStore';
import { PublishMode } from '../components/PublishModePanel';
import { ManagedPostFeed } from '../components/ManagedPostFeed';
import { resolveTextPosterStyle } from '../utils/poster/posterTokens';
import { buildPageTransition } from '../utils/styles';
import { buildPageTitleBarOptions, GlassTitleRow } from '../design/components/HdsGlassBackSurface';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import type { HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';

// 栏体高（vp）：MINI 标题区实测 175px ÷ 3.125 = 56vp。穿底时内容要按这个值让位。
const DRAFT_BAR_ROW_VP: number = 56;

@Entry
@Component
struct DraftBoxPage {
  @State drafts: SavedPostDraft[] = [];
  // 穿底配方要按状态栏高度自己让位（enableComponentSafeArea=false 后系统不再代为顶开内容）
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 交给 HdsNavigation.bindToScrollable，驱动顶栏渐变模糊 —— 没有它，栏后拿不到内容可采样，
  // 玻璃珠材质在纯白画布上只差 2~3 级，肉眼等于没变化（用户复看时指出的正是这一点）
  private feedScroller: Scroller = new Scroller();
  private unsubscribeDrafts: () => void = () => {};

  aboutToAppear(): void {
    // 登录闸门：草稿按 userId 归档，未登录（userId=0）看到的是「暂无草稿」——一个假结论。
    // 用 replaceUrl 把本页从路由栈里替换掉 —— 取消登录返回时落到**入口页**（我的页）。
    if (getUserId() === 0) {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
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

  private draftOf(key: string): SavedPostDraft | undefined {
    return this.drafts.find((d: SavedPostDraft): boolean => d.id === key);
  }

  private continueEdit(draft: SavedPostDraft): void {
    publishFlowStore.editSavedDraft(draft.id, draft);
    const mode: PublishMode = draft.mode ?? ((draft.videoUrl !== undefined && draft.videoUrl.length > 0) ? 'video'
      : (draft.images.length === 0 ? 'text' : 'photo'));
    const url: string = mode === 'video' ? 'pages/VideoPublishPage'
      : (mode === 'text' ? 'pages/TextPublishPage' : 'pages/PhotoPublishPage');
    this.getUIContext().getRouter().pushUrl({ url: url });
  }

  // 列表删除按钮回调（回传稳定 key = 草稿 id）
  private removeByKey(key: string): void {
    const draft: SavedPostDraft | undefined = this.draftOf(key);
    if (draft === undefined) {
      return;
    }
    this.remove(draft);
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
      structuredDocument: draft.structuredDocument,
      upCount: 0,
      commentCount: 0,
      user: getCurrentUser() ?? undefined,
    };
  }

  private draftPosts(): Post[] {
    return this.drafts.map((d: SavedPostDraft): Post => this.postForDraft(d));
  }

  private draftKeys(): string[] {
    return this.drafts.map((d: SavedPostDraft): string => d.id);
  }

  // 文字海报样式 key（与 draftPosts 同序）：无图草稿在列表里用本地渲染海报作封面。
  // ⚠️ 必须经 resolveTextPosterStyle 归一化：textPosterStyle 只由**文本发布页**写入，
  // 「照片帖但没放图」的草稿没有这个字段 —— 而预览页对这类草稿照样渲染海报（取第 0 个样式）。
  // 若原样传 undefined/''，外层「styleKey 非空」的判断不成立 → 卡片不渲染海报封面（实测 bug）。
  private draftPosterStyles(): string[] {
    return this.drafts.map((d: SavedPostDraft): string => resolveTextPosterStyle(d.textPosterStyle).key);
  }

  // 标题栏配置：官方返回键（backIcon）+ stackBuilder 只放「草稿箱」文字，返回闭包原逻辑逐字保留。
  // 渐变模糊/栏级材质/透明底配方收敛进 buildPageTitleBarOptions 内部的 buildGlassTitleBarStyle
  // （同门禁、同 32vp 端点）；状态栏避让走缺省 avoidLayoutSafeArea(true)；内容侧缺省
  // enableComponentSafeArea(false) + 自己补 topInset，让草稿卡片能穿到栏下被渐变模糊采样。
  private draftTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildPageTitleBarOptions({
      back: (): void => { this.getUIContext().getRouter().back(); },
      stackBuilder: (): void => { this.draftTitleRow(); },
    });
  }

  // stackBuilder 行：只剩「草稿箱」标题，居中与返回键让位样板收敛进 GlassTitleRow。
  @Builder
  draftTitleRow(): void {
    GlassTitleRow({ title: '草稿箱', headlineSerif: true })
  }

  @Builder
  body(): void {
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
      ManagedPostFeed({
        posts: this.draftPosts(),
        itemKeys: this.draftKeys(),
        textPosterStyles: this.draftPosterStyles(),
        badgeText: '草稿',
        deletable: true,
        // 草稿未发布，没有真实互动数据 → 不显示互动数据行（其余仍与首页卡片一致）
        showStats: false,
        // 穿底：把滚动源交给顶栏驱动渐变模糊，并补回「状态栏 + 栏高」的让位量
        scroller: this.feedScroller,
        topInset: this.statusBarHeight + DRAFT_BAR_ROW_VP,
        onOpen: (_post: Post, key: string): void => {
          const draft: SavedPostDraft | undefined = this.draftOf(key);
          if (draft !== undefined) {
            this.continueEdit(draft);
          }
        },
        onDelete: (key: string): void => { this.removeByKey(key); },
      })
    }
  }

  build() {
    HdsNavigation() {
      Column() {
        this.body()
      }
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .titleBar(this.draftTitleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    // 渐变模糊的滚动源：没有它，栏后拿不到内容可采样，材质在纯白画布上只差 2~3 级看不出
    .bindToScrollable([this.feedScroller])
    // 穿底绘制链路：HdsNavigation 自身不裁切（内容需画到栏下被模糊采样）
    .clip(false)
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    .transition(buildPageTransition())
  }
}
