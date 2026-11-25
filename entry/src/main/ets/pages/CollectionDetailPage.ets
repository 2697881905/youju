// 合集详情页：有序帖子目录；作者可加帖（从自己已发布帖子中选）与移除
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import type { HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { buildPageTitleBarOptions, GlassTitleRow, GlassBarInsetRow } from '../design/components/HdsGlassBackSurface';
import { EmptyState } from '../design/components/EmptyState';
import { resolveActionIcon } from '../utils/actionIcons';
import {
  getCollection, addPostToCollection, removePostFromCollection, listPosts,
} from '../services/api';
import { Post, CollectionDetail } from '../models/types';
import { openPostDetail } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { getUserId } from '../utils/auth';
import { Pressable } from '../design/motion/Pressable';
import { PostCardMedia } from '../components/PostCardMedia';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

interface IndexedPost {
  index: number;
  post: Post;
}

@Entry
@Component
export struct CollectionDetailPage {
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @State collectionId: number = 0;
  @State authorId: number = 0;
  @State title: string = '合集';
  @State detail: CollectionDetail | null = null;
  @State posts: Post[] = [];
  @State ready: boolean = false;
  @State error: string = '';
  // 加帖选择器：展开后列出我的已发布帖子，避免新增浮层/弹窗组件
  @State pickerVisible: boolean = false;
  @State pickCandidates: Post[] = [];
  @State pickLoading: boolean = false;
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    if (getUserId() === 0) {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    const params = this.getUIContext().getRouter().getParams() as Record<string, string> | undefined;
    this.collectionId = Number(params?.collectionId ?? 0);
    this.authorId = Number(params?.authorId ?? 0);
    this.title = params?.title ?? '合集';
    this.load();
  }

  get isOwner(): boolean {
    return this.authorId === getUserId();
  }

  private async load(): Promise<void> {
    if (!(this.collectionId > 0)) {
      this.ready = true;
      this.error = '合集参数缺失，请返回重新进入';
      return;
    }
    try {
      const res = await getCollection(this.collectionId, 1, 50);
      this.detail = res.collection;
      this.posts = res.list;
      this.authorId = res.collection.authorId;
      this.title = res.collection.title;
      this.ready = true;
    } catch (e) {
      this.error = (e as Error).message;
      this.ready = true;
    }
  }

  // 展开选择器时拉取我的已发布帖子（最多 50 条）
  private async openPicker(): Promise<void> {
    if (this.pickLoading) {
      return;
    }
    this.pickerVisible = true;
    this.pickLoading = true;
    try {
      const res = await listPosts({ page: 1, limit: 50, sort: 'latest', author: getUserId() });
      this.pickCandidates = res.list;
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.pickLoading = false;
    }
  }

  private async onAdd(post: Post): Promise<void> {
    if (!(post.id! > 0)) {
      return;
    }
    try {
      await addPostToCollection(this.collectionId, post.id!);
      this.pickerVisible = false;
      this.load();
      safeShowToast(this.getUIContext(), { message: '已加入合集' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  private confirmRemove(post: Post): void {
    this.getUIContext().showAlertDialog({
      title: '从合集移除？',
      message: '帖子本身不会被删除',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '移除',
        fontColor: $r('app.color.semantic_red'),
        action: async (): Promise<void> => {
          try {
            await removePostFromCollection(this.collectionId, post.id!);
            this.load();
            safeShowToast(this.getUIContext(), { message: '已移除' });
          } catch (e) {
            safeShowToast(this.getUIContext(), { message: (e as Error).message });
          }
        },
      },
    });
  }

  // 双列分列：raw 下标 % 2，与主页信息流口径一致（首项左上角）
  private colPosts(colIdx: number): IndexedPost[] {
    const out: IndexedPost[] = [];
    for (let i: number = 0; i < this.posts.length; i += 1) {
      if (i % 2 === colIdx) {
        out.push({ index: i, post: this.posts[i] });
      }
    }
    return out;
  }

  @Builder
  postCard(index: number, post: Post) {
    Pressable({
      fillWidth: true,
      fullResponseRegion: true,
      action: (): void => { openPostDetail(String(post.id ?? 0)); },
    }) {
      Column({ space: SpaceTokens.none }) {
        // 3:4 封面（复用主页 PostCardMedia，视频封面/首图口径一致）；无封面用序号占位
        if ((typeof post.coverImage === 'string' && post.coverImage.length > 0)
          || (post.videoUrl ?? '').length > 0) {
          PostCardMedia({
            imageUrl: typeof post.coverImage === 'string' ? post.coverImage : '',
            videoUrl: post.videoUrl ?? '',
            videoCover: post.videoCover ?? '',
            compact: true,
          })
        } else {
          Column() {
            Text(String(index + 1).padStart(2, '0'))
              .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
              .fontColor(ColorTokens.secondary)
          }
          .width('100%')
          .aspectRatio(LayoutTokens.cardMediaAspectRatio)
          .backgroundColor(ColorTokens.sunken)
          .borderRadius({ topLeft: RadiusTokens.xs, topRight: RadiusTokens.xs, bottomLeft: 0, bottomRight: 0 })
          .justifyContent(FlexAlign.Center)
          .clip(true)
        }
        // 信息区：序号 + 标题 + 作者，elevated 底（与帖子卡信息区一致）
        Column({ space: SpaceTokens.inlineTight }) {
          Row({ space: SpaceTokens.xs }) {
            Text(String(index + 1))
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.brand)
            Text(post.title ?? '')
              .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.primary).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          if ((post.user !== undefined && post.user.nickname !== undefined) || this.isOwner) {
            Row() {
              if (post.user !== undefined && post.user.nickname !== undefined) {
                Text(post.user.nickname)
                  .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                  .fontColor(ColorTokens.tertiary).layoutWeight(1)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              if (this.isOwner) {
                Text('移除')
                  .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                  .fontColor($r('app.color.semantic_red'))
                  .onClick(() => { this.confirmRemove(post); });
              }
            }
            .width('100%')
          }
        }
        .padding(SpaceTokens.xs)
        .width('100%')
      }
      .width('100%')
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.xs)
      .clip(true)
    }
  }

  @Builder
  pickerPanel() {
    Column({ space: SpaceTokens.xs }) {
      Row() {
        Text('选择要加入的帖子')
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight).fontColor(ColorTokens.primary);
        Text('收起').fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.brand)
          .onClick(() => { this.pickerVisible = false; });
      }
      .width('100%').justifyContent(FlexAlign.SpaceBetween)
      if (this.pickLoading) {
        Text('加载中…').fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary);
      } else if (this.pickCandidates.length === 0) {
        Text('还没有已发布的帖子').fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily).fontColor(ColorTokens.tertiary);
      } else {
        ForEach(this.pickCandidates, (post: Post) => {
          Row() {
            Text(post.title ?? '').fontSize(TypeTokens.caption.size)
              .fontFamily(TypeTokens.fontFamily).fontColor(ColorTokens.primary)
              .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('加入').fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.brand)
              .onClick(() => { this.onAdd(post); });
          }
          .width('100%').padding({ top: 6, bottom: 6 })
        }, (post: Post) => String(post.id));
      }
    }
    .width('100%')
    .padding(SpaceTokens.base)
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(RadiusTokens.md)
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    return buildPageTitleBarOptions({
      back: (): void => { this.getUIContext().getRouter().back(); },
      stackBuilder: (): void => { this.titleRow(); },
    });
  }

  @Builder
  titleRow() {
    GlassTitleRow({ title: this.title })
  }

  build() {
    HdsNavigation() {
      Column() {
      // MINI 标题栏穿底：内容顶部统一让位（状态栏 + 栏体），固定区与滚动容器共用这一条
      GlassBarInsetRow({ statusBarHeight: this.statusBarHeight })
      if (!this.ready) {
        Column() {
          LoadingProgress().width(28).height(28);
          Text('加载中…').fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary).margin({ top: 10 });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else if (this.error !== '') {
        Column() {
          EmptyState({
            icon: resolveActionIcon('warning'),
            title: '加载失败',
            message: this.error,
            actionLabel: '重试',
            onAction: (): void => { this.error = ''; this.load(); },
          })
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else {
        if (this.detail !== null && this.detail.description !== null) {
          Text(this.detail.description)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary).width('100%')
            .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.sm });
        }
        if (this.isOwner && this.pickerVisible) {
          Column() {
            this.pickerPanel()
          }
          .width('100%')
          .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.sm })
        }
        if (this.posts.length === 0) {
          Column() {
            EmptyState({
              title: '合集还是空的',
              message: this.isOwner ? '点下方「添加帖子」开始连载' : '',
            })
          }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
        } else {
          // 双列卡片流（与主页信息流同构）：Scroll > Row > 两列 Column，raw 下标 %2 分列
          Scroll(this.pageScroller) {
            Column({ space: SpaceTokens.xs }) {

              Row({ space: SpaceTokens.xs }) {
                ForEach([0, 1], (colIdx: number) => {
                  Column({ space: SpaceTokens.xs }) {
                    ForEach(this.colPosts(colIdx), (entry: IndexedPost) => {
                      this.postCard(entry.index, entry.post)
                    }, (entry: IndexedPost) => String(entry.post.id))
                  }
                  .layoutWeight(1)
                }, (colIdx: number) => String(colIdx))
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }
            .width('100%')
            // 内容不足一屏时撑满视口，否则 Scroll 会把卡片垂直居中（顶部留白）
            .constraintSize({ minHeight: '100%' })
            .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.md })
          }
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollable(ScrollDirection.Vertical)
          .layoutWeight(1).width('100%')
          .scrollBar(BarState.Off);
        }
        if (this.isOwner) {
          Button(this.pickerVisible ? '收起选择器' : '添加帖子')
            .width('calc(100% - 32vp)').height(44)
            .margin({ left: 16, right: 16, top: 8, bottom: 20 })
            .backgroundColor($r('app.color.ds_brand_solid'))
            .fontColor($r('app.color.ds_on_brand'))
            .borderRadius(22)
            .onClick(() => {
              if (this.pickerVisible) {
                this.pickerVisible = false;
              } else {
                this.openPicker();
              }
            });
        }
      }
      }
      .width('100%').height('100%')
    }
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .titleBar(this.titleBarOptions())
    .bindToScrollable([this.pageScroller])
    .clip(false)
    .width('100%').height('100%')
    .backgroundColor($r('app.color.bg_primary'));
  }
}
