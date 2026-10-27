import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { Pressable } from '../design/motion/Pressable';
import { TagIcon } from './TagIcon';

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
  @Prop totalCount: number = 0;
  // 创建圈子的分类白名单（与后端 TAG_CATEGORIES 一致，由父页面传入）
  @Prop categories: string[] = [];
  onKeywordChange: (kw: string) => void = (_kw: string): void => {};
  onJoin: (name: string) => void = (_name: string): void => {};
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
    // 原型 cccreate：金色虚线边框卡片（区别于普通行，突出「点燃新星」的仪式感）
    Row({ space: SpaceTokens.md }) {
      Text('＋')
        .fontSize(18).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.warm)
      Text(this.creating ? '收起创建' : '点亮一颗新星 · 创建圈子')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        // 彩色微文案不压 tint（warm 字 #A06400 在浅 tint 上 4.19:1，12px 不达 AA）：
        // 金色语义交给虚线描边 + 「＋」，文字回 primary 墨。
        .fontColor(ColorTokens.primary)
        .layoutWeight(1)
    }
    .width('100%')
    .padding(SpaceTokens.md)
    .margin({ top: SpaceTokens.md })
    .backgroundColor(ColorTokens.brandTint)
    .border({ width: 1, color: ColorTokens.warm, style: BorderStyle.Dashed })
    .borderRadius(RadiusTokens.md)
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
    // 原型 catchip：选中=品牌色描边+浅底+墨字（11px 蓝字压蓝 tint 深色仅 3.58:1，不达 AA，
    // 蓝色身份由 1px brand 描边 + tint 底承担，描边只需过 3:1 图形下限）
    Text(item)
      .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(this.newCategory === item ? TypeTokens.headline.weight : FontWeight.Regular)
      .fontColor(this.newCategory === item ? ColorTokens.primary : ColorTokens.secondary)
      .backgroundColor(this.newCategory === item ? ColorTokens.brandTint : ColorTokens.subtle)
      .border({ width: 1, color: this.newCategory === item ? ColorTokens.brand : ColorTokens.separator, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.pill)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: 6, bottom: 6 })
      .onClick((): void => { this.newCategory = item; })
  }

  @Builder
  createForm(): void {
    Column({ space: SpaceTokens.base }) {
      Column({ space: SpaceTokens.xs }) {
        Text('圈子名字（2~8 字）')
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .alignSelf(ItemAlign.Start)
        TextInput({ text: this.newName, placeholder: '如：露营装备' })
          .maxLength(8)
          .height(40)
          .fontSize(TypeTokens.callout.size)
          .onChange((value: string): void => { this.newName = value; })
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
        TextInput({ text: this.newDesc, placeholder: '这个圈子聊什么？' })
          .maxLength(24)
          .height(40)
          .fontSize(TypeTokens.callout.size)
          .onChange((value: string): void => { this.newDesc = value; })
      }
      Button(this.submitting ? '点亮中…' : '✦ 点亮新星')
        .width('100%')
        .height(44)
        .enabled(this.canSubmit())
        .opacity(this.canSubmit() ? 1 : 0.5)
        .onClick(async (): Promise<void> => {
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
        })
    }
    .width('100%')
    .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.md })
  }

  @Builder
  row(item: CatalogItem): void {
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
            TagIcon({ name: item.name, iconSize: 24, tint: ColorTokens.brand })
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
              Text(item.description)
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

      Button(item.joined ? '去看看' : '加入')
        .buttonStyle(ButtonStyleMode.NORMAL)
        .type(ButtonType.Capsule)
        .controlSize(ControlSize.SMALL)
        .fontSize(TypeTokens.overline.size)
        .fontColor(item.joined ? ColorTokens.warm : ColorTokens.brand)
        .backgroundColor(Color.Transparent)
        .borderWidth(1)
        .borderColor(item.joined ? ColorTokens.warm : ColorTokens.brand)
        .onClick((): void => {
          if (item.joined) {
            this.onOpen(item.name);
          } else {
            this.onJoin(item.name);
          }
        })
    }
    .width('100%')
    .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.sm })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      Search({ value: this.keyword, placeholder: '搜索圈子名或分类…' })
        .height(40)
        .margin({ left: SpaceTokens.xl, right: SpaceTokens.xl, top: SpaceTokens.sm })
        .onChange((value: string): void => { this.onKeywordChange(value); })

      Scroll() {
        Column() {
          // 三期：点亮新星入口（置顶）+ 展开的创建表单
          this.createEntry()
          Divider().color(ColorTokens.separator).strokeWidth(0.5)
          if (this.creating) {
            this.createForm()
            Divider().color(ColorTokens.separator).strokeWidth(0.5)
          }

          ForEach(this.groups, (group: CatalogGroup) => {
            Text(group.category)
              .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(ColorTokens.tertiary)
              .letterSpacing(2)
              .alignSelf(ItemAlign.Start)
              .margin({ top: SpaceTokens.md, bottom: SpaceTokens.xs })
            ForEach(group.items, (item: CatalogItem) => {
              this.row(item)
              Divider().color(ColorTokens.separator).strokeWidth(0.5)
            }, (item: CatalogItem) => item.name)
          }, (group: CatalogGroup) => group.category)

          if (this.groups.length === 0) {
            Column({ space: SpaceTokens.sm }) {
              Text('✦').fontSize(26).fontColor(ColorTokens.warm)
              Text(this.keyword.length > 0
                ? '深空里没有叫「' + this.keyword + '」的圈子\n也许，该由你来点亮它'
                : '深空目录加载中…')
                .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.tertiary)
                .textAlign(TextAlign.Center)
                .lineHeight(20)
            }
            .width('100%')
            .margin({ top: SpaceTokens.x3l })
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
