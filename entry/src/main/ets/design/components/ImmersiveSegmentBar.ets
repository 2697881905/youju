import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem,
  TabSegmentButtonConstructionOptions, uiMaterial } from '@kit.ArkUI';
import { getSegmentImmersiveMaterial } from '../../utils/immersiveMaterial';
import { SharedSlide } from '../motion/SharedSlide';
import { ColorTokens } from '../tokens/color';
import { MotionCurves, MotionTokens } from '../tokens/motion';
import { RadiusTokens } from '../tokens/radius';
import { LayoutTokens } from '../tokens/space';
import { TypeTokens } from '../tokens/type';
import { SegmentedItem } from './SegmentedControl';

// 官方 tab 分段栏的选中面：真机实测纯白（轨道 252 / 画布 255），故直接用 Color.White 而非 barSelectionSurface。
const SLIDE_FILL: ResourceColor = Color.White;
// 选中面悬浮投影：真机实测官方药丸在轨道内的接触投影很浅（轨道 252→药丸边缘 246，Δ6），
// 用 cardAmbient 一档（radius 10 / 8% 黑 / offsetY 3）贴合，重了会在轨道里压出一圈灰边。
const SLIDE_SHADOW: ShadowOptions = { radius: 10, color: '#14000000', offsetY: 3 };

/**
 * 官方分段栏（沉浸光感）+ 1:1 跟手滑块。
 *
 * 分工：
 * - 表面（轨道 / 材质 / 投影 / 命中）全部交给官方 SegmentButton + backgroundSystemMaterial，
 *   自绘轨道永远追不上系统材质对背景的实时采样（白底上材质上限 252，自绘只能给常数）。
 * - 官方组件的 selectedIndexes 只吃整数，滑块无法跟手 → 把它的选中面与文字透明化
 *   （真机验证：轨道材质与投影完整保留），选中面由 SharedSlide 按连续索引逐帧位移。
 *
 * 宿主联动：把 Swiper 的连续位置（浮点索引）喂给 slidePosition，-1 表示不在滚动，
 * 此时滑块回退整数 selectedIndex 并走弹性动画（点击切换）。slidePosition 必须是标量 @Prop，
 * 数组/对象参数在 keyed ForEach 里不会刷新（见 memory: arkui-array-prop-in-foreach-stale）。
 * 喂入口径（真机逐帧取证 566 个采样）：连续索引 = onContentDidScroll 的 index - position，
 * 视口内每一页都按同一基准回报、算出的值一致，且整段（含松手后的吸附动画）连续单调。
 * 因此全程喂入、不设「手指按下」闸门（设了会在收尾处留下 0.2 页的断档），
 * 只在 onAnimationEnd 写一次整数位抹掉浮点残差。
 * 点击/程序化换页是另一条路：真机取证这类切换一条滚动回调都不发，
 * 宿主必须在 Swiper.onChange（非动画在途时）直接把整数位写进去，否则滑块停在旧槽。
 */
@Component
export struct ImmersiveSegmentBar {
  @Prop items: SegmentedItem[] = [];
  @Link @Watch('syncIndexes') selectedIndex: number;
  // 连续（浮点）索引：滚动中逐帧喂入，1:1 跟手；-1 = 空闲
  @Prop slidePosition: number = -1;
  // 每槽位宽度（vp）：>0 时整栏按 items.length × 该值定宽（标题栏里与 chip/按钮并排的场景），
  // 0 = 撑满父容器。官方组件自身不支持通用属性，宽度落在包裹层上、由它等分给各 item。
  @Prop itemWidth: number = 0;
  // 按钮内边距：官方组件按内容自适应高度（默认档实测 99px=31.7vp），
  // 参考App 设备详情页顶栏实测 123px=39.4vp → 上下各补 9.5vp 把轨道撑到 segmentBarHeight。
  @Prop buttonVerticalPadding: number = 9.5;
  // 按钮横向内边距：定宽栏（itemWidth）下 8vp 会把长标签（4 字 ≈ 64vp）挤到官方 item 截断，
  // 宿主按槽位预算调小。
  @Prop buttonHorizontalPadding: number = 8;
  // 浅色内容态（顶栏模糊背板变深时切白，同 SegmentedControl.lightContent 口径）
  @Prop lightContent: boolean = false;
  onSelect?: (index: number) => void = undefined;
  // options 是 @ObjectLink，只能在 aboutToAppear（items 就位后）构造一次：
  // 逐帧重建会打断官方组件的内部状态。
  @State private barOptions: SegmentButtonOptions | undefined = undefined;
  @State private indexes: number[] = [0];
  // 轨道实测高度：官方组件自适应，滑块几何必须贴实测值而非声明值（差 1.3vp 会顶出轨道）
  @State private trackHeight: number = LayoutTokens.segmentBarHeight;

  aboutToAppear(): void {
    this.indexes = [this.selectedIndex];
    this.barOptions = this.buildOptions();
  }

  // 宿主侧改选中值（滑动落页、外部跳转）时回灌官方组件的选中索引：
  // 它的选中面虽然被透明化，但按压态与后续点击仍按这个索引走。
  private syncIndexes(): void {
    this.indexes = [this.selectedIndex];
  }

  private buildOptions(): SegmentButtonOptions {
    const buttons: SegmentButtonTextItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      buttons.push({ text: this.items[i].label });
    }
    const opts: TabSegmentButtonConstructionOptions = {
      buttons: buttons as ItemRestriction<SegmentButtonTextItem>,
      buttonPadding: {
        top: this.buttonVerticalPadding,
        right: this.buttonHorizontalPadding,
        bottom: this.buttonVerticalPadding,
        left: this.buttonHorizontalPadding,
      } as Padding,
      // 选中面与文字让位给自绘层：轨道材质/投影不受影响（真机验证）
      selectedBackgroundColor: Color.Transparent,
      fontColor: Color.Transparent,
      selectedFontColor: Color.Transparent,
    };
    const material: uiMaterial.Material | undefined = getSegmentImmersiveMaterial();
    if (material !== undefined) {
      opts.backgroundSystemMaterial = material;
    }
    return SegmentButtonOptions.tab(opts);
  }

  // 滚动中用连续索引，空闲时用整数选中值
  private progress(): number {
    const raw: number = this.slidePosition >= 0 ? this.slidePosition : this.selectedIndex;
    return Math.max(0, Math.min(Math.max(0, this.items.length - 1), raw));
  }

  private isActive(index: number): boolean {
    return Math.round(this.progress()) === index;
  }

  // 整栏宽度：定宽槽位模式下 = 槽位数 × 槽宽（官方组件把可用宽度等分给各 item，包裹层负责给多少可用宽度）
  private barWidth(): Length {
    return this.itemWidth > 0 ? this.itemWidth * Math.max(1, this.items.length) : '100%';
  }

  private slideFill(): ResourceColor {
    return this.lightContent ? '#33FFFFFF' : SLIDE_FILL;
  }

  private labelColor(index: number): ResourceColor {
    if (this.isActive(index)) {
      return this.lightContent ? Color.White : ColorTokens.primary;
    }
    return this.lightContent ? '#99FFFFFF' : ColorTokens.secondary;
  }

  private tap(index: number): void {
    if (this.selectedIndex !== index) {
      this.selectedIndex = index;
    }
    if (this.onSelect !== undefined) {
      this.onSelect(index);
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 官方组件不吃通用属性，量测挂在包裹它的 Row 上（材质在 options 里，包裹层不参与绘制）
      Row() {
        if (this.barOptions !== undefined) {
          SegmentButton({
            options: this.barOptions,
            selectedIndexes: $indexes,
            onItemClicked: (index: number): void => {
              this.tap(index);
            },
          })
        }
      }
      .width('100%')
      .onAreaChange((_old: Area, area: Area): void => {
        const h: number = parseFloat(String(area.height));
        if (h > 0 && Math.abs(h - this.trackHeight) > 0.5) {
          this.trackHeight = h;
        }
      })

      SharedSlide({
        selectedIndex: this.progress(),
        itemCount: this.items.length,
        controlHeight: this.trackHeight,
        inset: LayoutTokens.segmentSlideInset,
        radius: RadiusTokens.pill,
        fill: this.slideFill(),
        slideShadow: SLIDE_SHADOW,
      })

      Row() {
        ForEach(
          this.items,
          (item: SegmentedItem, index: number) => {
            Text(item.label)
              .layoutWeight(1)
              .fontSize(TypeTokens.callout.size)
              .fontFamily(TypeTokens.fontFamily)
              .fontWeight(this.isActive(index) ? FontWeight.Medium : TypeTokens.callout.weight)
              .lineHeight(TypeTokens.callout.lineHeight)
              .letterSpacing(TypeTokens.callout.tracking)
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(this.labelColor(index))
              .animation({
                duration: MotionTokens.fast,
                curve: MotionCurves.standard,
              })
          },
          (item: SegmentedItem): string => item.key
        )
      }
      .width('100%')
      .height(this.trackHeight)
      .alignItems(VerticalAlign.Center)
      // 标签层不参与命中：点击由下方官方组件的按钮承接。
      // 必须 BLOCK_DESCENDANTS(@since 20)：None 只豁免容器自身，后代 Text 仍参与命中并把点击挡在层外。
      .hitTestBehavior(HitTestMode.BLOCK_DESCENDANTS)
    }
    .width(this.barWidth())
  }
}
