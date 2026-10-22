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
import { PublishMode } from '../components/PublishModeSheet';
import { ManagedPostFeed } from '../components/ManagedPostFeed';
import { resolveTextPosterStyle } from '../utils/poster/posterTokens';
import { buildPageTransition } from '../utils/styles';
import { resolveActionIcon } from '../utils/actionIcons';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import type {
  HdsNavigationTitleBarOptions,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  ScrollEffectOptions,
  SystemMaterialParams,
  HdsTitleBarContentStyle,
  HdsNavigationIconItemStyle,
  HdsNavigationBackButtonItemOptions,
  HdsNavigationIconOptions,
} from '@kit.UIDesignKit';
// 栏级沉浸光感：与「我的」/首页/聊天页同一对字段、同一门禁（基准 §7.6.29）。
import { isImmersiveLightSenseSupported, HDS_MATERIAL_TYPE_IMMERSIVE, HDS_MATERIAL_LEVEL_EXQUISITE } from '../utils/immersiveMaterial';

// 官方返回键占 16~56vp（40vp 圆 + 16vp 左内缩）。stackBuilder 那行是全宽的、且在返回键的
// 后一个兄弟节点上（z 序更高），不留出这段就会**吃掉返回键的点击**（ChatView 试点真机复现）。
const HDS_BACK_SLOT_END_VP: number = 64;

@Entry
@Component
struct DraftBoxPage {
  @State drafts: SavedPostDraft[] = [];
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

  // 标题栏配置：官方返回键（backIcon）+ stackBuilder 只放「草稿箱」文字。
  // 状态栏避让交给 avoidLayoutSafeArea(true)，不再手动加 statusBarHeight padding；
  // enableComponentSafeArea(true) 让内容从栏下开始（等价于原先的 BarStyle.STANDARD 占位）。
  private draftTitleBarOptions(): HdsNavigationTitleBarOptions {
    const style: TitleBarStyleOptions = {
      // 本页内容容器（ManagedPostFeed）没有对外暴露 Scroller，拿不到滚动源 →
      // 不启用滚动特效，栏静止态即终态。材质与滚动特效是两件事，见下方 systemMaterialEffect。
      scrollEffectOpts: { enableScrollEffect: false } as ScrollEffectOptions,
      originalStyle: {
        backgroundStyle: { backgroundColor: Color.Transparent },
        contentStyle: {
          backIconStyle: { iconColor: ColorTokens.primary } as HdsNavigationIconItemStyle,
        } as HdsTitleBarContentStyle,
      },
    };
    if (isImmersiveLightSenseSupported()) {
      // 栏级材质：官方圆钮的 rim + 折射只在这一档出图（不传 → 默认 3% 黑平面，无轮廓）。
      style.systemMaterialEffect = {
        materialType: HDS_MATERIAL_TYPE_IMMERSIVE,
        materialLevel: HDS_MATERIAL_LEVEL_EXQUISITE,
      } as SystemMaterialParams;
    }
    // backIcon 带 action 槽 → 返回行为原样保留（还是 router.back()），不会被换成 NavPathStack 默认 pop
    const backContent: HdsNavigationIconOptions = {
      icon: resolveActionIcon('back'),
      label: '返回',
      action: (): void => { this.getUIContext().getRouter().back(); },
    };
    const backIcon: HdsNavigationBackButtonItemOptions = backContent;
    const content: TitleBarContentOptions = {
      stackBuilder: (): void => { this.draftTitleRow(); },
      backIcon: backIcon,
    };
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
    };
    return options;
  }

  // stackBuilder 行：只剩「草稿箱」标题。
  // ⚠️ 左内缩必须让开官方返回键 —— 这一行是 width('100%') 且住在 StackCustomNode 里，
  // 是返回键 Button 的后一个兄弟节点（z 序更高），不留开就会把返回键的点击吃掉（ChatView 实测）。
  @Builder
  draftTitleRow(): void {
    Row() {
      Text('草稿箱')
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(TypeTokens.headline.lineHeight)
        .fontColor(ColorTokens.primary)
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: HDS_BACK_SLOT_END_VP, right: SpaceTokens.md })
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
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    .transition(buildPageTransition())
  }
}
