import { Tag } from '../models/types';
import { CircleOverviewItem, CitySummary, getCircleOverview, listCities, listCityTags } from '../services/api';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { Pressable } from '../design/motion/Pressable';
import { EmptyState } from '../design/components/EmptyState';
import { DesignButton } from '../design/components/DesignButton';
import { GlowInput } from '../design/components/GlowInput';
import { ToggleChip } from '../design/components/ToggleChip';
import { TagIcon } from './TagIcon';

// bindSheet 自带的关闭按钮固定在右上角（40vp 触控区、距右约 16vp）。
// 搜索框与它同处第一行，右侧让开 64vp = 触控区 + 边距 + 呼吸，
// 既不会被图标压住，也不会被它的热区抢走搜索框右端点击（2026-10-29 反馈）。
const SHEET_CLOSE_RESERVE: number = 64;

// 目录条目：由父页面（CircleTab）从服务端数据 + CIRCLE_META 构建后传入。
export interface CatalogItem {
  name: string;
  category: string;
  description: string;
  memberCount: number;
  joined: boolean;
}

export interface CatalogGroup {
  category: string;
  items: CatalogItem[];
}

// 深空目录（星图 Live 一期 + 三期）：bindSheet 内容。星图只放「你的 + 活跃的」，
// 长尾圈子住这里——搜索 + 按分类分组列表 + 直接加入（加入后关目录、星图点亮新星）。
// 三期新增：目录内「点亮一颗新星」创建入口（名称 + 分类 + 一句话简介）。
@Component
export struct CircleExploreSheet {
  @Prop groups: CatalogGroup[] = [];
  @Prop keyword: string = '';
  // 当前关注集：同城行据此即时翻转「已加入」，不必等整张目录重拉。
  @Prop @Watch('onJoinedNamesChanged') joinedNames: string[] = [];
  // 创建圈子的分类白名单（与后端 TAG_CATEGORIES 一致，由父页面传入）
  @Prop categories: string[] = [];
  onKeywordChange: (kw: string) => void = (_kw: string): void => {};
  onJoin: (name: string) => void = (_name: string): void => {};
  // 同城圈加入：走父页面的城市关注通道（城市圈不在主星图 circles 里）
  onJoinCity: (name: string) => void = (_name: string): void => {};
  onOpen: (name: string) => void = (_name: string): void => {};
  // 三期：创建圈子回调（父页面调 POST /v1/tags 并上演「点亮新星」编舞）；
  // 返回 true=创建成功（父页面已关目录），false=失败（表单保留供重试）。
  onCreate: (name: string, category: string, description: string) => Promise<boolean> =
    (_name: string, _category: string, _description: string): Promise<boolean> => Promise.resolve(false);

  // —— 创建态（点亮新星表单）——
  @State creating: boolean = false;
  @State newName: string = '';
  @State newCategory: string = '';
  @State newDesc: string = '';
  @State submitting: boolean = false;
  // —— 同城（并入发现，不再单开全屏层）——
  @State private cities: CitySummary[] = [];
  @State private cityCode: string = '';
  @State private cityItems: CatalogItem[] = [];
  @State private cityLoading: boolean = false;
  private cityRequestId: number = 0;

  aboutToAppear(): void {
    this.loadCities();
  }

  private async loadCities(): Promise<void> {
    try {
      this.cities = await listCities();
    } catch (e) {
      // 城市列表失败：同城区不展示，搜索/分类目录照常可用
      this.cities = [];
    }
  }

  private toCatalog(item: CircleOverviewItem): CatalogItem {
    return {
      name: item.name,
      category: item.category,
      description: item.description,
      memberCount: item.memberCount,
      joined: item.joined || this.joinedNames.indexOf(item.name) >= 0,
    };
  }

  // 旧后端还没有 overview 接口时的同城兜底（/v1/tags?cityCode=）。
  private tagToCatalog(tag: Tag): CatalogItem {
    const name: string = tag.name ?? '';
    return {
      name,
      category: tag.category ?? '',
      description: tag.description ?? '',
      memberCount: tag.followCount ?? 0,
      joined: this.joinedNames.indexOf(name) >= 0,
    };
  }

  private async pickCity(city: CitySummary): Promise<void> {
    if (this.cityCode === city.code) {
      this.cityCode = '';
      this.cityItems = [];
      this.cityLoading = false;
      this.cityRequestId += 1;
      return;
    }
    const requestId: number = this.cityRequestId + 1;
    this.cityRequestId = requestId;
    this.cityCode = city.code;
    this.cityLoading = true;
    this.cityItems = [];
    try {
      const overview = await getCircleOverview('city', city.code);
      if (requestId !== this.cityRequestId) {
        return;
      }
      this.cityItems = overview.circles.map((item: CircleOverviewItem): CatalogItem => this.toCatalog(item));
    } catch (e) {
      if (requestId !== this.cityRequestId) {
        return;
      }
      // overview 不存在（旧后端）→ 退回按 cityCode 拉圈子；仍失败才显示空态。
      try {
        const tags: Tag[] = await listCityTags(city.code);
        if (requestId === this.cityRequestId) {
          this.cityItems = tags
            .filter((tag: Tag): boolean => (tag.name ?? '').length > 0)
            .map((tag: Tag): CatalogItem => this.tagToCatalog(tag));
        }
      } catch (legacyError) {
        if (requestId === this.cityRequestId) {
          this.cityItems = [];
        }
      }
    } finally {
      if (requestId === this.cityRequestId) {
        this.cityLoading = false;
      }
    }
  }

  private onJoinedNamesChanged(): void {
    if (this.cityItems.length === 0) {
      return;
    }
    this.cityItems = this.cityItems.map((item: CatalogItem): CatalogItem => {
      const joined: boolean = this.joinedNames.indexOf(item.name) >= 0;
      return {
        name: item.name,
        category: item.category,
        description: item.description,
        memberCount: item.memberCount,
        joined,
      };
    });
  }

  // 名称 2~8 字、简介 1~24 字、分类必选（与后端 createTag 校验同口径，前端先拦一层）
  private canSubmit(): boolean {
    const name: string = this.newName.trim();
    const desc: string = this.newDesc.trim();
    return name.length >= 2 && name.length <= 8
      && desc.length >= 1 && desc.length <= 24
      && this.newCategory.length > 0
      && !this.submitting;
  }

  private resetForm(): void {
    this.creating = false;
    this.newName = '';
    this.newCategory = '';
    this.newDesc = '';
    this.submitting = false;
  }

  @Builder
  createEntry(): void {
    Row({ space: SpaceTokens.md }) {
      Text('＋')
        .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.warm)
      Text(this.creating ? '收起创建' : '创建一个圈子')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        // 彩色微文案不压 tint：金色语义交给「＋」这一处图形，文字回 primary 墨。
        .fontColor(ColorTokens.primary)
        .layoutWeight(1)
    }
    .width('100%')
    // 左右内缩归零：这一行的「＋」此前比搜索框/分组标题多缩进 12vp，左缘出现锯齿。
    // 热区仍靠 width('100%') 覆盖整行。
    .padding({ top: SpaceTokens.md, bottom: SpaceTokens.md })
    .margin({ top: SpaceTokens.md })
    // 这是一个动作行，不是输入区：不铺任何底色，靠上下 Divider 与「＋/收起创建」文案定位。
    // 一度铺过 canvas / subtle / 系统三级背景，真机上三种都会和相邻的输入框撞成同一张「输入框」。
    .onClick((): void => {
      if (this.creating) {
        this.resetForm();
      } else {
        this.creating = true;
      }
    })
  }

  @Builder
  categoryChip(item: string): void {
    // 可选中迷你 chip 的家族唯一样式源（ToggleChip）：选中态由 brandTint 底 + 加粗 + 墨字承担。
    // 原先手写的 brand 描边是「11px 品牌字压 tint 只有 3.58:1」的补偿手段，tint 底本身已足够示意。
    ToggleChip({
      label: item,
      selected: this.newCategory === item,
      // 半模态材质面板上 elevated 底与面板同色，补发丝描边才有边界。
      outlined: true,
      action: (): void => { this.newCategory = item; },
    })
  }

  @Builder
  createForm(): void {
    Column({ space: SpaceTokens.base }) {
      Column({ space: SpaceTokens.xs }) {
        Text('圈子名字（2~8 字）')
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .alignSelf(ItemAlign.Start)
        GlowInput({
          text: $newName,
          placeholder: '如：露营装备',
          fillWidth: false,
          inputHeight: 40,
          fontSize: TypeTokens.callout.size,
          maxLength: 8,
          fillColor: $r('sys.color.comp_background_tertiary'),
        })
      }
      Column({ space: SpaceTokens.xs }) {
        Text('分类')
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .alignSelf(ItemAlign.Start)
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.categories, (item: string) => {
            this.categoryChip(item)
          }, (item: string) => item)
        }
        .width('100%')
      }
      Column({ space: SpaceTokens.xs }) {
        Text('一句话简介（1~24 字）')
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .alignSelf(ItemAlign.Start)
        GlowInput({
          text: $newDesc,
          placeholder: '这个圈子聊什么？',
          fillWidth: false,
          inputHeight: 40,
          fontSize: TypeTokens.callout.size,
          maxLength: 24,
          fillColor: $r('sys.color.comp_background_tertiary'),
        })
      }
      DesignButton({
        label: this.submitting ? '创建中…' : '创建圈子',
        variant: 'primary',
        fillWidth: true,
        disabled: !this.canSubmit(),
        action: async (): Promise<void> => {
          if (!this.canSubmit()) {
            return;
          }
          this.submitting = true;
          const success: boolean = await this.onCreate(this.newName.trim(), this.newCategory, this.newDesc.trim());
          this.submitting = false;
          // 成功时父页面已关目录；失败时表单保留供修改重试
          if (success) {
            this.resetForm();
          }
        },
      })
    }
    .width('100%')
    .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.md })
  }

  @Builder
  row(item: CatalogItem, fromCity: boolean = false): void {
    // 信息区与按钮必须是两块独立点击区：整行 onClick + 内嵌按钮会让「加入」同时打开详情
    // （CityLayer.circleRow 已记录同类真机问题，2026-10-25）。
    Row({ space: SpaceTokens.md }) {
      Column() {
        Pressable({
          fillWidth: true,
          fullResponseRegion: true,
          action: (): void => { this.onOpen(item.name); },
        }) {
          Row({ space: SpaceTokens.md }) {
            TagIcon({ name: item.name, category: item.category, iconSize: 24, tint: ColorTokens.brand })
              .width(34)
              .height(34)
            Column({ space: 2 }) {
              Row({ space: SpaceTokens.xs }) {
                Text(item.name)
                  .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                  .fontWeight(TypeTokens.headline.weight)
                  .fontColor(ColorTokens.primary)
                if (item.joined) {
                  // 11px 小字压暖金在纸白上只有约 4.2:1，达不到 AA；
                  // 金色语义交给描边/图标，文字回主墨色。
                  Text('✓ 已加入')
                    .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
                    .fontWeight(TypeTokens.headline.weight)
                    .fontColor(ColorTokens.secondary)
                }
              }
              Text((item.description.length > 0 ? item.description + ' · ' : '') + item.memberCount + ' 人')
                .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.tertiary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
      }
      .layoutWeight(1)

      // 保留原生 Button：这是行内次级 CTA，品牌描边就是它的可点性来源。
      // 一度换成 DesignButton outlined，真机上描边色(barBorder)比 brand 淡一档，
      // 白底行里几乎看不出边界 → 回退。原生 Button 本身属官方控件，
      // 不在此次「自绘冒充控件」的整改范围内（对比原分类/城市胶囊是 Text + onClick）。
      Button(item.joined ? '去看看' : '加入')
        .buttonStyle(ButtonStyleMode.NORMAL)
        .type(ButtonType.Capsule)
        .controlSize(ControlSize.SMALL)
        // 与分类/城市胶囊同高（28）：行内三类小元素（chip 28、按钮 28、图标 34）不再参差。
        .height(28)
        .fontSize(TypeTokens.overline.size)
        .fontColor(item.joined ? ColorTokens.warm : ColorTokens.brand)
        .backgroundColor(Color.Transparent)
        .borderWidth(LayoutTokens.glassBorderWidth)
        .borderColor(item.joined ? ColorTokens.warm : ColorTokens.brand)
        .onClick((): void => {
          if (item.joined) {
            this.onOpen(item.name);
          } else if (fromCity) {
            this.onJoinCity(item.name);
          } else {
            this.onJoin(item.name);
          }
        })
    }
    .width('100%')
    .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.sm })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  cityChip(city: CitySummary): void {
    // 与分类胶囊同一个可选中 chip 源（ToggleChip），不再各写一份底色/描边/字重配方。
    // 触控区由 Pressable 的 minTouchTarget(44) 承担，视觉高度回落到家族标准 28。
    ToggleChip({
      label: city.name + (city.circleCount > 0 ? ' ' + city.circleCount : ''),
      selected: this.cityCode === city.code,
      outlined: true,
      action: (): void => { this.pickCity(city); },
    })
  }

  @Builder
  citySection(): void {
    Column({ space: SpaceTokens.sm }) {
      Row({ space: SpaceTokens.xs }) {
        Text('同城圈子')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.primary)
        Text('· 按城市看')
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
        Blank()
        if (this.cityCode.length > 0) {
          Text('清除筛选')
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brand)
            .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 6, bottom: 6 })
            .onClick((): void => {
              this.cityCode = '';
              this.cityItems = [];
              this.cityLoading = false;
              this.cityRequestId += 1;
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 全部白名单城市横向滚动：保留原城市层「所有城市可选」的能力，
      // 又不再单开一整个全屏层。
      Scroll() {
        Row({ space: SpaceTokens.sm }) {
          ForEach(this.cities, (city: CitySummary) => {
            this.cityChip(city)
          }, (city: CitySummary) => 'city-' + city.code)
        }
        .padding({ right: SpaceTokens.md })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .height(48)
      .width('100%')

      if (this.cityCode.length > 0) {
        if (this.cityLoading) {
          Row({ space: SpaceTokens.sm }) {
            LoadingProgress().width(IconTokens.small).height(IconTokens.small)
            Text('正在加载同城圈子…')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
          }
          .width('100%')
          .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.sm })
        } else if (this.cityItems.length === 0) {
          Text('这座城市还没有同城圈，换个城市看看')
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .width('100%')
            .padding({ top: SpaceTokens.md, bottom: SpaceTokens.md })
        } else {
          ForEach(this.cityItems, (item: CatalogItem) => {
            this.row(item, true)
            Divider().color(ColorTokens.separator).strokeWidth(LayoutTokens.hairlineWidth)
          }, (item: CatalogItem) => 'city-item-' + item.name)
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: SpaceTokens.md, bottom: SpaceTokens.sm })
  }

  build() {
    Column() {
      // 顶边不留边距：系统关闭按钮贴在内容区顶部（实测其中心比带 8vp 上边距的搜索框高 8vp），
      // 搜索框与它顶对齐后两者水平中线一致（2026-10-29 反馈）。
      Search({ value: this.keyword, placeholder: '搜索圈子名或分类…' })
        .height(40)
        // 系统色底对齐官方 Search 外观（编译期 SDK 冻结的是 6.x 老样式）。
        // 半模态内不挂 systemMaterial——通用组件材质只在标题栏生效区出图（同「发现圈子」的教训）。
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .margin({ left: SpaceTokens.xl, right: SHEET_CLOSE_RESERVE, top: 0 })
        .onChange((value: string): void => { this.onKeywordChange(value); })

      Scroll() {
        Column() {
          // 三期：点亮新星入口（置顶）+ 展开的创建表单
          this.createEntry()
          Divider().color(ColorTokens.separator).strokeWidth(LayoutTokens.hairlineWidth)
          if (this.creating) {
            this.createForm()
            Divider().color(ColorTokens.separator).strokeWidth(LayoutTokens.hairlineWidth)
          }

          if (this.cities.length > 0) {
            this.citySection()
            Divider().color(ColorTokens.separator).strokeWidth(LayoutTokens.hairlineWidth)
          }

          // 选了城市就只看同城圈；点「清除筛选」回到全部圈子。
          if (this.cityCode.length === 0) {
            ForEach(this.groups, (group: CatalogGroup) => {
              // 分组标题：原先 overline(11)+tertiary+字距2，读起来像注释。
              // 升 caption(12)+secondary，组间距从 20 拉到 40（8 行底 + 32 标题顶），
              // 让「组」和「行」（行距 16）在节奏上真正分开。
              Text(group.category)
                .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.headline.weight)
                .fontColor(ColorTokens.secondary)
                .alignSelf(ItemAlign.Start)
                .margin({ top: SpaceTokens.x2l, bottom: SpaceTokens.sm })
              ForEach(group.items, (item: CatalogItem, index: number) => {
                this.row(item)
                // 组末不留线：否则最后一行与下一组标题之间会多出一条，切断分组感。
                if (index < group.items.length - 1) {
                  Divider().color(ColorTokens.separator).strokeWidth(LayoutTokens.hairlineWidth)
                }
              }, (item: CatalogItem) => item.name)
            }, (group: CatalogGroup) => group.category)

            if (this.groups.length === 0) {
              if (this.keyword.length > 0) {
                EmptyState({
                  icon: $r('app.media.empty_search'),
                  title: '没有找到「' + this.keyword + '」相关的圈子',
                  message: '换个关键词，或创建一个新圈子',
                })
                .margin({ top: SpaceTokens.x3l })
              } else {
                Column({ space: SpaceTokens.sm }) {
                  Text('圈子目录加载中…')
                    .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                    .fontColor(ColorTokens.secondary)
                }
                .width('100%')
                .margin({ top: SpaceTokens.x3l })
              }
            }
          }
        }
        .width('100%')
        .padding({ left: SpaceTokens.xl, right: SpaceTokens.xl, bottom: SpaceTokens.x2l })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .borderRadius({ topLeft: RadiusTokens.xl, topRight: RadiusTokens.xl })
  }
}
