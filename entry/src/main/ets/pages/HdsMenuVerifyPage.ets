// 顶栏圆钮官方实现验证页（临时页面 · 验证完成后随设置页入口一并删除）
//
// 目的：确认 HdsNavigation.titleBar({ content: { menu } }) 能否直接产出原生电话顶栏那枚 40vp
// 官方圆钮（圆底 / 高光 / 投影由组件内部绘制），替代现在 pages/Index.ets:1047 起
// 「Pressable + Image + 36vp 圆角 + 仅材质」的自绘做法。
// 基准数值取自 docs/harmonyos-official-ui-alignment-baseline.md §7.6（真机原生电话实测）。
//
// 验证清单（真机，浅色 / 深色各抓一帧）：
//   ① 默认表面 —— 上一轮实测（浅色、白底页面）：Button backgroundColor = **#0C000000（3% 黑）**，
//      渲染 #F7F7F7(L247) vs 页面 #FFFFFF(L255)，**无高光、无投影**。
//      ⚠️ 这与基准 §7.6 里电话 App 那颗圆（#F5F6F8 比页面**亮** 3 L + #FEFFFF 高光 + 正下方 −8 L 投影）
//      **不是同一个东西**：3% 黑叠在 #F1F3F5 上只会更暗，不可能亮 3 L。所以电话那颗圆的抬升感
//      来自材质（TitleBarStyleOptions.systemMaterialEffect / hdsMaterial）或显式 menuStyle，
//      不是 content.menu 的默认值。本页只测默认值，材质那一档留作下一个单变量实验。
//   ② 排布：项宽 40vp、项间距 8vp —— 上一轮实测 HdsMenuNode 136vp = 40×3 + 8×2 ✓ 已确认。
//   ③ maxCount 默认 3 —— 上一轮传 4 项，第 4 项被折进官方 Button **key=hdsNavigationMoreButton**
//      （40×40 @x=307.5，与电话 App dialerMenuHds 同槽位，图标是官方自绘的 4 点）。已确认。
//   ④ icon 双类型 —— 上一轮实测不一致：SymbolGlyphModifier 默认只有 **16vp**，app.media 按给定的 24vp。
//      本轮补 fontSize(24) 复测能否对齐。
//   ⑤ badge.count 能否叠在官方圆上 —— 本轮起 3 项不折叠，badge 挂在第 1 项上实测。
//   ⑥ 内容区并排贴一枚现状自绘圆（36vp + 仅材质），与标题栏官方圆同帧比对。
//
// 已知风险（旧验证页第四轮教训，见 HdsNavVerifyPage.ets 内注释）：avoidLayoutSafeArea 为 false 时
// menu 从屏幕最顶开始布局、与状态栏重合 → 本页显式置 true。
import { HdsNavigation, HdsNavigationTitleMode, hdsMaterial, ScrollEffectType } from '@kit.UIDesignKit';
import type {
  HdsNavigationTitleBarOptions,
  TitleBarContentOptions,
  TitleBarStyleOptions,
  ScrollEffectOptions,
  BottomBuilderParams,
  SystemMaterialParams,
  HdsNavigationMenuContentOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationIconOptions,
  HdsNavigationBadgeOptions,
  HdsNavigationTitle,
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier, LengthMetrics } from '@kit.ArkUI';
import deviceInfo from '@ohos.deviceInfo';
import hilog from '@ohos.hilog';
import { ColorTokens } from '../design/tokens/color';
import { TypeTokens } from '../design/tokens/type';
import { SpaceTokens, LayoutTokens } from '../design/tokens/space';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { Pressable } from '../design/motion/Pressable';
import { resolveActionIcon } from '../utils/actionIcons';
import { isSystemMaterialActive, TopButtonMaterialModifier, FloatingTopButtonMaterialModifier } from '../utils/immersiveMaterial';

const DOMAIN: number = 0x0000;
const MENU_TAG: string = 'HdsMenuVerify';

// 双门禁：SDK 版本 + HDS 系统能力（与 HdsNavVerifyPage / immersiveMaterial 同源口径）
const HDS_NAV_MIN_API: number = 20;
const HDS_SYSCAP: string = 'SystemCapability.UIDesign.HDSComponent.Core';
// 渐变模糊生效区间终点（与首页同款口径：0 → 64vp）
const BLUR_END_OFFSET_VP: number = 32;   // 与生产「我的」同值，保证两页可比
// B 方案样本行高：40vp 按钮 + 下方 ≥26.9vp 投影净空 + 上方 ≥10.9vp，取 96vp 富余
const PLAN_B_ROW_HEIGHT_VP: number = 48;
function isHdsNavSupported(): boolean {
  try {
    return deviceInfo.sdkApiVersion >= HDS_NAV_MIN_API && canIUse(HDS_SYSCAP);
  } catch (e) {
    return false;
  }
}

// 官方基准（§7.6）与现状自绘的差异，直接列成页面上的对照行，便于真机边看边核
interface CompareRow {
  label: string;
  official: string;
  ours: string;
}

const COMPARE_ROWS: CompareRow[] = [
  { label: '可视尺寸', official: '40 × 40vp 圆', ours: '36 × 36vp（radius 20 → 实际也是圆）' },
  { label: '触控目标', official: '40vp（槽位 56vp）', ours: '44vp（minTouchTarget）' },
  { label: '浅色圆底', official: '默认 #0C000000（3% 黑）实测 #F7F7F7，无高光无投影', ours: '无底色，仅系统材质' },
  { label: '电话 App 那颗', official: '#F5F6F8 比页面亮 3 L + 高光 + 投影 −8 L → 来自材质', ours: '—' },
  { label: '图标', official: 'SymbolGlyph 24.3vp；符号项默认仅 16vp', ours: 'Image 24vp + fillColor' },
  { label: '项间距 / 右缘', official: '8vp / 距屏 16vp（HdsMenuNode 136 = 40×3+8×2）', ours: '手写 Row 间距' },
];

interface Swatch {
  bg: ResourceColor;
  label: string;
}

// 彩色卡：白底纯文字看不出材质在合成什么（旧验证页实测教训），给栏底一条有彩度的内容带，
// 渐变模糊 / 材质才有东西可采样，圆下方那层接触阴影才可能显出来。
const SWATCHES: Swatch[] = [
  { bg: '#4A90D9', label: '蓝' },
  { bg: '#D98C4A', label: '橙' },
  { bg: '#3FA46A', label: '绿' },
  { bg: '#B25EC7', label: '紫' },
  { bg: '#C35A5A', label: '红' },
  { bg: '#2E7D9E', label: '青' },
];

@Entry
@Component
struct HdsMenuVerifyPage {
  @State lastTapped: string = '（还没点过标题栏的官方圆）';
  @State materialProbeText: string = '（材质探测未执行）';
  private supported: boolean = isHdsNavSupported();
  private material: SystemMaterialParams | undefined = undefined;
  private scroller: Scroller = new Scroller();
  private actionMaterial: TopButtonMaterialModifier = new TopButtonMaterialModifier();
  private floatingMaterial: FloatingTopButtonMaterialModifier = new FloatingTopButtonMaterialModifier();

  aboutToAppear(): void {
    this.material = this.probeMaterial();
    hilog.info(DOMAIN, MENU_TAG,
      'enter: sdkApiVersion=%{public}d, supported=%{public}s, materialActive=%{public}s, probe=%{public}s',
      deviceInfo.sdkApiVersion, String(this.supported), String(isSystemMaterialActive()),
      this.materialProbeText);
  }

  // 逐层显式标注 SDK 类型：ArkTS 对深层嵌套对象字面量的类型推断不友好（旧 POC 同款写法）
  // 本轮 3 项（不再触发折叠）：折叠行为上一轮已实测 —— 4 项时第 4 项被折进官方
  // Button key=hdsNavigationMoreButton（40×40 @x=307.5，与电话 App dialerMenuHds 同槽位）。
  // 留两个开放问题：① badge 能否叠在官方圆上（上一轮被折叠项挡住了）；
  // ② SymbolGlyphModifier 默认只有 16vp（上一轮实测），补 fontSize 后能否与 24vp 图片项对齐。
  private menuItems(): Array<HdsNavigationMenuItemOptions> {
    const symbolModifier = new SymbolGlyphModifier($r('sys.symbol.ohos_wifi'));
    symbolModifier.fontSize(24);
    const symbolContent: HdsNavigationIconOptions = {
      icon: symbolModifier,
      label: '符号字体项',
      action: (): void => {
        this.lastTapped = '① 符号字体项（SymbolGlyphModifier + fontSize 24）';
      },
    };
    const shareContent: HdsNavigationIconOptions = {
      icon: $r('app.media.action_share'),
      label: '图片项',
      action: (): void => {
        this.lastTapped = '② 图片项（app.media.action_share）';
      },
    };
    const moreContent: HdsNavigationIconOptions = {
      icon: $r('app.media.action_more'),
      label: '四点项',
      action: (): void => {
        this.lastTapped = '③ 四点项（app.media.action_more）';
      },
    };
    const badge: HdsNavigationBadgeOptions = { count: 3 };
    const first: HdsNavigationMenuItemOptions = { content: symbolContent, badge: badge };
    const second: HdsNavigationMenuItemOptions = { content: shareContent };
    const third: HdsNavigationMenuItemOptions = { content: moreContent };
    return [first, second, third];
  }

  // 本轮单变量实验：标题栏唯一的官方材质入口是 style.systemMaterialEffect（栏级，
  // SystemMaterialParams{materialType, materialLevel}，hdsMaterial @since 6.1.0(23)）。
  // menuStyle 只暴露 backgroundColor / iconColor / textColor 三个纯色，菜单项也没有 builder 槽位
  // （HdsNavigationIconOptions 只有 icon/label/isEnabled/action/componentId/type），
  // 所以「给官方圆挂通用 systemMaterial 属性」这条路在 content.menu 上根本没有挂载点。
  // 本实验要回答的就是：栏级材质能不能让那颗圆变成电话 App 的浮起观感。
  // 探测放在 aboutToAppear：build() 期间改 @State 会触发重渲染。
  private probeMaterial(): SystemMaterialParams | undefined {
    // systemMaterialEffect / hdsMaterial 均为 @since 6.1.0(23)，工程 compatibleSdk = 6.0.0(20)
    // → 显式 apiAvailable 门控（与 utils/immersiveMaterial.ets 的 26.0.0 门禁同源做法）
    if (!deviceInfo.apiAvailable('6.1.0')) {
      this.materialProbeText = `apiAvailable('6.1.0')=false → 本机不支持 systemMaterialEffect（需 6.1.0(23)），未传材质`;
      return undefined;
    }
    try {
      const types: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
      const names: string = types.map((t: hdsMaterial.MaterialType): string => String(t)).join('/');
      this.materialProbeText = `getSystemMaterialTypes()=[${names}] · apiAvailable('6.1.0')=`
        + `${String(deviceInfo.apiAvailable('6.1.0'))} · 已传 IMMERSIVE + EXQUISITE`;
      if (types.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0) {
        const params: SystemMaterialParams = {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          // 单变量（本轮）：用户描述验证页那颗是「圆润的玻璃**折射**」，生产页那颗只是「透过去」。
          // 折射是几何弯折、不是半透 —— 我上一轮把它从 EXQUISITE 改成 ADAPTIVE，正好是唯一变量。
          // 改回 EXQUISITE 看折射是否回来。
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE,
        };
        return params;
      }
      this.materialProbeText += ' · ⚠️ 设备不支持 IMMERSIVE，未传材质';
    } catch (e) {
      this.materialProbeText = `hdsMaterial 探测失败（低于 6.1.0(23) 或无 HDS 能力）：${String(e)} · 未传材质`;
      hilog.warn(DOMAIN, MENU_TAG, 'getSystemMaterialTypes failed: %{public}s', String(e));
    }
    return undefined;
  }

  // B 方案样本：自己的 Button + 通用属性 systemMaterial(applyShadow: true)。
  // 净空是这一档成立的前提：材质投影向下散 26.9vp、向上 10.9vp，所以本行给到 96vp 高、
  // 40vp 按钮顶置 → 按钮下方留 ~48vp，投影完整落在行内，不会被裁成灰带
  // （被裁就是 TopButtonMaterialModifier 关投影的历史原因，见 utils/immersiveMaterial.ets:133）。
  @Builder
  planBRow() {
    Column() {
      Row({ space: SpaceTokens.base }) {
        Button({ type: ButtonType.Circle }) {
          Image(resolveActionIcon('share'))
            .width(IconTokens.standard)
            .height(IconTokens.standard)
            .fillColor(ColorTokens.icon)
        }
        .width(40)
        .height(40)
        // ButtonType.Circle 自带默认蓝底 #FF0A59F7，会把材质表面整个盖住（上一轮实测踩到）
        // → 必须透明底，让 systemMaterial 自己画表面
        .backgroundColor(Color.Transparent)
        .attributeModifier(this.floatingMaterial)
        .accessibilityText('B 方案样本钮')

        Text('← B 方案：自研 Button + systemMaterial(applyShadow:true)，行高 96vp 给足净空')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.sm })
    }
    .width('100%')
    .height(PLAN_B_ROW_HEIGHT_VP)
    .alignItems(HorizontalAlign.Start)
  }

  private verifyTitleBarOptions(): HdsNavigationTitleBarOptions {
    const title: HdsNavigationTitle = { mainTitle: '顶栏圆钮对比', subTitle: '官方 content.menu' };
    const menu: HdsNavigationMenuContentOptions = { value: this.menuItems() };
    const content: TitleBarContentOptions = {
      title: title,
      menu: menu,
      // B 方案样本挂进 bottomBuilder：这一行仍在标题栏内（systemMaterial 的官方生效区域），
      // 但行高由我们给到 96vp，投影不会被裁。
      bottomBuilder: {
        builder: (): void => { this.planBRow(); },
        height: PLAN_B_ROW_HEIGHT_VP,
      } as BottomBuilderParams,
    };
    // 官方完整配方（对齐电话 App 的节点结构：它的 HdsTitleBar 下有 MaskBlur + Mask 两个子节点，
    // 我们上一版没有 —— 因为没有开滚动模糊。MaskBlur/Mask 就是渐变模糊栏产生的遮罩层。）
    // ⚠️ 与生产「我的」保持同一配方，否则两页观感不可比：档位必须 IMMERSIVE_GRADIENT_BLUR
    // （GRADIENT_BLUR 是空间渐变，栏一高下半条就糊不住）+ blurRadius 50 + 终点 32vp。
    // 见基准 §7.6.14。
    const scrollEffect: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(BLUR_END_OFFSET_VP),
    };
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollEffect,
      originalStyle: {
        backgroundStyle: { backgroundColor: Color.Transparent, blurRadius: 50 },
      },
    };
    if (this.material !== undefined) {
      style.systemMaterialEffect = this.material;
    }
    const options: HdsNavigationTitleBarOptions = {
      content: content,
      style: style,
      avoidLayoutSafeArea: true,
      // ⚠️ 必须 false：true 时内容盒被栏体顶开（实测 Scroll 起点 = 栏底 431px），
      // 下面那条彩色带**永远进不到按钮背后**，「卡片从按钮下方滚过」这个场景在本页根本观察不到
      // —— 之前两页「观感一致」的结论就是被这个假对照骗掉的（基准 §7.6.15）。
      // 改 false 后内容从窗口原点起算，彩色带要靠自己那条垫高 spacer 让开栏体（见 cardList 顶部）。
      enableComponentSafeArea: false,
    };
    return options;
  }

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize(TypeTokens.callout.size)
      .fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.callout.weight)
      .fontColor(ColorTokens.secondary)
      .alignSelf(ItemAlign.Start)
      .margin({ top: SpaceTokens.lg, bottom: SpaceTokens.xs })
  }

  @Builder
  compareTable() {
    Column({ space: SpaceTokens.xs }) {
      Row() {
        Text('项').width('26%').fontSize(TypeTokens.caption.size).fontColor(ColorTokens.tertiary)
        Text('官方 content.menu').width('37%').fontSize(TypeTokens.caption.size).fontColor(ColorTokens.tertiary)
        Text('我们现状').width('37%').fontSize(TypeTokens.caption.size).fontColor(ColorTokens.tertiary)
      }
      .width('100%')

      ForEach(COMPARE_ROWS, (row: CompareRow) => {
        Row() {
          Text(row.label).width('26%').fontSize(TypeTokens.caption.size).fontColor(ColorTokens.secondary)
          Text(row.official).width('37%').fontSize(TypeTokens.caption.size).fontColor(ColorTokens.primary)
          Text(row.ours).width('37%').fontSize(TypeTokens.caption.size).fontColor(ColorTokens.primary)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (row: CompareRow) => row.label)
    }
    .width('100%')
    .padding(SpaceTokens.md)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(RadiusTokens.md)
  }

  // 验证清单 ⑥：现状自绘圆（与 Index.ets 的分享钮同款写法）贴在内容区，
  // 与标题栏里的官方圆同帧截图，直接比圆底 / 高光 / 投影 / 尺寸。
  @Builder
  oursSample() {
    Row({ space: SpaceTokens.lg }) {
      Pressable({
        visualHeight: LayoutTokens.segmentedHeight,
        touchTargetHeight: LayoutTokens.minTouchTarget,
        action: (): void => {
          this.lastTapped = '内容区的自绘钮（现状写法）';
        },
      }) {
        Row() {
          Image(resolveActionIcon('share'))
            .width(IconTokens.standard)
            .height(IconTokens.standard)
            .fillColor(ColorTokens.icon)
        }
        .width(LayoutTokens.segmentedHeight)
        .height(LayoutTokens.segmentedHeight)
        .justifyContent(FlexAlign.Center)
        .borderRadius(RadiusTokens.lg)
        .attributeModifier(this.actionMaterial)
        .accessibilityText('自绘钮样例')
      }

      Text('↑ 现状自绘：36vp + 仅材质（无底色 / 无描边 / 无投影）\n↑ 标题栏那排：官方 content.menu，不传 menuStyle')
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(SpaceTokens.md)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(RadiusTokens.md)
  }

  @Builder
  body() {
    Scroll(this.scroller) {
      Column() {
        // 让位垫高：enableComponentSafeArea 改 false 后内容从窗口原点起算，整条栏（106..431px = 104vp）
        // 盖在它上面。垫这一条让彩色带初始停在栏底之下，往上滚才能一路穿到按钮背后。
        Column().width('100%').height(104)

        // 顶部彩色带：滚动时穿到标题栏下方，给渐变模糊/材质提供可采样的彩度
        Row({ space: SpaceTokens.sm }) {
          ForEach(SWATCHES, (s: Swatch) => {
            Column() {
              Text(s.label)
                .fontSize(TypeTokens.caption.size)
                .fontColor(Color.White)
            }
            .layoutWeight(1)
            .height(88)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(s.bg)
            .borderRadius(RadiusTokens.sm)
          }, (s: Swatch) => s.label)
        }
        .width('100%')
        .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.base })

        this.sectionTitle('点一下标题栏的官方圆，验证 action 是否接通')
        Text(this.lastTapped)
          .fontSize(TypeTokens.body.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.primary)
          .alignSelf(ItemAlign.Start)

        this.sectionTitle('官方圆 vs 现状自绘（基准 §7.6）')
        this.compareTable()

        this.sectionTitle('同帧比对')
        this.oursSample()

        this.sectionTitle('本轮单变量：标题栏级 systemMaterialEffect')
        Text(this.materialProbeText)
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .alignSelf(ItemAlign.Start)
        Text('判据：若上面三颗圆的节点 backgroundColor 仍是 #0C000000、渲染仍是 #F7F7F7 且无高光无投影，'
          + '则说明栏级材质不驱动菜单圆 → content.menu 接不上沉浸光感，电话 App 那颗圆的浮起来自别处。')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .alignSelf(ItemAlign.Start)

        this.sectionTitle('本轮两个开放问题')
        Text('① badge.count=3 叠在第 1 个官方圆上，能否正常显示？\n' +
          '② 第 1 项符号图标补了 fontSize(24)，与第 2 项 24vp 图片是否对齐？\n' +
          '（已确认：4 项触发折叠 → hdsNavigationMoreButton；默认圆底是 3% 黑、无高光无投影）')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .lineHeight(TypeTokens.caption.lineHeight * 2)
          .alignSelf(ItemAlign.Start)
      }
      .width('100%')
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: SpaceTokens.x2l })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    // 穿底链路：任何一层裁切都会把内容切在栏底，模糊/材质就没有东西可合成（旧验证页实测）
    .clip(false)
  }

  build() {
    if (this.supported) {
      HdsNavigation() {
        this.body()
      }
      .titleMode(HdsNavigationTitleMode.MINI)
      .titleBar(this.verifyTitleBarOptions())
      .bindToScrollable([this.scroller])
      .width('100%')
      .height('100%')
      .clip(false)
      // 单变量实验：页面底从工程 token canvas(#FFFFFF) 换成系统基色（浅 #F1F3F5 / 深 #121212，
      // = 电话 App Navigation 节点的 backgroundColor 真值）。
      // 材质阴影要落在「比它亮的背板」上才看得见；纯白背板会把 rim/shadow 全部压平。
      // 浅色侧取值与原来写死的 #FFF1F3F5 完全一致；改走 token 只是为了深色侧不再是浅色画布
      // （官方标题/图标在深色下是白字，压浅底不可读 —— 基准 §7.6.8），并与原型页保持同一口径。
      .backgroundColor(ColorTokens.materialCanvas)
    } else {
      // 低版本 / 无 HDS 能力：不挂官方组件，只说明原因（与旧验证页同款回退）
      Column({ space: SpaceTokens.sm }) {
        Text('本机不支持 HdsNavigation（需 API ≥ 20 且具备 HDS 系统能力）')
          .fontSize(TypeTokens.body.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.primary)
        Text(`sdkApiVersion=${deviceInfo.sdkApiVersion}`)
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.bg_primary'))
    }
  }
}
