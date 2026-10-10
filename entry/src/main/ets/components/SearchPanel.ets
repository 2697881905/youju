import { LengthMetrics } from '@kit.ArkUI';
import { listSearchHistory, clearSearchHistory, listHotKeywords, listSearchSuggest } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { GlassPanel } from '../design/components/GlassPanel';
import { Pressable } from '../design/motion/Pressable';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { TopButtonMaterialModifier } from '../utils/immersiveMaterial';

// 搜索框 / 返回按钮的标准控件高度：与系统搜索栏一致。
// 原生 Search 不显式定高时整体偏高（且返回按钮会跟着放大），故统一收敛到标准值。
const SEARCH_FIELD_HEIGHT: number = 40;

// 首页内的搜索探索页：玻璃工具栏 + 最近搜索 + 双列热搜。
// 选项胶囊/格子复用首页「推荐/关注」分段栏的 outlined 风格：透明底 + 细边框 + 大圆角 + 无阴影。
// 顶部工具栏（返回 + 搜索框 + 搜索按钮）驻留 Navigation 标题栏 —— uiMaterial 沉浸光感的官方生效区域；
// 下方联想/最近搜索/热搜为内容区。
@Component
export struct SearchPanel {
  onKeywordSelect: (keyword: string) => void = (keyword: string) => {};
  onCancel: () => void = () => {};

  // 全屏沉浸式布局下标题栏不代为避让状态栏：由标题栏 Builder 手动下移
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  // 系统材质修饰器（沉浸光感）：标题栏内的搜索框与返回按钮共用（低版本自动跳过）
  private titleBarMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();

  @State keyword: string = '';
  @State suggestions: string[] = []; // 搜索联想（输入时防抖拉取）
  @State historyList: string[] = [];
  @State hotList: string[] = [];
  @State loadingState: boolean = true;
  @State inputFocused: boolean = false; // 输入框聚焦（键盘弹出）时隐藏历史/热词，避免与联想卡粘连
  private suggestTimer: number = 0; // 联想防抖句柄

  // 卸载时清掉在途的防抖：否则回调会在已销毁的组件上写 suggestions，
  // 甚至继续发起 listSearchSuggest 请求。
  aboutToDisappear(): void {
    if (this.suggestTimer !== 0) {
      clearTimeout(this.suggestTimer);
      this.suggestTimer = 0;
    }
  }

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loadingState = true;
    try {
      this.historyList = await listSearchHistory();
      this.hotList = await listHotKeywords(10);
    } catch (e) {
      this.historyList = [];
      this.hotList = [];
    } finally {
      this.loadingState = false;
    }
  }

  private doSearch(): void {
    const kw: string = this.keyword.trim();
    if (kw === '') {
      safeShowToast(this.getUIContext(), { message: '请输入搜索内容' });
      return;
    }
    this.clearSuggestions();
    this.onKeywordSelect(kw);
  }

  private clearSuggestions(): void {
    if (this.suggestTimer !== 0) {
      clearTimeout(this.suggestTimer);
      this.suggestTimer = 0;
    }
    this.suggestions = [];
  }

  async clearHistory(): Promise<void> {
    try {
      await clearSearchHistory();
      this.historyList = [];
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '清除失败，请重试' });
    }
  }

  private rankColor(index: number): ResourceColor {
    if (index === 0) return '#FF3B30';
    if (index === 1) return '#FF9500';
    if (index === 2) return '#34C759';
    return ColorTokens.tertiary;
  }

  private visibleHotKeywords(): string[] {
    return this.hotList.slice(0, 10);
  }

  private hotGridHeight(): number {
    const rows: number = Math.ceil(this.visibleHotKeywords().length / 2);
    if (rows === 0) {
      return 0;
    }
    return rows * LayoutTokens.segmentedHeight + (rows - 1) * SpaceTokens.sm;
  }

  // 输入防抖拉取联想（300ms；失败/无结果静默清空）
  private debounceSuggest(value: string): void {
    if (this.suggestTimer !== 0) {
      clearTimeout(this.suggestTimer);
      this.suggestTimer = 0;
    }
    if (value.trim().length === 0) {
      this.suggestions = [];
      return;
    }
    this.suggestTimer = setTimeout((): void => {
      this.suggestTimer = 0;
      const kw: string = value.trim();
      listSearchSuggest(kw)
        .then((list: string[]): void => {
          this.suggestions = list;
        })
        .catch((e: Error): void => {
          this.suggestions = [];
        });
    }, 300) as number;
  }

  // 输入框聚焦/失焦共用处理（历史/热词卡片的显隐由 inputFocused 驱动）
  private handleInputFocus(focused: boolean): void {
    this.inputFocused = focused;
    if (focused) {
      // 聚焦时恢复联想：失焦清空了 suggestions，若有已输入关键词则重新拉取
      const kw: string = this.keyword.trim();
      if (kw.length > 0) {
        this.debounceSuggest(kw);
      }
    } else {
      // 失焦（返回键收起键盘等）清空联想，避免与历史/热词卡片粘连
      this.clearSuggestions();
    }
  }

  // 搜索框：ArkUI 原生 Search 组件，**纯默认样式**。
  // 工程 targetSdk 已升 26 —— Search 的默认背景材质/圆角/阴影即 H7 原生设计，
  // 由系统按设备版本渲染；此前「老样式」观感源于旧 targetSdk 24 编译 + 自拍覆盖值。
  // 现在只保留两处必要覆盖：① 高度取标准控件高度（原生默认偏高）；② 底色写在材质之前
  // （让系统材质把它清除为透明，避免与 Search 自带默认材质叠加成双层玻璃）。
  @Builder
  searchInput(): void {
    // 系统原生搜索框：集成搜索按钮（searchButton）——不再另放一颗方形搜索按钮。
    // 排版完全用系统默认（不做字体覆盖）；高度取标准控件高度。
    Search({ placeholder: '搜索你关心的经验和问题', value: this.keyword })
      .layoutWeight(1)
      .height(SEARCH_FIELD_HEIGHT)
      .searchButton('搜索')
      // 关键：底色写在材质之前 —— 材质生效时由系统强制清除为透明（官方行为），
      // 避免「Search 自带默认材质 + 我们叠加的材质」双层玻璃；低版本则作为兜底底色。
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      // 沉浸光感：标题栏内由系统材质接管搜索框表面（低版本自动跳过，保留系统默认样式）
      .attributeModifier(this.titleBarMaterial)
      .onChange((v: string): void => { this.debounceSuggest(v); })
      .onSubmit((v: string): void => {
        this.keyword = v;
        this.doSearch();
      })
      .onFocus((): void => { this.handleInputFocus(true); })
      .onBlur((): void => { this.handleInputFocus(false); })
  }

  // 选项胶囊：首页分段栏 outlined 同款（透明底 + 细边框 + 大圆角 + 无阴影），高度与分段栏一致
  @Builder
  private historyChip(keyword: string): void {
    Pressable({
      visualHeight: LayoutTokens.segmentedHeight,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: (): void => { this.onKeywordSelect(keyword); },
    }) {
      Row({ space: SpaceTokens.inlineTight }) {
        Image($r('app.media.history'))
          .width(IconTokens.compact)
          .height(IconTokens.compact)
          .fillColor(ColorTokens.icon)
        Text(keyword)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .fontColor(ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .height(LayoutTokens.segmentedHeight)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      .backgroundColor(Color.Transparent)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.lg)
      .alignItems(VerticalAlign.Center)
    }
  }

  // 标题栏总高：状态栏 + 上下内边距（各 xs 4）+ 标准控件高度
  private searchTitleBarHeight(): number {
    return this.statusBarHeight + SpaceTokens.xs * 2 + SEARCH_FIELD_HEIGHT;
  }

  // 标题栏：返回 + 系统原生搜索框（集成搜索按钮）——原顶部工具栏整体驻留于此
  @Builder
  private searchTitleBar(): void {
    Row({ space: SpaceTokens.inline }) {
      // 返回：系统原生 Button 组件（低版本保留细描边兜底，材质生效时由系统接管表面）。
      // 尺寸与搜索框统一为标准控件高度。
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Image(resolveActionIcon('back'))
          .width(IconTokens.small)
          .height(IconTokens.small)
          .fillColor(ColorTokens.icon)
      }
      .width(SEARCH_FIELD_HEIGHT)
      .height(SEARCH_FIELD_HEIGHT)
      // 视觉与搜索框同高，触控热区仍保持 44（与全局 minTouchTarget 一致）
      .responseRegion({
        x: (SEARCH_FIELD_HEIGHT - LayoutTokens.minTouchTarget) / 2,
        y: (SEARCH_FIELD_HEIGHT - LayoutTokens.minTouchTarget) / 2,
        width: LayoutTokens.minTouchTarget,
        height: LayoutTokens.minTouchTarget,
      })
      .backgroundColor(Color.Transparent)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.lg)
      .attributeModifier(this.titleBarMaterial)
      .accessibilityText('返回')
      .onClick((): void => { this.onCancel(); })

      this.searchInput()
    }
    .width('100%')
    // 不锁定行高：由搜索框原生高度 + 内边距决定（内容区即原生尺寸）。
    // 标题栏总高 = 状态栏 + 内边距 + 搜索框高度，与 Builder 的实际高度严格一致。
    .height(this.searchTitleBarHeight())
    .padding({
      left: SpaceTokens.sm,
      right: SpaceTokens.sm,
      top: this.statusBarHeight + SpaceTokens.xs,
      bottom: SpaceTokens.xs,
    })
  }

  build() {
    Navigation() {
      Column() {
        if (this.loadingState) {
        Column() {
          LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          // 搜索联想（输入时展示，置顶于历史/热词之上）
          if (this.suggestions.length > 0) {
            Column() {
              GlassPanel({ panelPadding: SpaceTokens.xs, radius: RadiusTokens.lg }) {
                Column({ space: SpaceTokens.none }) {
                  ForEach(this.suggestions, (kw: string, idx: number) => {
                    Pressable({
                      fillWidth: true,
                      visualHeight: LayoutTokens.minTouchTarget,
                      touchTargetHeight: LayoutTokens.minTouchTarget,
                      action: (): void => { this.onKeywordSelect(kw); },
                    }) {
                      Row({ space: SpaceTokens.inline }) {
                        Image($r('app.media.empty_search'))
                          .width(IconTokens.compact)
                          .height(IconTokens.compact)
                          .opacity(0.75)
                          .fillColor(ColorTokens.icon)
                        Text(kw)
                          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                          .fontColor(ColorTokens.primary)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Blank()
                        Text('搜索')
                          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                          .fontColor(ColorTokens.tertiary)
                      }
                      .width('100%')
                      .height(LayoutTokens.minTouchTarget)
                      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
                    }
                    if (idx < this.suggestions.length - 1) {
                      Divider()
                        .strokeWidth(LayoutTokens.hairlineWidth)
                        .color(ColorTokens.separator)
                        .margin({ left: SpaceTokens.md, right: SpaceTokens.md })
                    }
                  }, (kw: string, idx: number) => 'suggest-' + idx.toString() + '-' + kw)
                }
                .width('100%')
              }
            }
            .width('100%')
            .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.xs })
          }

          // 输入框聚焦（键盘弹出）时仅展示联想，隐藏最近搜索/大家都在搜，避免两张卡片粘连
          if (!this.inputFocused) {
          Column({ space: SpaceTokens.md }) {
            if (this.historyList.length > 0) {
              Column({ space: SpaceTokens.md }) {
                Row() {
                  Text('最近搜索')
                    .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
                    .fontWeight(TypeTokens.headline.weight)
                    .fontColor(ColorTokens.primary)
                  Blank()
                  Pressable({
                    visualHeight: LayoutTokens.segmentedHeight,
                    touchTargetHeight: LayoutTokens.minTouchTarget,
                    action: (): void => { this.clearHistory(); },
                  }) {
                    Image($r('app.media.set_trash'))
                      .width(IconTokens.compact)
                      .height(IconTokens.compact)
                      .fillColor(ColorTokens.icon)
                  }
                }
                .width('100%')
                // 换行容器：胶囊按实测宽度流式断行 —— 固定「每行 3 个」时长词整行溢出、短词留大片空白
                Flex({
                  wrap: FlexWrap.Wrap,
                  justifyContent: FlexAlign.Start,
                  space: { main: LengthMetrics.vp(SpaceTokens.inline), cross: LengthMetrics.vp(SpaceTokens.md) },
                }) {
                  ForEach(this.historyList.slice(0, 6), (kw: string) => {
                    this.historyChip(kw)
                  }, (kw: string) => 'history-' + kw)
                }
                .width('100%')
              }
              .width('100%')
              .padding(SpaceTokens.md)
            }

            Column({ space: SpaceTokens.md }) {
              Text('大家都在搜')
                .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
                .fontWeight(TypeTokens.headline.weight)
                .fontColor(ColorTokens.primary)
              if (this.visibleHotKeywords().length === 0) {
                Text('暂时没有热门搜索')
                  .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                  .fontColor(ColorTokens.secondary)
              } else {
                Grid() {
                  ForEach(this.visibleHotKeywords(), (kw: string, idx: number) => {
                    GridItem() {
                      Pressable({
                        fillWidth: true,
                        visualHeight: LayoutTokens.segmentedHeight,
                        touchTargetHeight: LayoutTokens.minTouchTarget,
                        action: (): void => { this.onKeywordSelect(kw); },
                      }) {
                        // 热搜格子：分段栏 outlined 同款（透明底 + 细边框 + 大圆角 + 无阴影）
                        Row({ space: SpaceTokens.sm }) {
                          Text(String(idx + 1))
                            .width(18)
                            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                            .fontWeight(TypeTokens.headline.weight)
                            .fontColor(this.rankColor(idx))
                          Text(kw)
                            .layoutWeight(1)
                            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                            .fontWeight(TypeTokens.callout.weight)
                            .fontColor(ColorTokens.primary)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }
                        .width('100%')
                        .height(LayoutTokens.segmentedHeight)
                        .padding({ left: SpaceTokens.md, right: SpaceTokens.sm })
                        .backgroundColor(Color.Transparent)
                        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
                        .borderRadius(RadiusTokens.lg)
                        .alignItems(VerticalAlign.Center)
                      }
                    }
                  }, (kw: string, idx: number) => 'hot-' + idx.toString() + '-' + kw)
                }
                .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
                .columnsTemplate('1fr 1fr')
                .columnsGap(SpaceTokens.sm)
                .rowsGap(SpaceTokens.sm)
                .width('100%')
                .height(this.hotGridHeight())
              }
            }
            .width('100%')
            .padding(SpaceTokens.md)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: 0, bottom: SpaceTokens.x3l })
          }
        }
        .layoutWeight(1)
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ColorTokens.canvas)
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(false)
    .title({
      builder: this.searchTitleBar,
      height: this.searchTitleBarHeight(),
    }, { barStyle: BarStyle.STANDARD, backgroundColor: ColorTokens.canvas })
    .width('100%')
    .height('100%')
  }
}