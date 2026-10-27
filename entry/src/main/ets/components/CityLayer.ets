// 同城层（星图子模式「降落地球」，Phase 1）：
// 圈子页星图内的城市维度入口层——未选城市时是选城页（热门城市格 + 搜索 + 按省分组全量），
// 选定后是城市页（城市圈列表，进入复用 CircleDetailPage 的 tag 过滤通道）。
// Phase 2 已接入华为地图：选城页增「地图选城」（MapComponent 全屏交互图，syscap 门禁：
// SystemCapability.Map.Core 不可用时自动隐藏，索引选城永远可用）与「定位我的城市」
//（定位→reverseGeocode 反解→白名单匹配，拒绝授权安静降级）。
//
// 父子关系（用户拍板）：星图是父模式，本层是子模式——由星图上的「📍同城」入口唤起，
// 关闭即回到星图；加入/退出同城圈与星图共用 joinedNames 关注事实（回调上抛）。
import { CitySummary, listCities, listCityTags, followTag, unfollowTag } from '../services/api';
import { Tag } from '../models/types';
import { BackButton } from '../design/components/BackButton';
import { DesignButton } from '../design/components/DesignButton';
import { EmptyState } from '../design/components/EmptyState';
import { GlowInput } from '../design/components/GlowInput';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { resolveActionIcon } from '../utils/actionIcons';
import { MapCityPicker } from './MapCityPicker';
import { isMapKitAvailable, locateCurrentCity } from '../utils/cityLocation';
import { common } from '@kit.AbilityKit';

// 热门城市格数量：白名单前 10 座（北上广深 + 直辖市 + 热门省会，cities.ts 的直觉序）。
const HOT_CITY_COUNT: number = 10;

// 选城页「按省分组」的组结构（ArkTS 要求具名接口，禁止内联对象字面量类型）
interface ProvinceGroup {
  province: string;
  cities: CitySummary[];
}

@Component
export struct CityLayer {
  // 已选城市（null = 选城页）；由 CircleTab 持有并传入（父模式记忆选城）
  @Link selectedCity: CitySummary | null;
  visible: boolean = false;
  // 父模式关注集（@Prop）：joinedNames 变化驱动本层重渲染——按钮「加入/已加入」才会翻转
  @Prop joinedNames: string[] = [];
  onJoin: (name: string) => void = (_name: string): void => {};
  onUnjoin: (name: string) => void = (_name: string): void => {};
  onOpenCircle: (name: string) => void = (_name: string): void => {};
  onClose: () => void = (): void => {};
  @State private cities: CitySummary[] = [];
  @State private citiesReady: boolean = false;
  @State private keyword: string = '';
  @State private tags: Tag[] = [];
  @State private tagsLoading: boolean = false;
  // 地图选城（Phase 2）：syscap 门禁——模拟器/OpenHarmony 无 HMS 地图时不出入口
  @State private mapMode: boolean = false;
  @State private locating: boolean = false;
  // 状态栏高度（Index 启动时写入 AppStorage）：覆盖层自管状态栏避让
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  // 底部悬浮 Dock 避让：LayoutTokens.floatingBarReserve + 系统导航条高度（随导航模式即时变化）
  @StorageLink('navBarHeight') navBarHeight: number = 0;

  aboutToAppear(): void {
    this.loadCities();
    this.loadTags();
  }

  private async loadCities(): Promise<void> {
    try {
      this.cities = await listCities();
    } catch (e) {
      // 城市白名单加载失败：选城页空态提示重试（城市页不受影响——已选城市可继续用）
    } finally {
      this.citiesReady = true;
    }
  }

  private async loadTags(): Promise<void> {
    if (this.selectedCity === null) {
      return;
    }
    this.tagsLoading = true;
    try {
      this.tags = await listCityTags(this.selectedCity.code);
    } catch (e) {
      this.tags = [];
    } finally {
      this.tagsLoading = false;
    }
  }

  // 选城：写回父模式并加载该城圈子
  private pickCity(city: CitySummary): void {
    if (this.selectedCity?.code === city.code) {
      return;
    }
    this.selectedCity = city;
    this.keyword = '';
    this.loadTags();
  }

  // 选城页过滤：按城市名/省名包含匹配（30 城量级，前端过滤即够）
  private filteredCities(): CitySummary[] {
    const kw: string = this.keyword.trim();
    if (kw.length === 0) {
      return this.cities;
    }
    return this.cities.filter((c: CitySummary): boolean => c.name.includes(kw) || c.province.includes(kw));
  }

  private hotCities(): CitySummary[] {
    return this.cities.slice(0, HOT_CITY_COUNT);
  }

  // 按省分组（保持白名单顺序）；搜索态不分组直接平铺
  private provinceGroups(): ProvinceGroup[] {
    const groups: ProvinceGroup[] = [];
    for (const c of this.filteredCities()) {
      const last: ProvinceGroup | undefined = groups.length > 0
        ? groups[groups.length - 1] : undefined;
      if (last !== undefined && last.province === c.province) {
        last.cities.push(c);
      } else {
        groups.push({ province: c.province, cities: [c] });
      }
    }
    return groups;
  }

  private toggleJoin(t: Tag): void {
    const name: string = t.name ?? '';
    if (this.joinedNames.includes(name)) {
      this.onUnjoin(name);
    } else {
      this.onJoin(name);
    }
  }

  // 定位自动选城（Phase 2）：失败安静降级（权限拒绝/超时/白名单之外都返回 null）
  private async locateAndPick(): Promise<void> {
    if (this.locating) {
      return;
    }
    this.locating = true;
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const located = await locateCurrentCity(ctx);
      if (located !== null) {
        const hit: CitySummary | undefined = this.cities.find((c: CitySummary): boolean => c.name === located.cityName);
        if (hit !== undefined) {
          this.pickCity(hit);
        }
      }
    } finally {
      this.locating = false;
    }
  }

  @Builder
  private headerBar(title: string, showBack: boolean): void {
    Row() {
      if (showBack) {
        // 全应用统一返回件（44vp 触控 + 无障碍标注），不再手搓图标按钮
        BackButton({
          action: (): void => {
            // 城市页 → 选城页（不关闭层；层关闭走右上）
            this.selectedCity = null;
          },
        })
      }
      Text(title)
        .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.titleSerif.weight)
        .lineHeight(TypeTokens.titleSerif.lineHeight)
        .fontColor(ColorTokens.primary)
        .layoutWeight(1)
        .padding({ left: showBack ? SpaceTokens.none : SpaceTokens.sm })
      // 顶栏次级动作标准件（同发布页「清空」的 ghost 变体）
      DesignButton({
        label: '回到星图',
        variant: 'ghost',
        visualHeight: LayoutTokens.segmentedHeight,
        action: (): void => { this.onClose(); },
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    // 覆盖层自管状态栏避让（盖住了 HdsNavigation 标题栏，Index 只给 CircleTab 让位）
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: this.statusBarHeight + SpaceTokens.sm })
  }

  @Builder
  private cityCell(city: CitySummary): void {
    Pressable({
      fillWidth: true,
      fullResponseRegion: true,
      action: (): void => { this.pickCity(city); },
    }) {
      Row() {
        Column({ space: 2 }) {
          Text(city.name)
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.primary)
          Text(city.province + ' · ' + city.circleCount + ' 个圈子')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Image(resolveActionIcon('chevronRight'))
          .width(IconTokens.small)
          .height(IconTokens.small)
          .fillColor(ColorTokens.tertiary)
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.md)
    }
  }

  // —— 选城页 ——
  @Builder
  private cityPicker(): void {
    Column() {
      this.headerBar('降落地球 · 选择城市', false)
      // 统一输入件（官方原生样式：subtle 底 + lg 胶囊），替换裸 TextInput
      GlowInput({
        placeholder: '搜索城市或省份',
        text: $keyword,
        fillWidth: false,
      })
        .margin({ top: SpaceTokens.sm })

      // 地图选城 / 定位（Phase 2）：仅华为地图 syscap 可用时展示；定位失败安静降级
      if (isMapKitAvailable()) {
        Row({ space: SpaceTokens.sm }) {
          DesignButton({
            label: '地图选城',
            variant: 'outlined',
            visualHeight: LayoutTokens.segmentedHeight,
            action: (): void => { this.mapMode = true; },
          })
          DesignButton({
            label: this.locating ? '定位中…' : '定位我的城市',
            variant: 'outlined',
            visualHeight: LayoutTokens.segmentedHeight,
            disabled: this.locating,
            action: (): void => { this.locateAndPick(); },
          })
        }
        .width('100%')
        .margin({ top: SpaceTokens.sm })
      }

      if (!this.citiesReady) {
        Column() {
          LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: SpaceTokens.base }) {
            Text('热门城市')
              .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.overline.weight)
              .fontColor(ColorTokens.tertiary)
              .width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.hotCities(), (c: CitySummary) => {
                Column() {
                  Pressable({
                    visualHeight: LayoutTokens.segmentedHeight,
                    action: (): void => { this.pickCity(c); },
                  }) {
                    // 芯片家族标准规格（同 ChipRow 未选中态：sunken 底 + sm 圆角 + 36 高）
                    Text(c.name)
                      .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                      .fontWeight(TypeTokens.headline.weight)
                      .fontColor(ColorTokens.primary)
                      .padding({ left: SpaceTokens.item, right: SpaceTokens.item })
                      .height(LayoutTokens.segmentedHeight)
                      .backgroundColor(ColorTokens.sunken)
                      .borderRadius(RadiusTokens.sm)
                  }
                }
                .margin({ right: SpaceTokens.sm, bottom: SpaceTokens.sm })
              }, (c: CitySummary) => 'hot-' + c.code)
            }
            .width('100%')

            // 全量城市按省分组（搜索时平铺）
            if (this.keyword.trim().length === 0) {
              ForEach(this.provinceGroups(), (g: ProvinceGroup) => {
                Column({ space: SpaceTokens.xs }) {
                  Text(g.province)
                    .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
                    .fontWeight(TypeTokens.overline.weight)
                    .fontColor(ColorTokens.tertiary)
                    .width('100%')
                  ForEach(g.cities, (c: CitySummary) => {
                    this.cityCell(c)
                  }, (c: CitySummary) => c.code)
                }
                .width('100%')
              }, (g: ProvinceGroup) => g.province)
            } else {
              ForEach(this.filteredCities(), (c: CitySummary) => {
                this.cityCell(c)
              }, (c: CitySummary) => c.code)
            }
          }
          .width('100%')
          .padding({
            left: SpaceTokens.base,
            right: SpaceTokens.base,
            top: SpaceTokens.base,
            bottom: LayoutTokens.floatingBarReserve + this.navBarHeight + SpaceTokens.x2l,
          })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        // Scroll 内容矮于视口时默认垂直居中（搜索只剩一两个结果时整页下坠），显式顶对齐
        .align(Alignment.Top)
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  // —— 城市页 ——
  @Builder
  private cityHome(): void {
    Column() {
      this.headerBar(this.selectedCity?.name ?? '', true)
      Scroll() {
        Column({ space: SpaceTokens.sm }) {
          // 城市头卡（Phase 2 换静态地图底图）
          Column({ space: SpaceTokens.xs }) {
            Text(this.selectedCity?.name ?? '')
              .fontSize(TypeTokens.display.size).fontFamily(TypeTokens.fontFamilySerif)
              .fontWeight(TypeTokens.display.weight)
              .fontColor(ColorTokens.primary)
            Text('同在这座城的人，聊这座城的事')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
          }
          .width('100%')
          .padding({ top: SpaceTokens.md, bottom: SpaceTokens.md })
          .alignItems(HorizontalAlign.Start)

          Text('城市圈子 · ' + this.tags.length + ' 个')
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.overline.weight)
            .fontColor(ColorTokens.tertiary)
            .width('100%')

          if (this.tagsLoading) {
            Column() {
              LoadingProgress().width(IconTokens.empty).height(IconTokens.empty)
            }
            .width('100%')
            .padding({ top: SpaceTokens.x2l })
            .justifyContent(FlexAlign.Center)
          } else if (this.tags.length === 0) {
            Column() {
              EmptyState({
                icon: resolveActionIcon('guide'),
                title: '这座城市还没有同城圈',
                message: '换个城市看看，或回到星图探索全球圈子',
              })
            }
            .width('100%')
            .padding({ top: SpaceTokens.x2l, bottom: SpaceTokens.x2l })
            .alignItems(HorizontalAlign.Center)
          } else {
            ForEach(this.tags, (t: Tag) => {
              this.circleRow(t)
            }, (t: Tag) => (t.name ?? '') + '-' + String(t.followCount ?? 0))
          }
        }
        .width('100%')
        .padding({
          left: SpaceTokens.base,
          right: SpaceTokens.base,
          // 底部让开悬浮 Dock + 系统导航条：否则最后一行会被盖住。
          bottom: LayoutTokens.floatingBarReserve + this.navBarHeight + SpaceTokens.x2l,
        })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      // 同上：城市圈少时内容矮于视口，Scroll 默认居中会把头卡坠到屏幕中部（真机实证）
      .align(Alignment.Top)
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }

  // 城市圈行：**两个点击区完全分离**（信息区进详情 / 按钮加退）——嵌套 Pressable
  // 会被外层行吃掉按钮点击（点「加入」直接进了详情页，真机实证 2026-10-25）
  @Builder
  private circleRow(t: Tag): void {
    Row({ space: SpaceTokens.sm }) {
      // layoutWeight 挂在容器 Column 上（Pressable 尾随属性链在 ArkTS 解析受限）
      Column() {
        Pressable({
          fillWidth: true,
          fullResponseRegion: true,
          action: (): void => { this.onOpenCircle(t.name ?? ''); },
        }) {
          Column({ space: 2 }) {
            Text(t.name ?? '')
              .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(ColorTokens.primary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text((t.description ?? '') + ' · ' + (t.followCount ?? 0) + ' 人')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
      }
      .layoutWeight(1)
      // 加退按钮走全应用统一件（同圈子详情「加入圈子」的 outlined 变体，label 翻转表状态）
      DesignButton({
        label: this.joinedNames.includes(t.name ?? '') ? '退出' : '加入',
        variant: 'outlined',
        visualHeight: LayoutTokens.segmentedHeight,
        action: (): void => { this.toggleJoin(t); },
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(RadiusTokens.md)
  }

  build() {
    Stack() {
      if (this.selectedCity === null) {
        this.cityPicker()
      } else {
        this.cityHome()
      }

      // 地图选城覆盖层（Phase 2）：全屏交互地图，点城市 marker 即选定并收起
      if (this.mapMode) {
        MapCityPicker({
          cities: this.cities,
          onPick: (city: CitySummary): void => {
            this.mapMode = false;
            this.pickCity(city);
          },
          onClose: (): void => { this.mapMode = false; },
        })
          .transition(TransitionEffect.OPACITY
            .animation({ duration: MotionTokens.container, curve: MotionCurves.emphasized }))
      }
    }
    .width('100%')
    .height('100%')
  }
}
