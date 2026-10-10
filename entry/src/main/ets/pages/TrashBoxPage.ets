// 废纸篓：顶部标题（返回键 + 「废纸篓」）迁入 Navigation 标题栏，下方为内容区
// （与首页/搜索结果页同构）。列表复用 ManagedPostFeed —— 与首页信息流同款双列布局、
// 卡片样式与入场错峰过渡。
//
// 卡片不再内嵌「恢复 / 彻底删除」按钮：操作统一收进帖子详情页的作者菜单
// （点卡片 → 详情 → 标题栏「更多」→ 恢复帖子 / 彻底删除）。
// 后端 getPost 已允许作者本人查看自己的已删除帖子（postService.getPost），该路径成立。
import { Post } from '../models/types';
import { listTrashedPosts } from '../services/api';
import { BackButton } from '../design/components/BackButton';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { ManagedPostFeed } from '../components/ManagedPostFeed';
import { buildPageTransition } from '../utils/styles';
import { openPostDetail } from '../utils/nav';
import { getUserId } from '../utils/auth';

@Entry
@Component
struct TrashBoxPage {
  @State posts: Post[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

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

  // 标题栏内容：随页面一起迁入 Navigation 标题栏（沉浸式布局下系统不代为避让状态栏，
  // 由标题栏自行下移；STANDARD 占位使内容区从栏下开始，内容区不再重复避让）。
  @Builder
  trashTitleBar(): void {
    Row({ space: SpaceTokens.sm }) {
      BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
      Text('废纸篓')
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
        onOpen: (post: Post, _key: string): void => { this.openDetail(post); },
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
      builder: this.trashTitleBar,
      height: this.titleBarHeight(),
    }, { barStyle: BarStyle.STANDARD, backgroundColor: ColorTokens.canvas })
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    .transition(buildPageTransition())
  }
}
