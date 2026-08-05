import { Post } from '../models/types';
import { followTag, listFollowedTags, listPosts, unfollowTag } from '../services/api';
import { ensureLogin } from '../utils/auth';
import { openPostDetail, takeCircleDetailName } from '../utils/nav';
import { observeGridColumns, gridColumnTemplate } from '../utils/responsive';
import { GRID_GAP, GRID_PADDING } from '../utils/cardTokens';
import { safeShowToast } from '../utils/toast';
import { PostCard } from '../components/PostCard';
import { TagIcon } from '../components/TagIcon';
import { DesignButton } from '../design/components/DesignButton';
import { EmptyState } from '../design/components/EmptyState';
import { SegmentedControl, SegmentedItem } from '../design/components/SegmentedControl';
import { BackButton } from '../design/components/BackButton';
import { Pressable } from '../design/motion/Pressable';
import { Reveal } from '../design/motion/Reveal';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { common } from '@kit.AbilityKit';

const FEED_SEGMENTS: SegmentedItem[] = [
  { key: 'latest', label: '最新' },
  { key: 'hot', label: '热门' },
];

@Entry
@Component
struct CircleDetailPage {
  @State circleName: string = '';
  @State posts: Post[] = [];
  @State sortIndex: number = 0;
  @State page: number = 1;
  @State loading: boolean = false;
  @State refreshing: boolean = false;
  @State finished: boolean = false;
  @State error: string = '';
  @State joined: boolean = false;
  @State joining: boolean = false;
  @State gridColumns: number = 2;
  @State gridTemplate: string = '1fr 1fr';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  private listVersion: number = 0;
  private unregisterColumns: () => void = () => {};

  aboutToAppear(): void {
    this.circleName = takeCircleDetailName();
    this.unregisterColumns = observeGridColumns(
      this.getUIContext().getHostContext() as common.Context,
      (cols: number): void => {
        this.gridColumns = cols;
        this.gridTemplate = gridColumnTemplate(cols);
      }
    );
    this.init();
  }

  aboutToDisappear(): void {
    this.unregisterColumns();
  }

  private async init(): Promise<void> {
    if (this.circleName.length === 0) {
      this.error = '圈子信息已失效，请从圈子页重新进入';
      return;
    }
    const user = await ensureLogin();
    if (!user) {
      return;
    }
    await this.loadJoined();
    await this.refresh();
  }

  private async loadJoined(): Promise<void> {
    try {
      const names = await listFollowedTags();
      this.joined = names.indexOf(this.circleName) >= 0;
    } catch (e) {
      // 帖子流仍可继续加载；加入状态在本次会话中保持默认值。
    }
  }

  private async refresh(): Promise<void> {
    const version = this.listVersion + 1;
    this.listVersion = version;
    this.page = 1;
    this.finished = false;
    this.error = '';
    this.posts = [];
    await this.fetch(true, version);
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.finished || this.refreshing) {
      return;
    }
    this.page += 1;
    await this.fetch(false, this.listVersion);
  }

  private async fetch(reset: boolean, version: number): Promise<void> {
    if (!reset && this.loading) {
      return;
    }
    this.loading = true;
    try {
      const result = await listPosts({
        page: this.page,
        limit: 20,
        sort: this.sortIndex === 0 ? 'latest' : 'hot',
        tag: this.circleName,
      });
      if (version !== this.listVersion) {
        return;
      }
      this.posts = reset ? result.list : this.posts.concat(result.list);
      this.finished = result.list.length < 20;
    } catch (e) {
      if (version === this.listVersion) {
        this.error = (e as Error).message;
      }
    } finally {
      if (version === this.listVersion) {
        this.loading = false;
      }
    }
  }

  private switchSort(index: number): void {
    // SegmentedControl 会先更新双向绑定的 sortIndex，再触发 onSelect。
    if (this.sortIndex !== index) {
      this.sortIndex = index;
    }
    this.refresh();
  }

  private async toggleJoin(): Promise<void> {
    if (this.joining || this.circleName.length === 0) {
      return;
    }
    const wasJoined = this.joined;
    this.joining = true;
    this.joined = !wasJoined;
    try {
      if (wasJoined) {
        await unfollowTag(this.circleName);
      } else {
        await followTag(this.circleName);
      }
      const version: number = AppStorage.get<number>('circleMembershipVersion') ?? 0;
      AppStorage.setOrCreate('circleMembershipVersion', version + 1);
      safeShowToast(this.getUIContext(), { message: wasJoined ? '已退出圈子' : '已加入圈子' });
    } catch (e) {
      this.joined = wasJoined;
      safeShowToast(this.getUIContext(), { message: '操作失败：' + (e as Error).message });
    } finally {
      this.joining = false;
    }
  }

  private openPost(post: Post): void {
    if (post.id === undefined) {
      return;
    }
    const id = String(post.id);
    openPostDetail(id);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
  }

  @Builder
  refreshBuilder(): void {
    Row({ space: SpaceTokens.inline }) {
      LoadingProgress().width(IconTokens.compact).height(IconTokens.compact)
      Text('刷新中…')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.caption.weight)
        .fontColor(ColorTokens.secondary)
    }
  }

  build() {
    Column() {
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })

        Blank()
        Text('圈子')
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .fontColor(ColorTokens.primary)
        Blank()
        Text('')
          .width(LayoutTokens.minTouchTarget)
          .height(LayoutTokens.minTouchTarget)
      }
      .width('100%')
      .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, top: SpaceTokens.md, bottom: SpaceTokens.sm })
      .alignItems(VerticalAlign.Center)

      Row({ space: SpaceTokens.item }) {
        TagIcon({ name: this.circleName, iconSize: IconTokens.avatarProfile + 2, tint: ColorTokens.brand })
          .width(IconTokens.avatarProfile)
          .height(IconTokens.avatarProfile)

        Column({ space: SpaceTokens.inlineTight }) {
          Text(this.circleName)
            .fontSize(TypeTokens.display.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.display.weight)
            .lineHeight(TypeTokens.display.lineHeight)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('浏览这个圈子里的真实帖子')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.callout.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.secondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, top: SpaceTokens.sm, bottom: SpaceTokens.item })

      Row() {
        SegmentedControl({
          items: FEED_SEGMENTS,
          selectedIndex: $sortIndex,
          itemWidth: 64,
          fillWidth: false,
          glass: true,
          onSelect: (index: number): void => { this.switchSort(index); },
        })
        Blank()
        DesignButton({
          label: this.joined ? '退出圈子' : '加入圈子',
          variant: 'glass',
          disabled: this.joining,
          action: (): void => { this.toggleJoin(); },
        })
      }
      .width('100%')
      .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.sm })
      .alignItems(VerticalAlign.Center)

      if (this.posts.length === 0 && this.loading) {
        Column({ space: SpaceTokens.item }) {
          LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
          Text('正在加载帖子')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.callout.weight)
            .fontColor(ColorTokens.secondary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.posts.length === 0) {
        Column() {
          EmptyState({
            title: this.error ? '加载失败' : '这个圈子还没有帖子',
            message: this.error ? this.error : '第一篇相关内容发布后会显示在这里',
            actionLabel: this.error ? '重试' : '',
            onAction: (): void => { this.refresh(); },
          })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: this.refreshing, builder: this.refreshBuilder }) {
          Grid() {
            ForEach(this.posts, (post: Post, index: number) => {
              GridItem() {
                Reveal({ index: index % 5 }) {
                  PostCard({ post: post, onOpen: (): void => { this.openPost(post); } })
                }
              }
            }, (post: Post) => this.circleName + '-' + (post.id?.toString() ?? ''))
            if (this.finished) {
              GridItem() {
                Text('没有更多了')
                  .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                  .fontWeight(TypeTokens.caption.weight)
                  .fontColor(ColorTokens.tertiary)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding(SpaceTokens.base)
              }
              .columnStart(0)
              .columnEnd(this.gridColumns - 1)
            }
          }
          .columnsTemplate(this.gridTemplate)
          .columnsGap(GRID_GAP)
          .rowsGap(GRID_GAP)
          .padding({ left: GRID_PADDING, right: GRID_PADDING, top: GRID_PADDING, bottom: GRID_PADDING })
          .onScrollIndex((_start: number, end: number) => {
            if (end >= this.posts.length - 1) {
              this.loadMore();
            }
          })
        }
        .onRefreshing(() => {
          this.refreshing = true;
          this.refresh().finally(() => { this.refreshing = false; });
        })
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarHeight })
    .backgroundColor(ColorTokens.canvas)
    .alignItems(HorizontalAlign.Start)
  }
}
