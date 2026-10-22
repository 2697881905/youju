import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem,
  TabSegmentButtonConstructionOptions, uiMaterial } from '@kit.ArkUI';
import { getSegmentImmersiveMaterial } from '../../utils/immersiveMaterial';
import { SegmentedItem } from './SegmentedControl';

/**
 * 官方分段栏（SegmentButton · tab 档）+ 沉浸光感系统材质。
 *
 * 表面全部交回官方：选中面、文字颜色/字号/字重、圆角、内缩、投影一律不传，
 * 走官方默认（V1 tab 档这些字段的 Default value 均为 "auto"，选中面取
 * `sys.color.segment_button_checked_foreground_color`，圆角/内缩取 `sys.float.*` 系统值）。
 * 本文件不再自绘任何表面层。
 *
 * 参考实测（智慧生活 场景页「我的 | 探索」，2026-10-20/21 真机两档）：
 *   浅色 轨道 L246 / 滑块 L255（页面底 L243）；深色 轨道 L79.6 / 选中面 L84.5（页面底 L69.6）
 *   —— 选中面只比轨道亮 5~9 L，整条栏是「比底板略亮的一层磨砂」。基准文档 §7.7 / §7.6.18。
 *
 * 官方能力边界（不要再绕）：`selectedIndexes` 只接受整数数组，**没有连续/浮点索引入口**，
 * 因此滑块不跟随手指逐帧位移。宿主的职责是把 Swiper 的 `onChange` 落到 `selectedIndex`，
 * 分段切换由官方状态动画完成。
 */
@Component
export struct ImmersiveSegmentBar {
  @Prop items: SegmentedItem[] = [];
  @Link @Watch('syncIndexes') selectedIndex: number;
  // 每槽位宽度（vp）：>0 时整栏按 items.length × 该值定宽（标题栏里与 chip/按钮并排的场景），
  // 0 = 撑满父容器。官方组件把可用宽度等分给各 item，包裹层负责给多少可用宽度。
  @Prop itemWidth: number = 0;
  // 官方组件按内容自适应高度（默认实测 99px=31.7vp），参考栏高 40vp → 上下各补 9.5vp。
  // 这是官方 `buttonPadding` 字段，不是自绘尺寸。
  @Prop buttonVerticalPadding: number = 9.5;
  // 横向内边距：定宽栏（itemWidth）下 8vp 会把长标签（4 字 ≈ 64vp）挤到官方 item 截断，宿主按槽位预算调小。
  @Prop buttonHorizontalPadding: number = 8;
  // 浅色内容态：首页顶栏模糊背板转深时，标签随品牌行一起切白（官方 fontColor / selectedFontColor 字段）。
  @Prop @Watch('rebuildOptions') lightContent: boolean = false;
  // 是否把轨道材质覆盖成 ULTRA_THIN。**必须与 lightContent 同值**：
  //   ULTRA_THIN 薄到几乎只透背板 → 轨道随身后内容转深，此时白标签（lightContent）才有对比；
  //   官方默认材质会把轨道提亮成近白，配白标签就是白字压白底（真机实测首页滑到位那一帧）。
  // false = 不传 backgroundSystemMaterial，落回应用级 ohos.arkui.UIMaterial.state=enable
  //         给 SegmentButton 的官方默认材质，与参考 App 同一档。
  @Prop @Watch('rebuildOptions') overrideTrackMaterial: boolean = false;
  onSelect?: (index: number) => void = undefined;
  // options 是官方组件的 @ObjectLink：只在 aboutToAppear 与影响样式的入参变化时重建，
  // 逐帧重建会打断组件内部状态。
  @State private barOptions: SegmentButtonOptions | undefined = undefined;
  @State private indexes: number[] = [0];

  aboutToAppear(): void {
    this.indexes = [this.selectedIndex];
    this.barOptions = this.buildOptions();
  }

  // 宿主侧改选中值（滑动落页、外部跳转）时回灌官方组件的选中索引。
  private syncIndexes(): void {
    this.indexes = [this.selectedIndex];
  }

  private rebuildOptions(): void {
    this.barOptions = this.buildOptions();
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
      // 选中面底色 / 圆角 / 投影一律不传：官方默认（"auto"）即参考实现的那套系统材质语义。
    };
    if (this.lightContent) {
      opts.fontColor = '#99FFFFFF';
      opts.selectedFontColor = Color.White;
    }
    if (this.overrideTrackMaterial) {
      const material: uiMaterial.Material | undefined = getSegmentImmersiveMaterial();
      if (material !== undefined) {
        opts.backgroundSystemMaterial = material;
      }
    }
    return SegmentButtonOptions.tab(opts);
  }

  private barWidth(): Length {
    return this.itemWidth > 0 ? this.itemWidth * Math.max(1, this.items.length) : '100%';
  }

  build() {
    Row() {
      if (this.barOptions !== undefined) {
        SegmentButton({
          options: this.barOptions,
          selectedIndexes: $indexes,
          onItemClicked: (index: number): void => {
            if (this.selectedIndex !== index) {
              this.selectedIndex = index;
            }
            if (this.onSelect !== undefined) {
              this.onSelect(index);
            }
          },
        })
      }
    }
    .width(this.barWidth())
  }
}
