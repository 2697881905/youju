// HDS 导航验证页（临时页面 · 验证完成后随设置页入口一并删除）
//
// 目的：在独立页面里验证「HdsNavigation + 官方骨架承载 + 官方渐变模糊（GRADIENT_BLUR）」，
// 通过后再把同一套结构迁到首页（Index.ets / HomeTab.ets），主链路零改动、天然可回滚。
//
// 官方骨架承载（真机修正后的结构，也是首页将来的形态；华为应用市场同构）：
//   系统标题栏：品牌进系统标题（FREE 大标题 '有据' + 副标题 '真实经验，有据可循'，滚动自动收起）；
//               搜索进 menu；分段栏（推荐/关注）+ 圈子 chip 进 bottomBuilder（官方自定义区，
//               应用市场的页签行即此结构，栏高由系统计算、无任何自校准）。
//   内容区：纯信息流（List），不设吸顶头 —— 真机实测：吸顶头（不透明底、钉在内容区顶部）
//           会挡住滚动内容，内容到不了标题栏下方，「穿底 + 渐变模糊」不成立。
//
// 模糊基线（按官方文档《设置动态模糊样式》/S0 实测口径）：
//   ScrollEffectType.GRADIENT_BLUR + 生效区间 0 → 64vp + originalStyle 透明起步 + enableComponentSafeArea；
//   双页（Swiper × 两个 List）都要交给 bindToScrollable；穿底绘制链路上的每一层都必须关裁切：
//   HdsNavigation.clip(false) + Swiper.clip(false)（Swiper 默认裁切子节点！）+ List.clip(false)
//   + cachedCount(_, true)，任何一层裁切都会把内容切在栏底，模糊没有东西可「糊」。
//   材质：uiMaterial（沉浸光感）官方生效区域 = 标题栏 —— bottomBuilder 里的分段栏/chip 挂
//   useSystemMaterial 才生效；放进内容区则修饰器静默失效（真机实测教训）。
//
// 验证清单（真机）：
//   ① 静止态无黑带、内容从栏下开始；② 滚动穿底渐入渐变模糊、回弹还原；
//   ③ 双页都能驱动模糊；④ 栏高 = FREE 大标题 + bottomBuilder（应用市场观感）；
//   ⑤ bottomBuilder 分段/chip 交互与沉浸光感材质正常；⑥ 低版本（API < 20）回退不崩。
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import type {
  HdsNavigationTitleBarOptions,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  ScrollEffectOptions,
  BottomBuilderParams,
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import deviceInfo from '@ohos.deviceInfo';
import hilog from '@ohos.hilog';
import { ColorTokens } from '../design/tokens/color';
import { TypeTokens } from '../design/tokens/type';
import { SpaceTokens, LayoutTokens } from '../design/tokens/space';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { Pressable } from '../design/motion/Pressable';
import { SegmentedControl } from '../design/components/SegmentedControl';
import type { SegmentedItem } from '../design/components/SegmentedControl';
import { BackButton } from '../design/components/BackButton';
import { TagNav } from '../components/TagNav';
import { resolveActionIcon } from '../utils/actionIcons';
import { isSystemMaterialActive, TopButtonMaterialModifier } from '../utils/immersiveMaterial';
import { Tag } from '../models/types';

const DOMAIN: number = 0x0000;
const VERIFY_TAG: string = 'HdsNavVerify';

// 双门禁：SDK 版本 + HDS 系统能力（与 utils/immersiveMaterial.ets 同源口径，避免 import 不存在模块即崩）
const HDS_NAV_MIN_API: number = 20;
const HDS_SYSCAP: string = 'SystemCapability.UIDesign.HDSComponent.Core';
function isHdsNavSupported(): boolean {
  try {
    return deviceInfo.sdkApiVersion >= HDS_NAV_MIN_API && canIUse(HDS_SYSCAP);
  } catch (e) {
    return false;
  }
}

// 滚动模糊生效区间终点（vp）：0 → 64，滚动 64vp 内模糊线性到位（官方默认 8 偏快，首页需要更缓的渐入感）
const BLUR_END_OFFSET_VP: number = 64;

// bottomBuilder 行高：44 = minTouchTarget（搜索按钮满高触控目标；分段/chip 控件 36 由 Row 居中）。
// 原 52 = 36 + 8×2（无搜索按钮时）；真机第五轮搜索挪入本行后以内边距归零保持 44 不反弹。
const TAB_ROW_BUILDER_HEIGHT: number = LayoutTokens.minTouchTarget;

// bottomBuilder 分段行：推荐/关注（与 Swiper 双页一一对应；「每日一帖」不属本页验证范围）
const VERIFY_SEGMENTS: SegmentedItem[] = [
  { key: 'recommend', label: '推荐' },
  { key: 'following', label: '关注' },
];

// 圈子 chip 占位数据（下沉内容区后仍走 TagNav 原组件；下拉面板宿主在内容层）
const VERIFY_TAGS: Tag[] = [
  { id: 1, name: '全部' },
  { id: 2, name: '职场' },
  { id: 3, name: '生活' },
  { id: 4, name: '科技' },
  { id: 5, name: '旅行' },
  { id: 6, name: '美食' },
];

interface VerifyCardData {
  title: string;
  desc: string;
  colorFrom: string;
  colorTo: string;
}

// 高饱和渐变卡：模糊效果在彩色内容上肉眼可辨（白底纯文字看不出模糊）
const VERIFY_CARDS: VerifyCardData[] = [
  { title: '晨间阅读', desc: '光线最好的半小时留给纸书', colorFrom: '#4A90D9', colorTo: '#8E7CC3' },
  { title: '茶与咖啡', desc: '手冲参数记在手边的小本上', colorFrom: '#D98C4A', colorTo: '#C35A5A' },
  { title: '城市漫步', desc: '沿着河堤走到桥下再折返', colorFrom: '#3FA46A', colorTo: '#2E7D9E' },
  { title: '胶片摄影', desc: '一卷 36 张，按快门要慢', colorFrom: '#B25EC7', colorTo: '#5C6BC0' },
  { title: '旧书重读', desc: '折角那页正好是三年前停下的地方', colorFrom: '#C77E5E', colorTo: '#8D6E63' },
  { title: '深夜食堂', desc: '一碗热汤面收尾加班日', colorFrom: '#455A64', colorTo: '#1A237E' },
  { title: '周末远足', desc: '山脊线上的风比城里凉两度', colorFrom: '#7CB342', colorTo: '#00897B' },
  { title: '观星记录', desc: '无月夜，猎户座悬在正南方', colorFrom: '#3949AB', colorTo: '#1A1A2E' },
  { title: '早市观察', desc: '摊主会把最红的番茄摆在最前面', colorFrom: '#EF6C00', colorTo: '#AD1457' },
  { title: '雨天的窗', desc: '雨点敲窗的节奏适合发呆', colorFrom: '#5C8AA8', colorTo: '#37474F' },
  { title: '晚风来信', desc: '晾台上的风把便签吹得哗哗响', colorFrom: '#EC407A', colorTo: '#7B1FA2' },
  { title: '晨跑路线', desc: '沿江五公里，慢速人格外多', colorFrom: '#26A69A', colorTo: '#1565C0' },
];

@Entry
@Component
struct HdsNavVerifyPage {
  // 进入页面即定值（进程级缓存），不需要响应式
  private supported: boolean = isHdsNavSupported();
  private verifyStack: NavPathStack = new NavPathStack();
  // Swiper 双页各一个独立滚动容器：都要交给 bindToScrollable（官方：多滚动容器用数组传入）
  private feedScroller0: Scroller = new Scroller();
  private feedScroller1: Scroller = new Scroller();
  private statusBarHeight: number = AppStorage.get<number>('statusBarHeight') ?? 24;
  // 搜索按钮同源材质修饰器（沉浸光感，标题栏 = 官方生效区域；真机第五轮随搜索挪入 bottomBuilder）
  private searchMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();
  // 顶栏共享态（bottomBuilder 里的分段栏/chip 与信息流联动）
  @State segmentIndex: number = 0;
  @State slidePosition: number = -1;
  @State tagIndex: number = 0;
  @State showCircleDropdown: boolean = false;

  aboutToAppear(): void {
    hilog.info(DOMAIN, VERIFY_TAG,
      'enter: sdkApiVersion=%{public}d, supported=%{public}s, materialActive=%{public}s',
      deviceInfo.sdkApiVersion, String(this.supported), String(isSystemMaterialActive()));
  }

  // 标题栏配置：官方骨架（系统标题 = 品牌；menu = 搜索；无任何自绘内容进系统栏）
  // 逐层显式标注 SDK 类型：ArkTS 对深层嵌套对象字面量的类型推断不友好（旧 POC 同款写法）。
  private verifyTitleBarOptions(): HdsNavigationTitleBarOptions {
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(BLUR_END_OFFSET_VP),
    };
    // originalStyle 透明起步（沉浸式：静止时不遮挡首屏内容）；滚动后的样式走渐变模糊的官方默认。
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: {
        backgroundStyle: { backgroundColor: Color.Transparent },
      },
    };
    const content: TitleBarContentOptions = {
      // 实验记录（真机第七轮，路线 B 定稿）：第六轮发现 stackBuilder 落点 = 应用市场标题的
      // 同一高度（顶部行）——应用市场的「探索」根本不在 FREE 大标题块里，而是自绘在顶部行。
      // 据此：titleMode 换 MINI（下方 FREE 大标题块消失，栏高 ≈ 状态栏 + 56 + 44）、
      // 品牌「有据」自绘进 stackBuilder 与搜索同一行、content.title 整个移除。
      stackBuilder: (): void => { this.verifyBrandRow(); },
      // 分段栏 + 圈子 chip 进 bottomBuilder（官方自定义区，应用市场页签行同构）——
      // 分段/chip 处于标题栏内，uiMaterial 沉浸光感的官方生效区域，useSystemMaterial 材质生效。
      bottomBuilder: {
        builder: (): void => { this.verifyTabRow(); },
        height: TAB_ROW_BUILDER_HEIGHT,
      } as BottomBuilderParams,
    };
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      // 安全区避让（真机第四轮）：默认 false 时标题栏内容不避让安全区 —— 搜索 menu 从屏幕
      // 最顶开始布局，与系统通知栏（状态栏）重合。置 true 让标题栏内容（menu/返回键）从
      // 安全区边界开始布局（迁移文档 §6.2 方案一）；大标题块位置是否随动 → 装机观察。
      avoidLayoutSafeArea: true,
      // 组件级安全区：静止时内容从栏下开始、滚动时内容穿入栏下被渐变模糊 —— S0 实测组合
      enableComponentSafeArea: true,
    };
    return options;
  }

  // bottomBuilder 分段行：分段栏 + 圈子 chip（应用市场页签行同构）。
  // 行本体透明 —— 背板由标题栏统一绘制；组件自身挂系统材质（标题栏 = uiMaterial 官方生效区域）。
  @Builder
  verifyTabRow() {
    Row() {
      SegmentedControl({
        items: VERIFY_SEGMENTS,
        selectedIndex: $segmentIndex,
        slidePosition: this.slidePosition,
        itemWidth: 66,
        fillWidth: false,
        glass: false,
        outlined: true,
        // 关闭按压/长按光斑：材质玻璃/描边风格上光斑过于抢眼
        glowEnabled: false,
        // 沉浸光感：处于标题栏内（官方生效区域），系统材质接管整栏表面
        useSystemMaterial: true,
      })
      TagNav({
        tags: VERIFY_TAGS,
        selectedIndex: $tagIndex,
        dropdownVisible: $showCircleDropdown,
        compact: true,
        glass: false,
        dropdownOnly: true,
        useSystemMaterial: true,
      })
        .layoutWeight(1)
    }
    .width('100%')
    .height(TAB_ROW_BUILDER_HEIGHT)
    .padding({
      left: SpaceTokens.base,
      right: SpaceTokens.base,
    })
  }

  // stackBuilder 品牌行（路线 B）：品牌块（有据 + SUBSTANTIATE / 标语，旧首页同款）与搜索按钮同一行。
  // stackBuilder 行固定 56vp（旧 POC 实测，超出会居中溢出）——品牌块 32 + 24 = 56 顶格排布（无额外 space）。
  // 搜索按钮规格 = 旧首页同款（44 触控 + 描边 + 同源沉浸光感材质）。
  // 状态栏避让：avoidLayoutSafeArea(true) 已实测覆盖 stackBuilder（第六轮搜索落点 = 应用市场标题高度）；
  // 若品牌块顶进状态栏，回退方案：本 Builder 手动补 statusBarHeight 上内边距。
  @Builder
  verifyBrandRow() {
    Row() {
      Column() {
        Row({ space: SpaceTokens.sm }) {
          Text('有据')
            .fontSize(TypeTokens.titleSerif.size)
            .fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.titleSerif.weight)
            .lineHeight(TypeTokens.titleSerif.lineHeight)
            .fontColor(ColorTokens.primary)
          Text('SUBSTANTIATE')
            .fontSize(TypeTokens.overline.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.overline.weight)
            .fontColor(ColorTokens.tertiary)
        }
        Text('真实经验，有据可循')
          .fontSize(TypeTokens.headline.size)
          .fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .fontColor(ColorTokens.primary)
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Pressable({
        visualHeight: LayoutTokens.minTouchTarget,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        action: (): void => {
          hilog.info(DOMAIN, VERIFY_TAG, 'search clicked (verify stub, brand row in stackBuilder)');
        },
      }) {
        Row() {
          Image(resolveActionIcon('search'))
            .width(IconTokens.small)
            .height(IconTokens.small)
            .fillColor(ColorTokens.icon)
        }
        .width(LayoutTokens.minTouchTarget)
        .height(LayoutTokens.minTouchTarget)
        .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
        .borderRadius(RadiusTokens.lg)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .attributeModifier(this.searchMaterial)
        .accessibilityText('搜索')
      }
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
  }

  // 沉浸式头图：滚动前就在标题栏下方（内容穿底后的穿入观察底图，彩色大块最利于看模糊质量）
  @Builder
  verifyHero() {
    Column({ space: SpaceTokens.xs }) {
      Text('HDS 验证页 · 首页骨架')
        .fontSize(TypeTokens.titleSerif.size)
        .fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.titleSerif.weight)
        .fontColor(Color.White)
      Text('上下滚动，观察内容穿过标题栏时的官方渐变模糊')
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor('#E6FFFFFF')
    }
    .width('100%')
    .height(240)
    .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, bottom: SpaceTokens.lg })
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Start)
    .linearGradient({ angle: 160, colors: [['#1F2A55', 0], ['#4A3C8C', 0.55], ['#8E5AA8', 1]] })
  }

  // 单张内容卡：高饱和渐变底 + 白色文字
  @Builder
  verifyCard(item: VerifyCardData) {
    Column({ space: SpaceTokens.xs }) {
      Text(item.title)
        .fontSize(TypeTokens.headline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(Color.White)
      Text(item.desc)
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor('#D9FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(96)
    .margin({ left: SpaceTokens.base, right: SpaceTokens.base })
    .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .borderRadius(RadiusTokens.lg)
    .linearGradient({ angle: 135, colors: [[item.colorFrom, 0], [item.colorTo, 1]] })
  }

  // 单页信息流：纯 List（无吸顶头 —— 真机实测吸顶头会挡住穿底内容）+ clip(false)/cachedCount 保穿底绘制
  @Builder
  verifyFeedPage(scroller: Scroller) {
    List({ scroller: scroller, space: SpaceTokens.md }) {
      ListItem() {
        this.verifyHero()
      }
      ForEach(VERIFY_CARDS, (item: VerifyCardData) => {
        ListItem() {
          this.verifyCard(item)
        }
      }, (item: VerifyCardData) => item.title)
      ListItem() {
        Text('临时验证页 · 验证完成后随入口一并删除')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.xl })
      }
    }
    // 不裁剪：让内容画到标题栏下方（模糊采样素材）；cachedCount 保证穿入栏下的条目不被回收
    .clip(false)
    .cachedCount(3, true)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .width('100%')
    .height('100%')
  }

  // HdsNavigation 分支（API 20+ 真机）：官方骨架 + 官方渐变模糊
  @Builder
  hdsBranch() {
    HdsNavigation(this.verifyStack) {
      Stack({ alignContent: Alignment.TopStart }) {
        // 信息流：Swiper 双页 × 独立 List（首页 Swiper 结构的代理）
        Swiper() {
          this.verifyFeedPage(this.feedScroller0)
          this.verifyFeedPage(this.feedScroller1)
        }
        .index(this.segmentIndex)
        .loop(false)
        .indicator(false)
        .onChange((index: number): void => {
          this.segmentIndex = index;
        })
        // 拖动/吸附逐帧联动滑块（1:1 跟手；与 HomeTab 同款口径）
        .onContentDidScroll((selectedIndex: number, index: number, position: number, _mainAxisLength: number): void => {
          if (index !== selectedIndex) {
            return;
          }
          const continuous: number = selectedIndex - position;
          this.slidePosition = Math.max(0, Math.min(VERIFY_SEGMENTS.length - 1, continuous));
        })
        .onAnimationEnd((): void => {
          if (Math.abs(this.slidePosition - Math.round(this.slidePosition)) < 0.01) {
            this.slidePosition = -1;
          }
        })
        // ⚠️ Swiper 默认裁切子节点：不关掉它，List 穿出顶边的内容会被切在栏底，「穿底」不成立
        .clip(false)
        .width('100%')
        .height('100%')

        // 圈子下拉面板宿主（吸顶 chip 通过共享态开合）：面板 + 点外关闭遮罩渲染在内容层，向下覆盖信息流
        if (this.showCircleDropdown) {
          TagNav({
            tags: VERIFY_TAGS,
            selectedIndex: $tagIndex,
            dropdownVisible: $showCircleDropdown,
            compact: true,
            glass: false,
            dropdownOnly: true,
            panelOnly: true,
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .hideBackButton(true)
    .titleBar(this.verifyTitleBarOptions())
    // 路线 B（真机第七轮定稿）：MINI 模式——栏内只有顶部行（stackBuilder 品牌行）+ bottomBuilder，
    // FREE 的大标题块不再占位（四~六轮实验已证其系统锁死且位置偏低，应用市场同款顶部行结构）。
    .titleMode(HdsNavigationTitleMode.MINI)
    // 关键：绑定全部滚动容器（Swiper 双页各一个），否则标题栏不跟手、模糊不生效
    .bindToScrollable([this.feedScroller0, this.feedScroller1])
    // 关闭容器自身裁切：穿底内容需一路画到标题栏下方（与主框架 Navigation.clip(false) 同理）
    .clip(false)
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
  }

  // 回退分支（模拟器 / API < 20 / 无 HDS syscap）：内容同构，仅无系统模糊标题栏，保证页面可用不崩
  @Builder
  fallbackBranch() {
    Column() {
      Row({ space: SpaceTokens.sm }) {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Text('HDS 验证页（回退）')
          .fontSize(TypeTokens.headline.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.primary)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({
        left: SpaceTokens.sm,
        right: SpaceTokens.sm,
        top: this.statusBarHeight + SpaceTokens.sm,
        bottom: SpaceTokens.sm,
      })

      Column() {
        Text('当前设备/模拟器不支持 HDS 滚动模糊标题栏（需 API 20+ 且具备 HDS syscap），已回退为普通滚动页。')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
      }
      .width('100%')
      .padding(SpaceTokens.md)
      .margin({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: SpaceTokens.sm })
      .borderRadius(RadiusTokens.md)
      .backgroundColor(ColorTokens.subtle)

      Scroll() {
        Column({ space: SpaceTokens.md }) {
          this.verifyHero()
          ForEach(VERIFY_CARDS, (item: VerifyCardData) => {
            this.verifyCard(item)
          }, (item: VerifyCardData) => item.title)
        }
        .width('100%')
        .padding({ bottom: SpaceTokens.xl })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
  }

  build() {
    if (this.supported) {
      this.hdsBranch()
    } else {
      this.fallbackBranch()
    }
  }
}