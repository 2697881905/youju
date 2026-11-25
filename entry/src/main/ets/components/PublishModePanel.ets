// 发布方式页（原「发布方式」半模态面板改造）。
//
// 为什么从弹窗改成页面：底部 Dock 开放了整页左右滑动切页，而发布占位夹在圈子与消息中间 ——
// Tabs 的滑动是**相邻索引**逐格推进，`onContentWillChange` 对 index 2 返回 false 会同时挡住
// 点击与滑动（官方文档触发条件第 1 条即"用户滑动 TabContent"），结果是圈子↔消息之间永远滑不过去。
// 要让滑动链完整，发布必须成为一个可停靠的真实页面。
//
// 与面板版的差别：去掉固定 344 宽与右上角 ✕（页面不需要自己关，滑走或点别的页签即离开），
// 改为整宽排布；表面不再由 SheetOptions 承担，直接站在页面画布上。
//
// 单屏式（2026-11-23 用户拍板删第二屏）：只有「发干货 / 发随记」两张意图卡，底部 AI 提示
// 分别收纳进对应卡（原屏 2 ai-note 收纳为卡内提示块）；点意图卡直接弹系统 showAlertDialog
// 三按钮（图文 / 视频 / 长文）选形式，选中即跳对应发布页。zone 锁定后留在 @State（弹窗
// onSelect 携带 zone），不再需要第二屏与「改」胶囊。
//
// 视觉对齐 design/publish-flow-redesign-prototype.html 屏 1（V1，仅视觉、不动 zone/onSelect）：
// 意图卡 = tint 图标牌 + tertiary「›」+ 贴底内容块（衬线标题 / 副题 / 干货体裁 chips / 提示块），
// 两卡纵向撑满；原型 hex 是示意值，一律走既有 token。暖侧强调按 V4 口径用既有 warm 表面体系
// （底 warmSurfacePrimary + 字/图标 warmAccent 或 warm），不新增 warmTint token。
//
// 避让：本页没有内嵌 HdsNavigation（其余四个主 Tab 都有），所以状态栏与悬浮 Dock 都要自己让 ——
// Dock 是 barOverlap 悬浮的，不让位最后一张卡片会被压在玻璃底下。
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { bottomNavInset, DOCK_BAR_HEIGHT_VP, DOCK_BOTTOM_MARGIN_BASE } from '../utils/cardTokens';
import { FeedZone } from '../utils/feedZones';


export type PublishMode = 'photo' | 'text' | 'video';


// 第一屏意图卡图标牌（原型 glyph 44/14，14 档走 RadiusTokens.md）。
const GLYPH_SIZE: number = 44;
// 标题行高度：与其余四个主 Tab 的 HdsNavigation 标题行同高，切页时标题不会上下跳。
const TITLE_ROW_VP: number = 56;
// 「改」胶囊视觉高：14fp 行高 20 + 上下各 4；触控目标由 Pressable 默认 44 居中外扩兜住。
const CHANGE_PILL_VISUAL_VP: number = 28;

@Component
export struct PublishModePanel {
  onSelect: (mode: PublishMode, zone: FeedZone) => void = (_mode: PublishMode, _zone: FeedZone): void => {};
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  @State zone: FeedZone = 'insight';

  private zoneLabel(): string {
    return this.zone === 'insight' ? '干货' : '随记';
  }

  // 点意图卡 → 系统 showAlertDialog 选形式（用户点名保留系统弹窗质感）。
  // 排版升级全走系统可定制面，不放弃机制：
  // - subtitle 副题行（API 基类字段）承担「选择一种方式开始创作」
  // - buttonDirection.VERTICAL：三按钮自动竖排成全宽选项行（AUTO 对 ≥3 按钮本来也竖排，显式锁定）
  // - 每钮分色：图文=brand/onBrand 主推、视频=warm 面、长文=sunken 中性；「名称 · 副标题」合并进
  //   按钮文案，观感即选项列表
  private showModeDialog(zone: FeedZone): void {
    this.zone = zone;
    // 三钮统一中性浅灰（用户拍板 2026-11-24：不用 tint 分色，统一 sunken 底 + primary 字）。
    this.getUIContext().showAlertDialog({
      title: '发' + this.zoneLabel(),
      subtitle: '选择一种方式开始创作',
      // withOptions 形态要求 message 必填（空串即不占内容行）
      message: '',
      autoCancel: true,
      buttonDirection: DialogButtonDirection.VERTICAL,
      buttons: [
        {
          value: '图文',
          // subtle 中性浅灰（浅 #F2F2F4 / 深 #232326）：sunken 深色是 #0D0D0F 近纯黑，用户真机否决
          backgroundColor: ColorTokens.subtle,
          fontColor: ColorTokens.primary,
          action: (): void => { this.onSelect('photo', zone); },
        },
        {
          value: '视频',
          backgroundColor: ColorTokens.subtle,
          fontColor: ColorTokens.primary,
          action: (): void => { this.onSelect('video', zone); },
        },
        {
          value: '长文',
          backgroundColor: ColorTokens.subtle,
          fontColor: ColorTokens.primary,
          action: (): void => { this.onSelect('text', zone); },
        },
      ],
    });
  }

  // 标题行：衬线标题，位置对齐其余 Tab 的 HdsNavigation 标题行（状态栏 + 56vp）。
  // 字体规格统一用 titleSerif（21/700/32），与圈子/消息/我的三个主 Tab 标题完全一致。
  @Builder
  headerRow(): void {
    Row() {
      Text('发布')
        .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.titleSerif.weight)
        .lineHeight(TypeTokens.titleSerif.lineHeight)
        .fontColor(ColorTokens.primary)
    }
    .width('100%')
    .height(TITLE_ROW_VP)
    .alignItems(VerticalAlign.Center)
    // 标题左右边距统一为「我的」页基准 base(16vp)，四页 Title 与屏幕左缘等距。
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
    // 五个 tab 顶部区域手势隔离（fix-tab-top-gesture-isolation，机制见 HomeTab.homeBrandRow 注释）：
    // 发布页顶部标题行横向拖动不触发 tab 切换，主体区滑动保留。
    .priorityGesture(
      PanGesture({ direction: PanDirection.Horizontal, fingers: 1, distance: 5 })
        .onActionStart((): void => {})
        .onActionUpdate((_e: GestureEvent): void => {})
        .onActionEnd((): void => {})
    )
  }

  // 干货意图卡的体裁 chip（原型屏 1：brandTint 底 + brand 字、14 圆角）。
  @Builder
  genreChip(label: string): void {
    Text(label)
      .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
      .fontColor(ColorTokens.brand)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.xs, bottom: SpaceTokens.xs })
      .backgroundColor(ColorTokens.brandTint)
      .borderRadius(RadiusTokens.md)
  }

  // 随记意图卡的标签 chip：形状对齐 genreChip，用 warm 同相色（warmSurfacePrimary 底 + warmAccent 字），
  // 与随记卡提示行同一色彩语言（不混用 brand 蓝系，避免在 warm 卡内跳色）。
  @Builder
  warmChip(label: string): void {
    Text(label)
      .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
      .fontColor(ColorTokens.warmAccent)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.xs, bottom: SpaceTokens.xs })
      .backgroundColor(ColorTokens.warmSurfacePrimary)
      .borderRadius(RadiusTokens.md)
  }

  // 第一屏意图卡：panel 面 + lg 圆角，撑满所在格（格由 layoutWeight 分配高度，卡面 100% 传导）。
  // 结构对齐原型：顶部一行 = 左上 tint 图标牌 + 右上 tertiary「›」；内容块（衬线标题 / 副题 /
  // 干货体裁 chips）贴底。撑满靠 SpaceBetween 首尾分布：高度传导生效时中间留白、贴底；
  // 传导异常退化为内容自然高时两段紧排，功能与层级不受损。
  // 意图卡点击：锁定内容区后弹系统三按钮弹窗选形式（原第二屏已删）。
  @Builder
  zoneCard(zone: FeedZone, title: string, subtitle: string, glyph: string, iconColor: ResourceColor, tintBg: ResourceColor): void {
    Pressable({
      fillWidth: true,
      fullResponseRegion: true,
      action: (): void => {
        this.zone = zone;
        this.showModeDialog(zone);
      },
    }) {
      Column({ space: SpaceTokens.base }) {
      Row() {
        Text(glyph)
          .fontSize(TypeTokens.title.size)
          .fontColor(iconColor)
          .width(GLYPH_SIZE)
          .height(GLYPH_SIZE)
          .textAlign(TextAlign.Center)
          .backgroundColor(tintBg)
          .borderRadius(RadiusTokens.md)

        Blank()

        Text('›')
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 弹性空白：内容组整体贴卡底（顶行与内容组之间的留白由 Blank 承担，
      // 内容块→提示块的段间距固定为 base，不再靠 SpaceBetween 拉出不均留白）。
      Blank()
        .layoutWeight(1)

      Column({ space: SpaceTokens.sm }) {
        Text(title)
          .fontSize(TypeTokens.titleSerif.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.titleSerif.weight)
          .lineHeight(TypeTokens.titleSerif.lineHeight)
          .fontColor(ColorTokens.primary)

        Text(subtitle)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.secondary)
          .width('100%')

        if (zone === 'insight') {
          Row({ space: SpaceTokens.sm }) {
            this.genreChip('测评')
            this.genreChip('避坑')
            this.genreChip('教程')
            this.genreChip('辩论')
          }
          .width('100%')
        } else {
          Row({ space: SpaceTokens.sm }) {
            this.warmChip('分享')
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      // 底部轻提示行（紧凑单行）：干货=降级路径「可按原文发布」、随记=边界「不调 AI」；
      // ✦ 与文字垂直居中，不再有二级标题行（原「发布前 AI 会做什么」标题与副题重复，已删）。
      Row({ space: SpaceTokens.sm }) {
        if (zone === 'insight') {
          Text('✦')
            .fontSize(16)
            .fontColor(ColorTokens.brand)
        }

        Text(zone === 'insight' ? '不想整理？可按原文发布' : '不做结构化整理，不调用 AI')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .lineHeight(TypeTokens.caption.lineHeight)
          .fontColor(zone === 'insight' ? ColorTokens.brand : ColorTokens.warmAccent)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
      .backgroundColor(zone === 'insight' ? ColorTokens.brandTint : ColorTokens.warmSurfacePrimary)
      .borderRadius(RadiusTokens.md)
      }
      .width('100%')
      .height('100%')
      .padding(SpaceTokens.lg)
      .backgroundColor(ColorTokens.panel)
      .borderRadius(RadiusTokens.lg)
    }
  }

  // 第一屏：引导句 + 两张意图卡纵向等分撑满（原型 intent-stack flex:1 / gap 16）。
  @Builder
  zoneStage(): void {
    Column({ space: SpaceTokens.base }) {
      Text('你想让大家看到什么？')
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.callout.weight)
        .lineHeight(TypeTokens.callout.lineHeight)
        .fontColor(ColorTokens.secondary)
        .width('100%')

      Column() {
        this.zoneCard('insight', '发干货',
          'AI 把正文整理成信息块，逐块确认后发出。',
          '◈', ColorTokens.brand, ColorTokens.brandTint)
      }
      .width('100%')
      .layoutWeight(1)

      Column() {
        this.zoneCard('life', '发随记',
          '轻量记录，写完直接发。',
          '○', ColorTokens.warmAccent, ColorTokens.warmSurfacePrimary)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, top: SpaceTokens.sm, bottom: SpaceTokens.base })
  }


  build() {
    Column() {
      this.headerRow()

      this.zoneStage()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      top: this.statusBarHeight,
      // 让开整条悬浮 Dock：栏高 + 栏底间距 + 系统导航区，再留一档呼吸。
      bottom: DOCK_BAR_HEIGHT_VP + DOCK_BOTTOM_MARGIN_BASE + bottomNavInset() + SpaceTokens.xl,
    })
    .backgroundColor(ColorTokens.canvas)
  }
}