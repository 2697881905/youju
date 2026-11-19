// 发现圈子独立页：内容橱窗（发现）+ 已加入，两个页签。
//
// 设计依据：docs/superpowers/specs/2026-11-20-circle-discover-redesign-design.md
// - 定位是「发现」不是目录：首屏三张内容橱窗卡，分类索引退到其后
// - 已加入从弹窗并进来（原 JoinedCirclesDialog），减少一个浮层入口
// - 组件优先官方：分段栏 ImmersiveSegmentBar / 返回 BackButton / 图标钮 IconButton /
//   空态 EmptyState；卡片与构成条是自有组件（官方没有对应的「内容构成」控件）
import {
  CircleOverview,
  CircleOverviewItem,
  CitySummary,
  followTag,
  getCircleOverview,
  listCities,
} from '../services/api';
import { CircleCreateSheet, CircleCreatedPayload } from '../components/CircleCreateSheet';
import {
  getSheetImmersiveMaterial,
  isSystemMaterialActive,
} from '../utils/immersiveMaterial';
import { getToken } from '../utils/auth';
import { CircleShowcaseCard } from '../components/CircleShowcaseCard';
import { TagIcon } from '../components/TagIcon';
import { BackButton } from '../design/components/BackButton';
import { IconButton } from '../design/components/IconButton';
import { EmptyState } from '../design/components/EmptyState';
import { ImmersiveSegmentBar, SegmentedItem } from '../design/components/ImmersiveSegmentBar';
import { ToggleChip } from '../design/components/ToggleChip';
import { PublishPageShell, PUBLISH_BAR_ROW_VP } from '../components/PublishPageShell';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { TypeTokens } from '../design/tokens/type';
import {
  EmptyNavParams,
  getMainNavStack,
  openCircleDetailViaNav,
} from '../utils/navigationTransition';
import { safeShowToast } from '../utils/toast';

interface CategoryGroup {
  category: string;
  items: CircleOverviewItem[];
}

const CATEGORY_FALLBACK: string = '其他';

@Component
export struct CircleDiscoverPage {
  // 0 = 发现，1 = 已加入（星图标题栏两颗药丸各自指定落点）
  @Prop initialTab: number = 0;
  onBack: () => void = (): void => {};

  @State segIndex: number = 0;
  @State loading: boolean = false;
  @State error: string = '';
  @State circles: CircleOverviewItem[] = [];
  @State searchVisible: boolean = false;
  @State keyword: string = '';
  // 正在加入的圈子名：卡片的「加入中」态与重复点击闸门
  @State joiningName: string = '';
  // 同城区块：进入页面只拉城市列表，选中某城才请求该城圈子（省一次首屏请求）
  @State cities: CitySummary[] = [];
  @State cityCode: string = '';
  @State cityCircles: CircleOverviewItem[] = [];
  @State cityLoading: boolean = false;
  // 建圈半模态（本页唯一的 bindSheet）
  @State createVisible: boolean = false;
  // 分类默认每组只露 3 行：24 个圈子全铺开要滑三屏，等于把「索引」当成了主内容
  @State expandedCategory: string = '';
  @StorageLink('isDarkMode') isDarkMode: boolean = false;
  // PublishPageShell 要求：同一个 Scroller 既给外壳 bindToScrollable、又挂 Scroll（外壳普通属性接）
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  private scroller: Scroller = new Scroller();


  private segItems: SegmentedItem[] = [
    { key: 'discover', label: '发现' },
    { key: 'joined', label: '已加入' },
  ];

  aboutToAppear(): void {
    this.segIndex = this.initialTab === 1 ? 1 : 0;
    this.load();
    this.loadCities();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const overview: CircleOverview = await getCircleOverview('main');
      this.circles = overview.circles;
    } catch (e) {
      this.error = (e as Error).message;
    } finally {
      this.loading = false;
    }
  }

  // —— 派生数据（@Builder 内禁 let/const，全部放在方法里）——

  private matched(): CircleOverviewItem[] {
    const kw: string = this.keyword.trim();
    if (kw.length === 0) {
      return this.circles;
    }
    return this.circles.filter((item: CircleOverviewItem): boolean =>
      item.name.indexOf(kw) >= 0 || item.category.indexOf(kw) >= 0 || item.description.indexOf(kw) >= 0);
  }

  // 推荐位：未加入 + 非同城圈，取前 3。
  // 活跃的排前面，不足时用其余未加入圈子补足——冷启动期线上可能一个活跃圈子都没有，
  // 若强制 active7d 会让首屏只剩分类列表，回到「目录」的老样子。
  private recommended(): CircleOverviewItem[] {
    const pool: CircleOverviewItem[] = this.matched().filter((item: CircleOverviewItem): boolean =>
      !item.joined && item.cityCode.length === 0);
    const active: CircleOverviewItem[] = pool.filter((item: CircleOverviewItem): boolean => item.active7d);
    const quiet: CircleOverviewItem[] = pool.filter((item: CircleOverviewItem): boolean => !item.active7d);
    return active.concat(quiet).slice(0, 3);
  }

  private joinedItems(): CircleOverviewItem[] {
    return this.matched().filter((item: CircleOverviewItem): boolean => item.joined);
  }

  private unreadTotal(): number {
    let total: number = 0;
    this.joinedItems().forEach((item: CircleOverviewItem): void => { total += item.unread; });
    return total;
  }

  private categoryGroups(): CategoryGroup[] {
    const order: string[] = [];
    const map: Map<string, CircleOverviewItem[]> = new Map();
    this.matched().forEach((item: CircleOverviewItem): void => {
      const key: string = item.category.length > 0 ? item.category : CATEGORY_FALLBACK;
      const bucket: CircleOverviewItem[] | undefined = map.get(key);
      if (bucket === undefined) {
        map.set(key, [item]);
        order.push(key);
      } else {
        bucket.push(item);
      }
    });
    return order.map((category: string): CategoryGroup => ({
      category,
      items: map.get(category) ?? [],
    }));
  }

  private memberText(count: number): string {
    if (count >= 10000) {
      return (count / 10000).toFixed(1) + ' 万人';
    }
    return String(count) + ' 人';
  }

  // 分类行元信息：体裁构成（近 7 天）优先，没数据时退回人数
  private rowMeta(item: CircleOverviewItem): string {
    const mix = item.contentMix;
    if (mix !== undefined) {
      const parts: string[] = [];
      if (mix.review > 0) {
        parts.push(String(mix.review) + ' 测评');
      }
      if (mix.pitfall > 0) {
        parts.push(String(mix.pitfall) + ' 踩坑');
      }
      if (mix.tutorial > 0) {
        parts.push(String(mix.tutorial) + ' 教程');
      }
      if (parts.length > 0) {
        return parts.join(' · ') + ' · ' + this.memberText(item.memberCount);
      }
    }
    return this.memberText(item.memberCount);
  }

  private async join(name: string): Promise<void> {
    if (this.joiningName.length > 0) {
      return;
    }
    // 未登录先引导登录（现状只弹 toast 不给入口，是漏洞）：沿用详情页 toggleJoin 的范式
    if (getToken() === '') {
      const nav: NavPathStack | null = getMainNavStack();
      if (nav !== null) {
        nav.pushPathByName('Login', new EmptyNavParams());
        return;
      }
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.joiningName = name;
    try {
      await followTag(name);
      const target: CircleOverviewItem | undefined =
        this.circles.find((item: CircleOverviewItem): boolean => item.name === name);
      if (target !== undefined) {
        target.joined = true;
        target.memberCount = target.memberCount + 1;
        this.circles = this.circles.slice();
      }
      const version: number = AppStorage.get<number>('circleMembershipVersion') ?? 0;
      AppStorage.setOrCreate('circleMembershipVersion', version + 1);
      safeShowToast(this.getUIContext(), { message: '已加入「' + name + '」' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '加入失败：' + (e as Error).message });
    } finally {
      this.joiningName = '';
    }
  }

  private async loadCities(): Promise<void> {
    try {
      this.cities = await listCities();
    } catch (e) {
      // 城市列表失败不阻塞主流程：同城区块整块不显示
      this.cities = [];
    }
  }

  private async pickCity(code: string): Promise<void> {
    if (this.cityCode === code) {
      this.cityCode = '';
      this.cityCircles = [];
      return;
    }
    this.cityCode = code;
    this.cityLoading = true;
    this.cityCircles = [];
    try {
      const overview: CircleOverview = await getCircleOverview('city', code);
      this.cityCircles = overview.circles.slice(0, 3);
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '同城圈子加载失败' });
    } finally {
      this.cityLoading = false;
    }
  }

  // 建圈成功：本地插入并切到「已加入」。不 pop 回星图——
  // 跨页接管编舞需要额外的一次性信号通道，留到后续单独做；此处只广播版本号让星图下次刷新可见。
  private handleCreated(payload: CircleCreatedPayload): void {
    this.createVisible = false;
    const item: CircleOverviewItem = {
      name: payload.name,
      emoji: payload.emoji,
      category: payload.category,
      cityCode: '',
      description: payload.description,
      memberCount: payload.memberCount,
      joined: true,
      creatorId: payload.creatorId,
      weight: 2,
      unread: 0,
      active7d: false,
      lastPostAt: null,
      latestPosts: [],
    };
    this.circles = [item].concat(this.circles);
    this.segIndex = 1;
    const version: number = AppStorage.get<number>('circleMembershipVersion') ?? 0;
    AppStorage.setOrCreate('circleMembershipVersion', version + 1);
    safeShowToast(this.getUIContext(), { message: '「' + payload.name + '」已创建，去发第一帖吧' });
  }

  private openCreate(): void {
    if (getToken() === '') {
      const nav: NavPathStack | null = getMainNavStack();
      if (nav !== null) {
        nav.pushPathByName('Login', new EmptyNavParams());
        return;
      }
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.createVisible = true;
  }

  // —— 区块 ——

  @Builder
  eyebrow(text: string): void {
    Text(text)
      .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.headline.weight)
      .fontColor(ColorTokens.quaternary)
      .letterSpacing(1)
      .margin({ top: SpaceTokens.md, bottom: SpaceTokens.xs })
  }

  @Builder
  catalogRow(item: CircleOverviewItem): void {
    Row({ space: SpaceTokens.md }) {
      Column() {
        TagIcon({ name: item.name, category: item.category, iconSize: 18 })
      }
      .width(32)
      .height(32)
      .backgroundColor(ColorTokens.elevated)
      .border({ width: LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.sm)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 2 }) {
        Text(item.name)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.rowMeta(item))
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(TypeTokens.callout.size)
        .fontColor(ColorTokens.quaternary)
    }
    .width('100%')
    .height(58)
    .alignItems(VerticalAlign.Center)
    .onClick((): void => { openCircleDetailViaNav(item.name); })
  }

  private visibleItems(group: CategoryGroup): CircleOverviewItem[] {
    if (this.expandedCategory === group.category || group.items.length <= 3) {
      return group.items;
    }
    return group.items.slice(0, 3);
  }

  @Builder
  groupHeader(group: CategoryGroup): void {
    Row() {
      Text(group.category)
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.quaternary)
        .letterSpacing(1)
      Blank()
      if (group.items.length > 3) {
        Text(this.expandedCategory === group.category ? '收起' : '全部 ' + String(group.items.length))
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.brand)
      }
    }
    .width('100%')
    .padding({ top: SpaceTokens.md, bottom: SpaceTokens.xs })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      if (group.items.length > 3) {
        this.expandedCategory = this.expandedCategory === group.category ? '' : group.category;
      }
    })
  }

  @Builder
  citySection(): void {
    Column({ space: SpaceTokens.sm }) {
      this.eyebrow('同城圈子')
      Scroll() {
        Row({ space: SpaceTokens.sm }) {
          ForEach(this.cities, (city: CitySummary) => {
            ToggleChip({
              label: city.name,
              selected: this.cityCode === city.code,
              outlined: true,
              action: (): void => { this.pickCity(city.code); },
            })
          }, (city: CitySummary) => city.code)
        }
        .padding({ right: SpaceTokens.md })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      if (this.cityLoading) {
        Row() {
          LoadingProgress().width(20).height(20).color(ColorTokens.brand)
        }
        .padding({ top: SpaceTokens.sm })
      } else if (this.cityCode.length > 0) {
        if (this.cityCircles.length > 0) {
          ForEach(this.cityCircles, (item: CircleOverviewItem) => {
            this.catalogRow(item)
          }, (item: CircleOverviewItem) => 'city-' + item.name)
        } else {
          Text('这座城市还没有圈子')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
            .padding({ top: SpaceTokens.sm })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  createEntry(): void {
    Row({ space: SpaceTokens.md }) {
      Text('＋')
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.warm)
      Text('点亮一颗新星')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.primary)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: SpaceTokens.md, bottom: SpaceTokens.md })
    .margin({ top: SpaceTokens.md })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => { this.openCreate(); })
  }

  @Builder
  createSheetContent(): void {
    CircleCreateSheet({
      onCreated: (payload: CircleCreatedPayload): void => { this.handleCreated(payload); },
      onCancel: (): void => { this.createVisible = false; },
    })
  }

  @Builder
  discoverTab(): void {
    Scroll(this.scroller) {
      Column() {
        if (this.recommended().length > 0) {
          this.eyebrow('为你挑的')
          ForEach(this.recommended(), (item: CircleOverviewItem) => {
            CircleShowcaseCard({
              item,
              isDarkMode: this.isDarkMode,
              joining: this.joiningName === item.name,
              onOpen: (): void => { openCircleDetailViaNav(item.name); },
              onJoin: (): void => { this.join(item.name); },
            })
              .margin({ bottom: SpaceTokens.sm })
          }, (item: CircleOverviewItem) => item.name)
        } else if (!this.loading && this.circles.length > 0) {
          // 都加入了 / 近 7 天没有活跃圈子：不硬凑卡片，直接给一句说明
          Text('暂时没有新的活跃圈子，先看分类吧')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
            .margin({ top: SpaceTokens.md })
        }

        if (this.cities.length > 0) {
          this.citySection()
        }

        ForEach(this.categoryGroups(), (group: CategoryGroup) => {
          this.groupHeader(group)
          ForEach(this.visibleItems(group), (item: CircleOverviewItem) => {
            this.catalogRow(item)
            Divider().color(ColorTokens.separator).strokeWidth(LayoutTokens.hairlineWidth)
          }, (item: CircleOverviewItem) => item.name)
        }, (group: CategoryGroup) => group.category)

        this.createEntry()
      }
      .width('100%')
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: SpaceTokens.x3l })
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.TopStart)
  }

  @Builder
  joinedTab(): void {
    Scroll(this.scroller) {
      Column() {
        this.eyebrow(String(this.joinedItems().length) + ' 个圈子 · '
          + String(this.unreadTotal()) + ' 条未读')
        ForEach(this.joinedItems(), (item: CircleOverviewItem) => {
          Row({ space: SpaceTokens.md }) {
            Column() {
              TagIcon({ name: item.name, category: item.category, iconSize: 18 })
            }
            .width(36)
            .height(36)
            .backgroundColor(ColorTokens.elevated)
            .border({ width: LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.sm)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)

            Column({ space: 2 }) {
              Text(item.name)
                .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.headline.weight)
                .fontColor(ColorTokens.primary)
              Text(this.memberText(item.memberCount) + (item.active7d ? ' · 近 7 天有新帖' : ''))
                .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.tertiary)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            if (item.unread > 0) {
              Text(String(item.unread))
                .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.onBrand)
                .backgroundColor(ColorTokens.brandSolid)
                .borderRadius(RadiusTokens.pill)
                .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            }
            Text('›')
              .fontSize(TypeTokens.callout.size)
              .fontColor(ColorTokens.quaternary)
          }
          .width('100%')
          .padding({ top: SpaceTokens.md, bottom: SpaceTokens.md })
          .alignItems(VerticalAlign.Center)
          .onClick((): void => { openCircleDetailViaNav(item.name); })
        }, (item: CircleOverviewItem) => item.name)

        if (this.joinedItems().length === 0) {
          EmptyState({
            icon: $r('app.media.empty_inbox'),
            title: '还没加入圈子',
            message: '去「发现」看看最近活跃的圈子',
            actionLabel: '去发现',
            onAction: (): void => { this.segIndex = 0; },
          })
            .margin({ top: SpaceTokens.x3l })
        }
      }
      .width('100%')
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: SpaceTokens.x3l })
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.TopStart)
  }

  // 让位量：外壳 enableComponentSafeArea=false，内容从窗口原点起算，
  // 必须自己补 statusBar + 栏体高（同三个发布页的 topInset 算法）。
  private topInset(): number {
    return this.statusBarHeight + PUBLISH_BAR_ROW_VP + SpaceTokens.sm;
  }

  build() {
    Stack() {
      PublishPageShell({
        modeLabel: '发现圈子',
        actionIcon: this.searchVisible ? 'close' : 'search',
        actionA11y: this.searchVisible ? '关闭搜索' : '搜索圈子',
        scroller: this.scroller,
        onAction: (): void => { this.searchVisible = !this.searchVisible; },
        onBack: (): void => { this.onBack(); },
      }) {
        Column() {
          Row().height(this.topInset()).width('100%')

          if (this.searchVisible) {
            Search({ value: this.keyword, placeholder: '搜圈子名或分类' })
              .height(40)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .margin({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: SpaceTokens.sm })
              .onChange((value: string): void => { this.keyword = value; })
          }

          Row() {
            ImmersiveSegmentBar({ items: this.segItems, selectedIndex: $segIndex, fillWidth: true })
          }
          .width('100%')
          .padding({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: SpaceTokens.sm })
          // 分段栏固定：给实色底，滚动内容滑到它下面时干净截断，不会露半行
          .backgroundColor(ColorTokens.canvas)

          if (this.loading && this.circles.length === 0) {
            Column() {
              LoadingProgress().width(28).height(28).color(ColorTokens.brand)
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else if (this.error.length > 0) {
            Column() {
              EmptyState({
                icon: $r('app.media.status_warning'),
                title: '加载失败',
                message: this.error,
                actionLabel: '重试',
                onAction: (): void => { this.load(); },
              })
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
          } else if (this.segIndex === 0) {
            this.discoverTab()
          } else {
            this.joinedTab()
          }
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    // 半模态挂外层 Stack（外壳规格：不能挂在 TailBuilder 的组件上）
    .bindSheet($$this.createVisible, this.createSheetContent(), {
      detents: [SheetSize.FIT_CONTENT, SheetSize.LARGE],
      systemMaterial: getSheetImmersiveMaterial(),
      blurStyle: isSystemMaterialActive() ? BlurStyle.NONE : BlurStyle.COMPONENT_THICK,
      backgroundColor: isSystemMaterialActive() ? undefined : ColorTokens.canvas,
      showClose: true,
      dragBar: true,
    })
  }
}
