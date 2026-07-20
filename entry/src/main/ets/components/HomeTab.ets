// 首页 feed（真实内容）：顶栏(三子Tab+搜索框同水平) + 标签筛选 + 帖子网格
// 搜索框获焦时展示 SearchPanel（搜索历史+热搜词），提交或选中关键词后跳结果页
// 数据来源：listPosts / listTags / recordSearchHistory（services/api.ets）

import { Post, Tag } from '../models/types';
import { listPosts, listFollowingPosts, listTags, recordSearchHistory, getUserProfile } from '../services/api';
import { getUserId } from '../utils/auth';
import { PostCard } from './PostCard';
import { TagNav } from './TagNav';
import { SearchPanel } from './SearchPanel';
import { setDetailPostId, emitTabSwitch } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { BasicDataSource } from '../utils/data-source';

type SortKey = 'hot' | 'latest' | 'recommend';
type FeedMode = 'recommend' | 'following';

const SORT_KEYS: SortKey[] = ['hot', 'latest', 'recommend'];
const FEED_TABS: string[] = ['推荐', '关注'];
const ALL_TAG: Tag = { name: '全部', emoji: '🔥' };

@Component
export struct HomeTab {
  @State posts: Post[] = [];
  private postSource: BasicDataSource<Post> = new BasicDataSource<Post>();
  @State displayTags: Tag[] = [];
  @State sortIndex: number = 0;
  @State @Watch('onTagChanged') tagIndex: number = 0;
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State isRefreshing: boolean = false;
  @State error: string = '';
  @State showPanel: boolean = false;
  @State feedMode: FeedMode = 'recommend'; // 'recommend' | 'following'
  @State needLogin: boolean = false; // 关注流且未登录的引导态
  @State followingCount: number = 0; // 关注流的关注数缓存（空态 A/B 区分）
  // 监听登录态：登录成功后 authToken 就绪，若处于关注流且列表空则自动补加载
  @StorageLink('authToken') @Watch('onTokenReady') token: string = '';

  aboutToAppear(): void {
    this.loadTags();
    // 默认加载推荐公开流（无需登录）；若已登录也保持推荐流默认
    this.refresh();
  }

  // token 由空变为非空（登录完成）→ 关注流且列表空、无 error 时自动补加载
  onTokenReady(): void {
    if (this.token !== '' && this.feedMode === 'following' && this.posts.length === 0 && this.error === '') {
      this.refresh();
    }
  }

  async loadTags(): Promise<void> {
    try {
      const tags = await listTags();
      this.displayTags = [ALL_TAG, ...tags];
    } catch (e) {
      // 标签加载失败不阻断列表；保留 "全部"
      this.displayTags = [ALL_TAG];
    }
  }

  // 重置并加载第一页
  async refresh(): Promise<void> {
    this.page = 1;
    this.finished = false;
    this.followingCount = 0; // 重置关注流空态缓存
    await this.fetch(true);
  }

  // 追加下一页
  async loadMore(): Promise<void> {
    if (this.finished || this.loading || this.isRefreshing) {
      return;
    }
    this.page += 1;
    await this.fetch(false);
  }

  onTagChanged(): void {
    this.refresh();
  }

  private currentTag(): string | undefined {
    return this.tagIndex > 0 ? this.displayTags[this.tagIndex]?.name : undefined;
  }

  // 切换信息源（推荐/关注）：重置并重新拉取
  private switchFeed(mode: FeedMode): void {
    if (this.feedMode !== mode) {
      this.feedMode = mode;
      this.needLogin = (mode === 'following' && this.token === '');
      this.refresh();
    }
  }

  private async fetch(reset: boolean): Promise<void> {
    if (this.loading) {
      return;
    }
    // 关注流且未登录：不发起请求，展示登录引导态
    if (this.feedMode === 'following' && this.token === '') {
      this.needLogin = true;
      this.posts = []; // 清空上一流（推荐流）残留内容
      this.postSource.clearData();
      return;
    }
    this.loading = true;
    this.error = '';
    this.needLogin = false; // 进入真正的拉取流程，复位登录引导态
    const sort = SORT_KEYS[this.sortIndex];
    try {
      const res =
        this.feedMode === 'following'
          ? await listFollowingPosts({ page: this.page, limit: 20, sort, tag: this.currentTag() })
          : await listPosts({ page: this.page, limit: 20, sort, tag: this.currentTag() });
      if (reset) {
        this.posts = res.list;
        this.postSource.setData(res.list);
      } else {
        this.posts = this.posts.concat(res.list);
        this.postSource.appendData(res.list);
      }
      if (res.list.length < 20) {
        this.finished = true;
      }
      // 关注流空列表：异步取 followingCount 用于空态 A/B 区分（不阻塞渲染）
      if (this.feedMode === 'following' && res.list.length === 0 && this.token !== '') {
        this.loadFollowingCount();
      }
    } catch (e) {
      this.error = (e as Error).message;
    } finally {
      this.loading = false;
    }
  }

  // 取当前用户的关注数（关注流空态 A/B 区分：0→未关注任何人，>0→关注的人未发帖）
  private async loadFollowingCount(): Promise<void> {
    try {
      const id: number = getUserId();
      if (id === 0) {
        this.followingCount = 0;
        return;
      }
      const profile = await getUserProfile(id);
      this.followingCount = profile.followingCount;
    } catch (e) {
      // 计数失败不阻断，默认按空态 A 处理
      this.followingCount = 0;
    }
  }

  // 搜索：校验关键词 → 隐藏面板 → 跳结果页 → 记录历史（fire-and-forget）
  private doSearch(raw: string): void {
    const kw = raw.trim();
    if (!kw) {
      safeShowToast(this.getUIContext(),{ message: '请输入搜索内容' });
      return;
    }
    this.showPanel = false;
    AppStorage.setOrCreate('searchKeyword', kw);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SearchResultPage' });
    // fire-and-forget：记录搜索历史，失败不阻断
    this.recordHistoryAsync(kw);
  }

  // 异步记录搜索历史（独立方法，避免阻塞搜索跳转）
  private async recordHistoryAsync(kw: string): Promise<void> {
    try {
      await recordSearchHistory(kw);
    } catch (e) {
      // 记录历史失败不影响搜索体验
    }
  }

  // SearchPanel 关键词选中回调：触发搜索
  private onKeywordSelect(kw: string): void {
    this.doSearch(kw);
  }

  @Builder
  refreshBuilder(): void {
    Row({ space: 8 }) {
      LoadingProgress().width(20).height(20)
      Text('刷新中…').fontSize(12).fontColor($r('app.color.text_secondary'))
    }
  }

  build() {
    Column() {
      if (this.showPanel) {
        // 全屏搜索面板：自带 < 返回 + 输入框 + 搜索 头部栏，隐藏首页推荐/关注顶栏
        SearchPanel({
          onKeywordSelect: (kw: string): void => {
            this.onKeywordSelect(kw);
          },
          onCancel: (): void => {
            this.showPanel = false;
          }
        })
          .transition(TransitionEffect.OPACITY
            .animation({ duration: 250, curve: Curve.EaseOut })
            .combine(TransitionEffect.translate({ x: '100%' })
              .animation({ duration: 300, curve: Curve.EaseOut })))
      } else {
        // 顶部栏：左 推荐/关注 分段（信息源切换），右 搜索入口
        Row({ space: 12 }) {
          // 推荐 / 关注（带下划线指示器）
          Row({ space: 0 }) {
            ForEach(FEED_TABS, (name: string, idx: number) => {
              Column() {
                Text(name)
                  .fontSize(16)
                  .fontWeight(this.feedMode === (idx === 0 ? 'recommend' : 'following') ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.feedMode === (idx === 0 ? 'recommend' : 'following') ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                if (this.feedMode === (idx === 0 ? 'recommend' : 'following')) {
                  Divider().width(24).height(2).color($r('app.color.brand_primary'))
                }
              }
              .onClick(() => {
                const mode: FeedMode = idx === 0 ? 'recommend' : 'following';
                this.switchFeed(mode);
              })
            }, (name: string) => name)
          }
          .alignItems(VerticalAlign.Center)

          Blank()

          // 右侧搜索入口（点击打开全屏搜索面板）
          Row() {
            Text('搜索')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .width(140)
          .height(34)
          .backgroundColor($r('app.color.bg_secondary'))
          .borderRadius(17)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.showPanel = true;
          })
        }
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 12, top: 8, bottom: 8 })
        .width('100%')

        // 标签筛选栏
        TagNav({
          tags: this.displayTags,
          selectedIndex: $tagIndex
        })
        .padding({ bottom: 8 })

        // 列表区
        if (this.needLogin) {
          // 未登录引导态（关注流且未登录）：不发起请求，引导登录
          Column({ space: 12 }) {
            Text('🔐')
              .fontSize(40)
              .fontColor($r('app.color.text_secondary'))
              .margin({ bottom: 4 })
            Text('登录后查看你关注的人发布的帖子')
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.Center)
            Text('关注的人发了什么，这里第一时间看到')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
            Button('登录')
              .margin({ top: 12 })
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
              })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.posts.length === 0 && this.loading) {
          Column() {
            LoadingProgress().width(28).height(28)
            Text('加载中…').fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 10 })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.posts.length === 0) {
          Column() {
            if (this.error) {
              Text('⚠️')
                .fontSize(36)
                .fontColor($r('app.color.text_secondary'))
                .margin({ bottom: 8 })
              Text('加载失败：' + this.error)
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 8 })
              Button('重试')
                .margin({ top: 16 })
                .onClick(() => {
                  this.refresh();
                })
            } else if (this.feedMode === 'following') {
              // 关注流空态 A/B 区分：按 followingCount 判定
              if (this.followingCount === 0) {
                // 空态 A：未关注任何人
                Text('🧭')
                  .fontSize(40)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ bottom: 4 })
                Text('你还没有关注任何人')
                  .fontSize(15)
                  .fontColor($r('app.color.text_primary'))
                  .textAlign(TextAlign.Center)
                Text('去发现有趣的人，关注后这里就有内容')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .textAlign(TextAlign.Center)
                  .margin({ top: 4 })
                Button('去发现')
                  .margin({ top: 12 })
                  .onClick(() => {
                    // 跳转到底部「圈子」Tab（CircleTab），在此发现有趣的人/圈子
                    emitTabSwitch(1);
                  })
              } else {
                // 空态 B：关注了人但无人发帖
                Text('📭')
                  .fontSize(40)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ bottom: 4 })
                Text('你关注的人还没有发布内容')
                  .fontSize(15)
                  .fontColor($r('app.color.text_primary'))
                  .textAlign(TextAlign.Center)
                Text('去他们的主页催更吧～')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .textAlign(TextAlign.Center)
                  .margin({ top: 4 })
              }
            } else {
              Text('暂无内容')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          Refresh({ refreshing: this.isRefreshing, builder: this.refreshBuilder }) {
            Grid() {
              LazyForEach(
                this.postSource,
                (post: Post, idx: number) => {
                  GridItem() {
                    PostCard({ post: post })
                      .transition(TransitionEffect.OPACITY
                        .animation({ duration: 350, curve: Curve.EaseOut })
                        .combine(TransitionEffect.translate({ y: 12 })
                          .animation({ duration: 400, curve: Curve.EaseOut })))
                      .onClick(() => {
                        if (post.id !== undefined) {
                          const id = post.id.toString();
                          AppStorage.setOrCreate('detailPostId', id);
                          setDetailPostId(id);
                          this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
                        }
                      })
                  }
                },
                (post: Post, idx: number) => (post.id ?? idx).toString()
              )
              if (this.finished) {
                GridItem() {
                  Text('没有更多了')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding(16)
                }
                .columnStart(0)
                .columnEnd(1)
              }
            }
            .columnsTemplate('1fr 1fr')
            .columnsGap(12)
            .rowsGap(12)
            .padding(12)
            .onScrollIndex((_start: number, end: number) => {
              if (end >= this.posts.length - 1) {
                this.loadMore();
              }
            })
          }
          .onRefreshing(() => {
            this.isRefreshing = true;
            this.refresh().finally(() => {
              this.isRefreshing = false;
            });
          })
          .layoutWeight(1)
          .width('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_primary'))
  }
}
