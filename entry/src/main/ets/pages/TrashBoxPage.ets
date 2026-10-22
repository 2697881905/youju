// 废纸篓：顶部标题（返回键 + 「废纸篓」）驻留 HdsNavigation 标题栏，下方为内容区。
// 返回键走官方 `content.backIcon`（40vp 玻璃圆，与「我的」/首页/聊天页/草稿箱同一套栏级材质），
// 不再自绘。内容接穿底 + 渐变模糊：列表滚到栏下时被采样，材质才有东西可折射。
// （与草稿箱同构，配方见基准 §7.6.31）。列表复用 ManagedPostFeed。
//
// 卡片不再内嵌「恢复 / 彻底删除」按钮：操作统一收进帖子详情页的作者菜单
// （点卡片 → 详情 → 标题栏「更多」→ 恢复帖子 / 彻底删除）。
// 后端 getPost 已允许作者本人查看自己的已删除帖子（postService.getPost），该路径成立。
import { Post } from '../models/types';
import { listTrashedPosts } from '../services/api';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { ManagedPostFeed } from '../components/ManagedPostFeed';
import { buildPageTransition } from '../utils/styles';
import { openPostDetail } from '../utils/nav';
import { getUserId } from '../utils/auth';
import { resolveActionIcon } from '../utils/actionIcons';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
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
// 栏级沉浸光感：与「我的」/首页/聊天页/草稿箱同一对字段、同一门禁（基准 §7.6.29）。
import { isImmersiveLightSenseSupported, HDS_MATERIAL_TYPE_IMMERSIVE, HDS_MATERIAL_LEVEL_EXQUISITE } from '../utils/immersiveMaterial';

// 官方返回键占 16~56vp（40vp 圆 + 16vp 左内缩）。stackBuilder 那行是全宽的、且在返回键的
// 后一个兄弟节点上（z 序更高），不留出这段就会**吃掉返回键的点击**（ChatView 试点真机复现）。
const HDS_BACK_SLOT_END_VP: number = 64;
// 栏体高（vp）：MINI 标题区实测 175px ÷ 3.125 = 56vp。穿底时内容按这个值让位。
const TRASH_BAR_ROW_VP: number = 56;
// 渐变模糊生效区间终点（vp）：与草稿箱/聊天页同量级
const TRASH_BLUR_END_VP: number = 32;

@Entry
@Component
struct TrashBoxPage {
  @State posts: Post[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 交给 HdsNavigation.bindToScrollable 驱动顶栏渐变模糊（配方同草稿箱）
  private feedScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    // 登录闸门：废纸篓是「我自己的数据」，未登录进来只会是「加载失败」空壳。
    // 用 replaceUrl 把本页从路由栈里替换掉 —— 取消登录返回时落到**入口页**（我的页）。
    if (getUserId() === 0) {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.reload();
  }

  private async reload(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const result = await listTrashedPosts(1, 50);
      // 展示口径（补齐封面）在数据层一次归一化，列表组件只消费结果
      this.posts = result.list.map((p: Post): Post => this.postForDisplay(p));
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
      structuredDocument: post.structuredDocument,
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

  private postKeys(): string[] {
    return this.posts.map((p: Post): string => String(p.id ?? ''));
  }

  private openDetail(post: Post): void {
    if (post.id === undefined) {
      return;
    }
    openPostDetail(post.id.toString());
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
  }

  // 标题栏配置：官方返回键（backIcon）+ stackBuilder 只放「废纸篓」文字。
  // 状态栏避让交给 avoidLayoutSafeArea(true)；内容侧 enableComponentSafeArea(false) + topInset
  // 让帖子能穿到栏下被渐变模糊采样 —— 材质才有东西可折射。
  private trashTitleBarOptions(): HdsNavigationTitleBarOptions {
    const immersive: boolean = isImmersiveLightSenseSupported();
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: immersive ? ScrollEffectType.IMMERSIVE_GRADIENT_BLUR : ScrollEffectType.GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(TRASH_BLUR_END_VP),
    };
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: {
        backgroundStyle: { backgroundColor: Color.Transparent },
        contentStyle: {
          backIconStyle: { iconColor: ColorTokens.primary } as HdsNavigationIconItemStyle,
        } as HdsTitleBarContentStyle,
      },
    };
    if (immersive) {
      style.systemMaterialEffect = {
        materialType: HDS_MATERIAL_TYPE_IMMERSIVE,
        materialLevel: HDS_MATERIAL_LEVEL_EXQUISITE,
      } as SystemMaterialParams;
    }
    // backIcon 带 action 槽 → 返回行为原样保留（还是 router.back()）
    const backContent: HdsNavigationIconOptions = {
      icon: resolveActionIcon('back'),
      label: '返回',
      action: (): void => { this.getUIContext().getRouter().back(); },
    };
    const backIcon: HdsNavigationBackButtonItemOptions = backContent;
    const content: TitleBarContentOptions = {
      stackBuilder: (): void => { this.trashTitleRow(); },
      backIcon: backIcon,
    };
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
    };
    return options;
  }

  // stackBuilder 行：只剩「废纸篓」标题。
  // ⚠️ 左内缩必须让开官方返回键 —— 这一行 width('100%') 且住在 StackCustomNode 里，
  // 是返回键 Button 的后一个兄弟节点（z 序更高），不留开会把返回键的点击吃掉。
  @Builder
  trashTitleRow(): void {
    Row() {
      Text('废纸篓')
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
    if (this.loading) {
      Column() {
        Text('正在加载…')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else if (this.error.length > 0) {
      Column({ space: SpaceTokens.sm }) {
        Text(this.error)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.danger)
          .textAlign(TextAlign.Center)
        Pressable({ action: (): void => { this.reload(); } }) {
          Text('重新加载')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.primary)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else if (this.posts.length === 0) {
      Column({ space: SpaceTokens.sm }) {
        Text('废纸篓为空')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.secondary)
        Text('删除的帖子会暂存在这里')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      ManagedPostFeed({
        posts: this.posts,
        itemKeys: this.postKeys(),
        badgeText: '已删除',
        // 穿底：滚动源交给顶栏驱动渐变模糊，并补回「状态栏 + 栏高」的让位量
        scroller: this.feedScroller,
        topInset: this.statusBarHeight + TRASH_BAR_ROW_VP,
        onOpen: (post: Post, _key: string): void => { this.openDetail(post); },
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
    .titleBar(this.trashTitleBarOptions())
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
