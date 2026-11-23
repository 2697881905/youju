import { LengthMetrics } from '@kit.ArkUI';
import { listSearchHistory, clearSearchHistory, listHotKeywords, listSearchSuggest } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { GlassPanel } from '../design/components/GlassPanel';
import { Pressable } from '../design/motion/Pressable';
import { IconButton } from '../design/components/IconButton';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { FloatingTopButtonMaterialModifier, isSystemMaterialActive, isImmersiveLightSenseSupported, HDS_MATERIAL_TYPE_IMMERSIVE, HDS_MATERIAL_LEVEL_EXQUISITE } from '../utils/immersiveMaterial';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import type {
  HdsNavigationTitleBarOptions,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  SystemMaterialParams,
  ScrollEffectOptions,
  HdsNavigationBackButtonItemOptions,
  HdsNavigationIconOptions,
} from '@kit.UIDesignKit';

// 搜索框 / 返回按钮的标准控件高度：与系统搜索栏一致。
// 原生 Search 不显式定高时整体偏高（且返回按钮会跟着放大），故统一收敛到标准值。
const SEARCH_FIELD_HEIGHT: number = 40;
// 官方返回键占 16~56vp（40vp 圆 + 16vp 左内缩）；stackBuilder 那行是全宽的且 z 序在返回键之上，
// 不留开就会吃掉它的点击（配方同 SearchResultPage / 基准 §7.6.31）
const HDS_BACK_SLOT_END_VP: number = 64;

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
  // 系统材质修饰器（沉浸光感）：标题栏内的搜索框、返回与搜索按钮共用（低版本自动跳过）。
  // 用带投影的一份：这条工具栏驻留自带留白的 Navigation 标题栏，不会被 HdsNavigation
  // 那种窄行裁切，而纯白画布上无投影的材质表面只差 2 级灰度，浮不起来。
  private titleBarMaterial: FloatingTopButtonMaterialModifier = new FloatingTopButtonMaterialModifier();
  // 内容区滚动源（交给 HdsNavigation.bindToScrollable 驱动栏体渐变模糊）：没有它栏后拿不到
  // 内容可采样，浅色画布上材质表面只差 2~3 级看不出（配方同 SearchResultPage.ets:410）。
  private panelScroller: Scroller = new Scroller();

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
  // 搜索按钮不再走 Search 自带的 searchButton：它是搜索框内部的文字子节点，
  // systemMaterial 只接管组件自身表面、管不到内部子节点，永远拿不到沉浸光感
  // （同 docs/tutorial-titlebar-immersive-light.md 案例 4）。改由标题栏右侧的
  // 独立原生 Button 承载，与返回键同一块材质表面。
  @Builder
  searchInput(): void {
    Search({ placeholder: '搜索你关心的经验和问题', value: this.keyword })
      .layoutWeight(1)
      .height(SEARCH_FIELD_HEIGHT)
      // 关键：底色写在材质之前 —— 材质生效时由系统强制清除为透明（官方行为），
      // 避免「Search 自带默认材质 + 我们叠加的材质」双层玻璃；低版本则作为兜底底色。
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      // 沉浸光感：标题栏内由系统材质接管搜索框表面（低版本自动跳过，保留系统默认样式）
      .attributeModifier(this.titleBarMaterial)
      .onChange((v: string): void => {
        // 必须回写 keyword：搜索按钮是标题栏里的独立 Button，走 doSearch() 读 this.keyword，
        // 不再由 Search 自带的 searchButton 触发 onSubmit 传值（那样只有回车一条路能拿到关键词）。
        // 清除 × 也经这里把 keyword 收回空串。
        this.keyword = v;
        this.debounceSuggest(v);
      })
      .onSubmit((v: string): void => {
        this.keyword = v;
        this.doSearch();
      })
      .onFocus((): void => { this.handleInputFocus(true); })
      .onBlur((): void => { this.handleInputFocus(false); })
  }

  // 搜索按钮：与返回键同构的原生 Button，驻留标题栏（沉浸光感官方生效区）挂同一块材质，
  // interactive 形变由系统承担。低版本门禁不通过 → 回退描边胶囊（与分段栏 outlined 同款）。
  @Builder
  private searchSubmitButton(): void {
    Button('搜索', { type: ButtonType.Normal, stateEffect: true })
      .fontSize(TypeTokens.callout.size)
      .fontWeight(TypeTokens.headline.weight)
      .fontColor(ColorTokens.brand)
      .height(SEARCH_FIELD_HEIGHT)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      // 视觉与搜索框同高，触控热区仍保持 44（与全局 minTouchTarget 一致）
      .responseRegion({
        x: (SEARCH_FIELD_HEIGHT - LayoutTokens.minTouchTarget) / 2,
        y: (SEARCH_FIELD_HEIGHT - LayoutTokens.minTouchTarget) / 2,
        width: LayoutTokens.minTouchTarget,
        height: LayoutTokens.minTouchTarget,
      })
      .backgroundColor(Color.Transparent)
      // 材质生效时自绘描边让位（否则与材质叠成第二圈描边，见教程案例 4）
      .border({
        width: isSystemMaterialActive() ? 0 : LayoutTokens.glassBorderWidth,
        color: ColorTokens.barBorder,
        style: BorderStyle.Solid,
      })
      .borderRadius(RadiusTokens.lg)
      .attributeModifier(this.titleBarMaterial)
      .accessibilityText('搜索')
      .onClick((): void => { this.doSearch(); })
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

  // 标题栏：官方返回键（backIcon，见 searchTitleBarOptions）+ 系统原生搜索框 + 独立搜索按钮。
  // 修复（测试反馈「搜索面板顶部未做沉浸光感适配」）：返回钮由自绘 Button 改为 HdsNavigation
  // 官方 backIcon（40vp 玻璃圆，配方同 SearchResultPage）——深色实测自绘钮 35 vs 官方圆 31，
  // 两者材质链路不同源；工具行左内缩 HDS_BACK_SLOT_END_VP 让开官方返回键的点击热区（z 序更高）。
  // 搜索框/搜索按钮材质与触控行为保持不变。
  @Builder
  private searchTitleBar(): void {
    Row({ space: SpaceTokens.inline }) {
      this.searchInput()
      this.searchSubmitButton()
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: HDS_BACK_SLOT_END_VP,
      right: SpaceTokens.sm,
    })
  }

  // HdsNavigation 标题栏配置（配方同 SearchResultPage，基准 §7.6.31）：
  // MINI + 官方 backIcon（返回行为走 onCancel）+ stackBuilder 工具行（搜索框+搜索按钮）
  // + 栏级 EXQUISITE 沉浸光感（官方生效区，材质出图）。
  private searchTitleBarOptions(): HdsNavigationTitleBarOptions {
    const immersive: boolean = isImmersiveLightSenseSupported();
    // 滚动模糊类型与结果页同口径：低版本（无沉浸光感）回退 GRADIENT_BLUR，
    // 之前写死 IMMERSIVE_GRADIENT_BLUR 没有门禁，是与结果页的一处差异。
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: immersive ? ScrollEffectType.IMMERSIVE_GRADIENT_BLUR : ScrollEffectType.GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(32),
    };
    const content: TitleBarContentOptions = {
      stackBuilder: (): void => { this.searchTitleBar(); },
    };
    // backIcon 带 action 槽 → 返回行为原样保留（onCancel），触控与无障碍由官方组件承担
    const backContent: HdsNavigationIconOptions = {
      icon: resolveActionIcon('back'),
      label: '返回',
      action: (): void => { this.onCancel(); },
    };
    const backIcon: HdsNavigationBackButtonItemOptions = backContent;
    content.backIcon = backIcon;
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: {
        backgroundStyle: { backgroundColor: Color.Transparent },
      },
    };
    if (immersive) {
      style.systemMaterialEffect = {
        materialType: HDS_MATERIAL_TYPE_IMMERSIVE,
        materialLevel: HDS_MATERIAL_LEVEL_EXQUISITE,
      } as SystemMaterialParams;
    }
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      // 内容从栏下开始、不穿底（与结果页同口径）：联想/历史卡片是白色表面，穿底无收益
      enableComponentSafeArea: true,
    };
    return options;
  }

  build() {
    // 根容器：HdsNavigation（沉浸光感官方生效区，见 searchTitleBarOptions）——标题栏走
    // titleBar(options)，状态栏避让由栏体承担（avoidLayoutSafeArea）；内容区从栏下开始。
    // 内容区包进 Scroll 并经 bindToScrollable 挂给栏体：为栏体引入可采样滚动源
    // （结果页配方，SearchResultPage.ets:409-410——没有它，栏后拿不到内容可采样，
    // 浅色画布上材质表面只差 2~3 级看不出）。
    HdsNavigation() {
      Scroll(this.panelScroller) {
      Column() {
        if (this.loadingState) {
        Column() {
          LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
        }
        .width('100%')
        .height('100%')
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
                  IconButton({ icon: 'trash', a11yText: '清空搜索历史', action: (): void => { this.clearHistory(); } })
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
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      }
      .width('100%')
      }
      // 画布色铺满 Scroll 视口（内容不足一屏时视口下部不露透底）
      .backgroundColor(ColorTokens.canvas)
      // 滚动容器自身的越界回弹交给热搜 Grid（alwaysEnabled Spring）承担，外层不再叠加
      .edgeEffect(EdgeEffect.None)
    }
    .mode(NavigationMode.Stack)
    .titleBar(this.searchTitleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    // 渐变模糊的滚动源：没有它，栏后拿不到内容可采样，材质在纯白画布上只差 2~3 级看不出
    .bindToScrollable([this.panelScroller])
    // 与结果页同构——HdsNavigation 自身不裁切（结果页同款属性），
    // 排除栏体裁切对材质渲染链路的干扰
    .clip(false)
    .width('100%')
    .height('100%')
  }
}