// 「我的」顶栏官方化原型页（临时页面 · 验完按本页结构改 Index.ets，随后连本页一并删除）
//
// 为什么要先搭原型：把「我的」顶栏搬进 HdsNavigation 会一次动到资料区归属（钉住还是随列表滚走）、
// 两条分段栏的落点、以及穿底与栏高那一整套数学（profileTitleBarHeight / profileListInset /
// hero 高度实测回写）。这些判断在已上线页面上盲改不可回滚，所以照 HdsNavVerifyPage 当年的路子
// 先在这里搭一遍，装机验过再搬主链路。
//
// 本页要回答的唯一未知：官方圆钮（content.menu）与分段栏（bottomBuilder）能不能同时挂在
// 同一条 HdsNavigation 标题栏上。首页/圈子的顶栏有 bottomBuilder 但没有 menu；
// HdsMenuVerifyPage 有 menu 但没有 bottomBuilder —— 这个组合从没装过机。
//
// 真机验收清单（浅色 / 深色各抓一帧）：
//   ① 标题 + 两枚官方圆 + 两条分段栏 同栏共存，互不遮挡、不溢出；
//   ② 官方圆 40×40vp、图标 24vp、钮间距 8vp、右缘距屏 16vp（基准 §7.6）；
//   ③ 分段栏落在 bottomBuilder 内材质正常，**栏底不出现常驻灰带**（当年 clip 病灶）；
//   ④ 列表能穿到标题栏底下被渐变模糊，回弹还原（→ 需 enableComponentSafeArea:false，已验）；
//   ⑤ 资料区住在 bottomBuilder 内、保住「标题行 → 资料区 → 分段栏」原顺序，栏体高随内容/分段重配
//     （→ 依赖 bottomBuilder.height 运行期可重配，已验，见基准 §7.6.9）。
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import type {
  HdsNavigationTitleBarOptions,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  ScrollEffectOptions,
  SystemMaterialParams,
  BottomBuilderParams,
  HdsNavigationMenuContentOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationIconOptions,
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import deviceInfo from '@ohos.deviceInfo';
import hilog from '@ohos.hilog';
import { ColorTokens } from '../design/tokens/color';
import { TypeTokens } from '../design/tokens/type';
import { SpaceTokens, LayoutTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { ImmersiveSegmentBar } from '../design/components/ImmersiveSegmentBar';
import type { SegmentedItem } from '../design/components/SegmentedControl';
import { isSystemMaterialActive } from '../utils/immersiveMaterial';

const DOMAIN: number = 0x0000;
const PROTO_TAG: string = 'ProfileBarProto';

const HDS_NAV_MIN_API: number = 20;
const HDS_SYSCAP: string = 'SystemCapability.UIDesign.HDSComponent.Core';
const BLUR_END_OFFSET_VP: number = 64;

// bottomBuilder 行高 = 资料区（内容驱动，实测回写）+ 主分段那一行（顶部间隙 + 栏体 + 投影净空）
//                + 子分段那一行（间隙 + 栏体，仅「我收藏」）
// 资料区放进 bottomBuilder 而不是内容区：已上线「我的」的视觉顺序是 标题行 → 资料区 → 分段栏，
// 资料区若留在内容区就只能排在整条栏之下（顺序变了）。能不能这么放取决于 bottomBuilder.height
// 能否随状态重配 —— 本轮实测**可以**（82→126→82vp 双向跟手），见基准 §7.6.9。
const MAIN_SEG_ROW_VP: number = LayoutTokens.segmentBarTopRoom + LayoutTokens.segmentBarHeight
  + LayoutTokens.segmentBarShadowRoom;
const SUB_SEG_ROW_VP: number = SpaceTokens.xs + LayoutTokens.segmentBarHeight;
// 标题行（官方 MINI 标题区 + 圆钮那一行）实测高 175px ÷ 3.125 = 56vp，系统定值不可调
const TITLE_ROW_VP: number = 56;
// 资料区首帧高度兜底（实测到齐前用），与已上线页的 profileHeroEstimate 同量级
const HERO_FALLBACK_VP: number = 92;

function isHdsNavSupported(): boolean {
  try {
    return deviceInfo.sdkApiVersion >= HDS_NAV_MIN_API && canIUse(HDS_SYSCAP);
  } catch (e) {
    return false;
  }
}

const PROFILE_SEGMENTS: SegmentedItem[] = [
  { key: 'posts', label: '我发布' },
  { key: 'bookmarks', label: '我收藏' },
  { key: 'likes', label: '我赞过' },
  { key: 'comments', label: '我评论' },
];

const BOOKMARK_SEGMENTS: SegmentedItem[] = [
  { key: 'notes', label: '帖子' },
  { key: 'folders', label: '收藏夹' },
];

interface ProtoCard {
  title: string;
  colorFrom: string;
  colorTo: string;
}

// 有彩度的卡片：白底纯文字看不出内容有没有穿到栏下被模糊（旧验证页实测教训）
const PROTO_CARDS: ProtoCard[] = [
  { title: '晨间阅读', colorFrom: '#4A90D9', colorTo: '#8E7CC3' },
  { title: '茶与咖啡', colorFrom: '#D98C4A', colorTo: '#C35A5A' },
  { title: '城市漫步', colorFrom: '#3FA46A', colorTo: '#2E7D9E' },
  { title: '胶片摄影', colorFrom: '#B25EC7', colorTo: '#5C6BC0' },
  { title: '旧书重读', colorFrom: '#C77E5E', colorTo: '#8D6E63' },
  { title: '长路散步', colorFrom: '#2E7D9E', colorTo: '#3FA46A' },
  { title: '手冲参数', colorFrom: '#8D6E63', colorTo: '#C77E5E' },
  { title: '折角那页', colorFrom: '#5C6BC0', colorTo: '#B25EC7' },
];

@Entry
@Component
struct ProfileBarProtoPage {
  @State lastTapped: string = '（还没点过官方圆）';
  @State materialProbeText: string = '（材质探测未执行）';
  @State mainSegIdx: number = 0;
  @State subSegIdx: number = 0;
  // 资料区实测高（vp）：0 = 尚未测到，用 HERO_FALLBACK_VP 兜底。bottomBuilder 高度靠它跟随内容。
  @State heroHVp: number = 0;
  private supported: boolean = isHdsNavSupported();
  private material: SystemMaterialParams | undefined = undefined;
  private scroller: Scroller = new Scroller();

  private heroHeight(): number {
    return this.heroHVp > 0 ? this.heroHVp : HERO_FALLBACK_VP;
  }

  private hasSubSeg(): boolean {
    return this.mainSegIdx === 1;
  }

  // bottomBuilder 声明高 = 资料区 + 主分段行 + （子分段行，仅「我收藏」）
  private barBuilderHeight(): number {
    return this.heroHeight() + MAIN_SEG_ROW_VP + (this.hasSubSeg() ? SUB_SEG_ROW_VP : 0);
  }

  // 列表要让开的那一条：内容区原点就在状态栏下沿，整条栏（标题行 + bottomBuilder）都盖在它上面
  private listInset(): number {
    return TITLE_ROW_VP + this.barBuilderHeight();
  }

  aboutToAppear(): void {
    this.material = this.probeMaterial();
    hilog.info(DOMAIN, PROTO_TAG,
      'enter: sdk=%{public}d supported=%{public}s materialActive=%{public}s probe=%{public}s',
      deviceInfo.sdkApiVersion, String(this.supported), String(isSystemMaterialActive()),
      this.materialProbeText);
  }

  // 栏级沉浸光感：官方在标题栏上唯一的材质入口（@since 6.1.0(23) → apiAvailable 门控）
  private probeMaterial(): SystemMaterialParams | undefined {
    if (!deviceInfo.apiAvailable('6.1.0')) {
      this.materialProbeText = "apiAvailable('6.1.0')=false → 本机不支持 systemMaterialEffect，未传材质";
      return undefined;
    }
    try {
      const types: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
      const names: string = types.map((t: hdsMaterial.MaterialType): string => String(t)).join('/');
      this.materialProbeText = `getSystemMaterialTypes()=[${names}] · 已传 IMMERSIVE + EXQUISITE`;
      if (types.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0) {
        const params: SystemMaterialParams = {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          // 与 HdsMenuVerifyPage 顶栏保持同一档，两页观感必须可比，否则原型结论不可迁移
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE,
        };
        return params;
      }
      this.materialProbeText += ' · 设备不支持 IMMERSIVE';
    } catch (e) {
      this.materialProbeText = `hdsMaterial 探测失败：${String(e)}`;
    }
    return undefined;
  }

  // 右上角两枚官方圆：对应 Index.ets 里现在自绘的分享 / 设置
  private menuItems(): Array<HdsNavigationMenuItemOptions> {
    const shareContent: HdsNavigationIconOptions = {
      icon: $r('app.media.action_share'),
      label: '分享',
      action: (): void => {
        this.lastTapped = '分享（官方 content.menu 项）';
      },
    };
    const settingContent: HdsNavigationIconOptions = {
      icon: $r('app.media.set_gear'),
      label: '设置',
      action: (): void => {
        this.lastTapped = '设置（官方 content.menu 项）';
      },
    };
    const first: HdsNavigationMenuItemOptions = { content: shareContent };
    const second: HdsNavigationMenuItemOptions = { content: settingContent };
    return [first, second];
  }

  // 逐层显式标注 SDK 类型：ArkTS 对深层嵌套对象字面量的类型推断不友好
  private protoTitleBarOptions(): HdsNavigationTitleBarOptions {
    const menu: HdsNavigationMenuContentOptions = { value: this.menuItems() };
    const segRow: BottomBuilderParams = {
      builder: (): void => { this.barBody(); },
      // 随状态重配已实测成立（82→126→82vp 双向跟手，基准 §7.6.9），所以资料区可以住进栏体，
      // 保住已上线「我的」的视觉顺序：标题行 → 资料区 → 主分段 → 子分段。
      height: this.barBuilderHeight(),
    };
    const content: TitleBarContentOptions = {
      // 实验④：标题改 stackBuilder 自排（为保住工程的衬线字族），只留 menu 是官方的。
      // 要回答的是「自排标题行会不会把官方圆挤掉」——若共存，迁移就没有取舍。
      stackBuilder: (): void => { this.serifTitleRow(); },
      menu: menu,
      bottomBuilder: segRow,
    };
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(BLUR_END_OFFSET_VP),
    };
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: { backgroundStyle: { backgroundColor: Color.Transparent } },
    };
    if (this.material !== undefined) {
      style.systemMaterialEffect = this.material;
    }
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      // 实验②（单变量）：true 时内容区被栏体顶开、列表永远穿不到栏底（实测 Scroll 起点 = 栏底
      // y=675px，与已上线「我的」的 BarStyle.STACK 覆盖式观感不等价）。改 false 让内容区从窗口
      // 原点起算，穿底由列表自己的 topInset 让位 —— 这才是旧栏的等价配置。
      enableComponentSafeArea: false,
    };
    return options;
  }

  // 衬线标题行：工程「我的」标题用的是 titleSerif 字族，官方 content.title 只有系统字体，
  // 所以标题走 stackBuilder 自排、圆钮仍归 content.menu。
  @Builder
  serifTitleRow() {
    Row() {
      Text('我的')
        .fontSize(TypeTokens.titleSerif.size)
        .fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.titleSerif.weight)
        .lineHeight(TypeTokens.titleSerif.lineHeight)
        .fontColor(ColorTokens.primary)
    }
    .width('100%')
    .height('100%')
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
    .alignItems(VerticalAlign.Center)
  }

  // 栏体内容：资料区 + 主分段 + （子分段）。整块由 bottomBuilder 承载，高度由 barBuilderHeight 声明。
  @Builder
  barBody() {
    Column() {
      this.heroBlock()
      ImmersiveSegmentBar({
        items: PROFILE_SEGMENTS,
        selectedIndex: $mainSegIdx,
        itemWidth: 67,
        buttonHorizontalPadding: SpaceTokens.xs,
      })
      if (this.hasSubSeg()) {
        Column() {
          ImmersiveSegmentBar({
            items: BOOKMARK_SEGMENTS,
            selectedIndex: $subSegIdx,
          })
        }
        .width('100%')
        .margin({ top: SpaceTokens.xs })
      }
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: LayoutTokens.segmentBarTopRoom })
  }

  // 资料区：从旧标题栏搬到内容区顶部，钉住不滚走，让列表从它底下穿过
  @Builder
  heroBlock() {
    Row({ space: SpaceTokens.md }) {
      Column() {
        Text('据')
          .fontSize(TypeTokens.title.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      .width(68)
      .height(68)
      .justifyContent(FlexAlign.Center)
      .borderRadius(34)
      .backgroundColor('#4A90D9')

      Column({ space: SpaceTokens.xs }) {
        Text('抹茶味的琴')
          .fontSize(TypeTokens.title.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.title.weight)
          .fontColor(ColorTokens.primary)
        Text('代码改变世界')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
    // 不铺自己的底色：资料区现在住在栏体里，铺 opaque 会把栏级材质截成两段，
    // 在资料区与分段栏之间留一条接缝。让材质整块铺过去才是已上线「我的」的观感。
    .onAreaChange((_old: Area, area: Area): void => {
      // 内容驱动高度 → 回写栏体声明高（bottomBuilder.height 可随状态重配，§7.6.9）
      const h: number = parseFloat(String(area.height));
      if (h > 0 && Math.abs(h - this.heroHVp) > 0.5) {
        this.heroHVp = h;
      }
    })
  }

  @Builder
  cardList() {
    Scroll(this.scroller) {
      Column({ space: SpaceTokens.sm }) {
        // 让开整条栏（标题行 + 栏体），列表首颗卡片才落在资料区下面；
        // 栏体高随内容/分段变化，所以这里必须与 barBuilderHeight 同源，不能写死。
        Column().width('100%').height(this.listInset())

        ForEach(PROTO_CARDS, (c: ProtoCard) => {
          Column() {
            Text(c.title)
              .fontSize(TypeTokens.body.size)
              .fontFamily(TypeTokens.fontFamily)
              .fontColor(Color.White)
          }
          .width('100%')
          .height(150)
          .justifyContent(FlexAlign.Center)
          .linearGradient({ angle: 135, colors: [[c.colorFrom, 0], [c.colorTo, 1]] })
          .borderRadius(RadiusTokens.md)
        }, (c: ProtoCard) => c.title)

        Text(this.materialProbeText)
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
        Text(`最近一次点击：${this.lastTapped}`)
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
      }
      .width('100%')
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: LayoutTokens.floatingBarReserve })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .clip(false)
  }

  build() {
    if (this.supported) {
      HdsNavigation() {
        this.cardList()
      }
      .titleMode(HdsNavigationTitleMode.MINI)
      .titleBar(this.protoTitleBarOptions())
      .bindToScrollable([this.scroller])
      .width('100%')
      .height('100%')
      .clip(false)
      // 与 HdsMenuVerifyPage 顶栏同一背板：承载系统材质的画布底（浅 #F1F3F5 / 深 #121212，
      // = 原生电话 Navigation 节点真值），不是工程 canvas 的纯白 —— 纯白会把材质圆的
      // rim/落影压平（基准 §7.6.3）。必须走 token 而不是写死 #F1F3F5：深色模式下官方标题
      // 与图标是白字，压在浅色画布上直接不可读（§7.6.8）。
      .backgroundColor(ColorTokens.materialCanvas)
    } else {
      Column({ space: SpaceTokens.sm }) {
        Text('本机不支持 HdsNavigation（需 API ≥ 20 且具备 HDS 系统能力）')
          .fontSize(TypeTokens.body.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.primary)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.bg_primary'))
    }
  }
}
