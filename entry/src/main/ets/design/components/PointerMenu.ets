// PointerMenu —— 长按跟手浮层菜单（行式菜单唯一样式源）
//
// 按压点定位跟手浮层菜单：全屏透明遮罩（点击关闭）+ 按压点钳制定位 + 轻量进场动效 +
// 行式菜单项（148vp 卡片宽 / elevated 底 / md 圆角 / clip / barShadow(offsetY 6) /
// hairline 分隔 / 42vp 行高 / headline 字重）。
// 语义边界：仅收敛「长按按压点跟手浮层菜单」（聊天消息长按菜单、正文长按复制菜单）；
// 标题栏右上角 openMenu 系统 Menu（官方配方）不参与收敛。
// 定位语义 placement：
// - center：卡片中心对准按压点（聊天消息长按菜单）
// - above：卡片底边距按压点 10vp 显示在上方（不遮住被长按的文字），贴近宿主区顶部
//   放不下时翻转到按压点下方（正文长按菜单）；均钳制在宿主区边界内（8vp 边距）。
// 交互约定：点遮罩关闭；菜单项点击先 onClose 关菜单再执行 action。
// 调用方式：调用方以 if 控制挂载（一次显示一次创建），构造参数传按压点全局坐标与宿主区
// 全局原点/尺寸；entries 含函数属性，须构造时传值（不做 @Prop 深拷贝）。
import { ColorTokens } from '../tokens/color';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens, SpaceTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';
import { MotionCurves } from '../tokens/motion';

// 菜单项：文案 + 动作
export interface PointerMenuEntry {
  label: string;
  action: () => void;
}

// 定位语义：center=卡片中心对准按压点；above=卡片在按压点上方（顶部放不下翻转到下方）
export type PointerMenuPlacement = 'center' | 'above';

// 视觉规格（与收敛前两页实现逐字一致）：卡片宽 / 行高 / 钳制边距 / above 模式距按压点间隙
const CARD_W: number = 148;
const ROW_H: number = 42;
const EDGE: number = 8;
const ABOVE_GAP: number = 10;

@Component
export struct PointerMenu {
  // 菜单项（含函数属性：构造时传值；调用方以 if 控制挂载保证每次显示都是新实例）
  entries: PointerMenuEntry[] = [];
  // 按压点全局坐标（调用方从 GestureEvent.fingerList 提取，兜底宿主区中心）
  pressX: number = 0;
  pressY: number = 0;
  // 宿主区域全局原点与尺寸（全局→本地换算与边界钳制基准）
  areaX: number = 0;
  areaY: number = 0;
  areaWidth: number = 0;
  areaHeight: number = 0;
  @Prop placement: PointerMenuPlacement = 'center';
  // 遮罩 zIndex：默认 0（默认层级）；需盖过页内底栏时由调用方抬高（正文长按菜单传 2）
  @Prop overlayZ: number = 0;
  // 关闭回调（遮罩点击与菜单项点击共用；菜单项先关菜单再执行 action）
  onClose: () => void = (): void => {};

  // 钳制后的卡片左上角（宿主区本地坐标），aboutToAppear 一次性算好
  @State posX: number = 0;
  @State posY: number = 0;

  // 按可见项数估算卡片高度（行高 42 + hairline 分隔线 + 上下 xs 内边距）
  private cardHeight(): number {
    const rows: number = Math.max(1, this.entries.length);
    return rows * ROW_H + (rows - 1) * LayoutTokens.hairlineWidth + 8;
  }

  aboutToAppear(): void {
    // 全局按压点 → 宿主区本地坐标
    const lx: number = this.pressX - this.areaX;
    const ly: number = this.pressY - this.areaY;
    const cardH: number = this.cardHeight();
    const maxX: number = Math.max(EDGE, this.areaWidth - CARD_W - EDGE);
    const maxY: number = Math.max(EDGE, this.areaHeight - cardH - EDGE);
    // 水平中心对准按压点（两种模式一致）
    this.posX = Math.max(EDGE, Math.min(maxX, lx - CARD_W / 2));
    if (this.placement === 'above') {
      // 卡片显示在按压点上方（底边距按压点 gap，不遮住被长按的文字）；
      // 上方放不下（长按位置贴近宿主区顶部）时翻转到按压点下方
      let y: number = ly - cardH - ABOVE_GAP;
      if (y < EDGE) {
        y = ly + ABOVE_GAP;
      }
      this.posY = Math.max(EDGE, Math.min(maxY, y));
    } else {
      // 卡片中心对准按压点
      this.posY = Math.max(EDGE, Math.min(maxY, ly - cardH / 2));
    }
  }

  @Builder
  menuRow(entry: PointerMenuEntry) {
    Text(entry.label)
      .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.headline.weight)
      .fontColor(ColorTokens.primary)
      .width('100%')
      .height(ROW_H)
      .textAlign(TextAlign.Center)
      .onClick(() => {
        // 先关菜单再执行动作（两页既有语义）
        this.onClose();
        entry.action();
      })
  }

  @Builder
  divider() {
    Divider()
      .color(ColorTokens.separator)
      .strokeWidth(LayoutTokens.hairlineWidth)
  }

  build() {
    Column() {
      Column() {
        ForEach(this.entries, (entry: PointerMenuEntry, idx: number) => {
          if (idx > 0) {
            this.divider()
          }
          this.menuRow(entry)
        }, (_entry: PointerMenuEntry, idx: number): string => idx.toString())
      }
      .width(CARD_W)
      .padding({ top: SpaceTokens.xs, bottom: SpaceTokens.xs })
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.md)
      .clip(true)
      .shadow({ radius: 20, color: ColorTokens.barShadow, offsetY: 6 })
      // 按压点定位（aboutToAppear 已完成全局→本地换算与边界钳制，不溢出宿主区）
      .position({ x: this.posX, y: this.posY })
      // 进/出场：淡入 + 轻微缩放（0.94→1），只动 transform/opacity 保证性能
      .transition(
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
          .animation({ duration: 180, curve: MotionCurves.standard })
      )
    }
    .width('100%')
    .height('100%')
    // 透明遮罩：视觉上无灰色覆盖，但仍捕获点击以关闭菜单
    .backgroundColor(Color.Transparent)
    .zIndex(this.overlayZ)
    .onClick((): void => {
      this.onClose();
    })
  }
}