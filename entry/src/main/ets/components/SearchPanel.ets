import { listSearchHistory, clearSearchHistory, listHotKeywords, listSearchSuggest } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { BackButton } from '../design/components/BackButton';
import { GlassPanel } from '../design/components/GlassPanel';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { isImmersiveLightSenseSupported, GlassBlurStyle } from '../utils/immersiveMaterial';

// 首页内的搜索探索页：玻璃工具栏 + 最近搜索 + 双列热搜。
@Component
export struct SearchPanel {
  onKeywordSelect: (keyword: string) => void = (keyword: string) => {};
  onCancel: () => void = () => {};

  @State keyword: string = '';
  @State historyList: string[] = [];
  @State hotList: string[] = [];
  @State suggestions: string[] = []; // 搜索联想（输入时防抖拉取）
  @State loadingState: boolean = true;
  @State inputFocused: boolean = false; // 输入框聚焦（键盘弹出）时隐藏历史/热词，避免与联想卡粘连
  private suggestTimer: number = 0; // 联想防抖句柄

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

  // 输入防抖拉取联想（300ms；失败/无结果静默清空）
  private debounceSuggest(value: string): void {
    if (this.suggestTimer !== 0) {
      clearTimeout(this.suggestTimer);
      this.suggestTimer = 0;
    }
    const kw: string = value.trim();
    if (kw.length === 0) {
      this.suggestions = [];
      return;
    }
    this.suggestTimer = setTimeout((): void => {
      this.suggestTimer = 0;
      listSearchSuggest(kw)
        .then((list: string[]): void => { this.suggestions = list; })
        .catch((): void => { this.suggestions = []; });
    }, 300) as number;
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
    return rows * LayoutTokens.minTouchTarget + (rows - 1) * SpaceTokens.sm;
  }

  // 搜索框本体发光（亮色描边 + 冷色光晕），作为外层 Row 的 flex 子项自适应宽度，
  // 不套 ImmersiveSurface 包装，避免强制定尺寸覆盖 flex 拉伸导致“过长/失真”。
  @Builder
  searchInput(): void {
    TextInput({ placeholder: '搜索你关心的经验和问题', text: this.keyword })
      .fontFamily(TypeTokens.fontFamily)
      .fontColor(ColorTokens.primary)
      .layoutWeight(1)
      .height(LayoutTokens.minTouchTarget)
      .backgroundBlurStyle(GlassBlurStyle.Floating)
      .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
      .border({ width: 1, color: '#C4E0FF', style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.floatingBar)
      .shadow({ radius: 12, color: '#4D8AD8FF', offsetY: 0 })
      .onChange((v: string): void => { this.keyword = v; this.debounceSuggest(v); })
      .onSubmit((): void => { this.doSearch(); })
      .onFocus((): void => { this.inputFocused = true; })
      .onBlur((): void => { this.inputFocused = false; })
  }

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
        Text(keyword)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .height(LayoutTokens.segmentedHeight)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      .backgroundBlurStyle(GlassBlurStyle.Floating)
      .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.floatingBar)
      .alignItems(VerticalAlign.Center)
    }
  }

  build() {
    Column() {
      Row({ space: SpaceTokens.inline }) {
        BackButton({ action: (): void => { this.onCancel(); } })

        this.searchInput()

        Row() {
          Image($r('app.media.empty_search'))
            .width(IconTokens.small)
            .height(IconTokens.small)
        }
        .width(LayoutTokens.minTouchTarget)
        .height(LayoutTokens.minTouchTarget)
        .justifyContent(FlexAlign.Center)
        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.lg)
        .onClick((): void => { this.doSearch(); })
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.sm, bottom: SpaceTokens.item })

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
              GlassPanel({ panelPadding: SpaceTokens.md, radius: RadiusTokens.lg }) {
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
                    }
                  }
                  .width('100%')
                  Row({ space: SpaceTokens.inline }) {
                    ForEach(this.historyList.slice(0, 3), (kw: string) => {
                      this.historyChip(kw)
                    }, (kw: string) => 'history-first-' + kw)
                  }
                  .width('100%')
                  if (this.historyList.length > 3) {
                    Row({ space: SpaceTokens.inline }) {
                      ForEach(this.historyList.slice(3, 6), (kw: string) => {
                        this.historyChip(kw)
                      }, (kw: string) => 'history-second-' + kw)
                    }
                    .width('100%')
                  }
                }
                .width('100%')
              }
            }

            GlassPanel({ panelPadding: SpaceTokens.md, radius: RadiusTokens.lg }) {
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
                          visualHeight: LayoutTokens.minTouchTarget,
                          touchTargetHeight: LayoutTokens.minTouchTarget,
                          action: (): void => { this.onKeywordSelect(kw); },
                        }) {
                          Row({ space: SpaceTokens.sm }) {
                            Text(String(idx + 1))
                              .width(18)
                              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                              .fontWeight(TypeTokens.headline.weight)
                              .fontColor(this.rankColor(idx))
                            Text(kw)
                              .layoutWeight(1)
                              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                              .fontColor(ColorTokens.primary)
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                          }
                          .height(LayoutTokens.minTouchTarget)
                          .padding({ left: SpaceTokens.md, right: SpaceTokens.sm })
                          .backgroundBlurStyle(GlassBlurStyle.Floating)
                          .backgroundColor(isImmersiveLightSenseSupported() ? Color.Transparent : ColorTokens.barSurface)
                          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
                          .borderRadius(RadiusTokens.md)
                          .alignItems(VerticalAlign.Center)
                        }
                      }
                    }, (kw: string, idx: number) => 'hot-' + idx.toString() + '-' + kw)
                  }
                  .columnsTemplate('1fr 1fr')
                  .columnsGap(SpaceTokens.sm)
                  .rowsGap(SpaceTokens.sm)
                  .width('100%')
                  .height(this.hotGridHeight())
                }
              }
              .width('100%')
            }
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
}
