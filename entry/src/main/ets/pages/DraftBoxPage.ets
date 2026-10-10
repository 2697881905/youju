// 草稿箱：顶部标题（返回键 + 「草稿箱」）迁入 Navigation 标题栏，下方为内容区
// （与首页/废纸篓/搜索结果页同构）。列表复用 ManagedPostFeed —— 与首页信息流同款
// 双列布局、卡片样式与入场错峰过渡。
//
// 草稿的 Post 没有 id，列表的稳定 key 由草稿 id 提供，因此点击/删除回调都按 key 反查草稿。
import { getCurrentUser, getUserId } from '../utils/auth';
import { removePostDraft, listPostDrafts, SavedPostDraft, subscribePostDrafts } from '../utils/postDraftStore';
import { Post } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { BackButton } from '../design/components/BackButton';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { publishFlowStore } from '../utils/publishFlowStore';
import { PublishMode } from '../components/PublishModeSheet';
import { ManagedPostFeed } from '../components/ManagedPostFeed';
import { resolveTextPosterStyle } from '../utils/poster/posterTokens';
import { buildPageTransition } from '../utils/styles';

@Entry
@Component
struct DraftBoxPage {
  @State drafts: SavedPostDraft[] = [];
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
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

  // 标题栏内容：随页面一起迁入 Navigation 标题栏（沉浸式布局下系统不代为避让状态栏，
  // 由标题栏自行下移；STANDARD 占位使内容区从栏下开始，内容区不再重复避让）。
  @Builder
  draftTitleBar(): void {
    Row({ space: SpaceTokens.sm }) {
      BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
      Text('草稿箱')
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(TypeTokens.headline.lineHeight)
        .fontColor(ColorTokens.primary)
    }
    .width('100%')
    .height(LayoutTokens.minTouchTarget)
    .alignItems(VerticalAlign.Center)
    .padding({ top: this.statusBarHeight, left: SpaceTokens.md, right: SpaceTokens.md })
  }

  private titleBarHeight(): number {
    return this.statusBarHeight + LayoutTokens.minTouchTarget;
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
    Navigation() {
      Column() {
        this.body()
      }
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(false)
    .title({
      builder: this.draftTitleBar,
      height: this.titleBarHeight(),
    }, { barStyle: BarStyle.STANDARD, backgroundColor: ColorTokens.canvas })
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    .transition(buildPageTransition())
  }
}
