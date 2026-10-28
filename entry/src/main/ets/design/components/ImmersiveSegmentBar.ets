import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem,
  TabSegmentButtonConstructionOptions, uiMaterial } from '@kit.ArkUI';
import { getSegmentImmersiveMaterial } from '../../utils/immersiveMaterial';

/**
 * 分段数据项。原定义在自绘 SegmentedControl 中，组件退役后收编至此——
 * 全 App 分段栏统一走官方 SegmentButton（本封装），ImmersiveSegmentBar 是唯一入口。
 */
export interface SegmentedItem {
  key: string;
  label: string;
}

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
  // 每槽位宽度（vp）：>0 = 显式定宽（标题栏里与 chip/按钮并排且推导不合身的场景）；
  // 0（默认）= 按内容自动推导：最长标签字数 × CHAR_W + 左右 buttonPadding，同字数同宽，
  // 全 App 分段栏布局由此统一（原 12 处手填 46/54/64/66/67/78/88 七档已全部删除）。
  // 官方组件把可用宽度等分给各 item，包裹层负责给多少可用宽度。
  @Prop itemWidth: number = 0;
  // true = 无视 itemWidth 直接铺满父容器（举报管理页两行表单式分段栏唯一使用）。
  @Prop fillWidth: boolean = false;
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
  // @Watch 必须挂着：官方页签组件**自带拖动选择**（慢拖松手即选释放点分段），它只回写
  // selectedIndexes（双向绑定落到这里的 indexes）、**不走 onItemClicked**——不监听的话
  // 选中面会动而宿主状态不动，表现为「滑动了分段栏但页面没切换」（真机实证 2026-10-24）。
  @State @Watch('onIndexesChanged') private indexes: number[] = [0];

  aboutToAppear(): void {
    this.indexes = [this.selectedIndex];
    this.barOptions = this.buildOptions();
  }

  // 宿主侧改选中值（滑动落页、外部跳转）时回灌官方组件的选中索引。
  private syncIndexes(): void {
    this.indexes = [this.selectedIndex];
  }

  // 官方组件拖动选择（以及点击）回写 indexes 后的唯一同步出口：回灌宿主 selectedIndex
  // 并触发 onSelect，与点击同一条数据通路。
  // ⚠️ 必须延迟到下一轮任务再写宿主：官方组件会在**自身更新期**回写 selectedIndexes
  //（双向绑定的回灌，日志里每次切换后的 no-op 回调即是），此时同步写 selectedIndex
  // 等于把状态修改嵌进渲染期——ArkUI 会丢掉这一轮重渲染，真机表现为「选中面切过去了、
  // 列表内容冻结在旧分段」（快速多次切换复现 2026-10-24）。timeout 闭包内重新校验，
  // 连续多次回写时只有与宿主最新值不同的那次会提交。
  private onIndexesChanged(): void {
    const idx: number = this.indexes[0] ?? -1;
    if (idx < 0 || idx === this.selectedIndex) {
      return;
    }
    setTimeout((): void => {
      if (idx < 0 || idx === this.selectedIndex) {
        return;
      }
      this.selectedIndex = idx;
      if (this.onSelect !== undefined) {
        this.onSelect(idx);
      }
    }, 0);
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

  // 槽宽推导的中文字宽系数（vp/字）：官方 tab 档默认字号 14fp，中文字符宽 ≈ 字号，
  // +0.5 字距余量防边缘截断。全 App 分段标签均为纯中文，无需按字符类别细分。
  private static readonly CHAR_W: number = 14.5;

  private barWidth(): Length {
    if (this.fillWidth) {
      return '100%';
    }
    if (this.itemWidth > 0) {
      return this.itemWidth * Math.max(1, this.items.length);
    }
    // 自动推导：最长标签字数 × 字宽 + 左右 buttonPadding（同字数标签 → 同槽宽）。
    let maxLen: number = 1;
    for (let i = 0; i < this.items.length; i++) {
      maxLen = Math.max(maxLen, this.items[i].label.length);
    }
    return Math.round(maxLen * ImmersiveSegmentBar.CHAR_W + this.buttonHorizontalPadding * 2)
      * Math.max(1, this.items.length);
  }

  build() {
    // Stack 是铺满语义的正确包装（真机对照实证 2026-10-28）：Stack 把自己的 content
    // area 作为子元素约束区传下去，SegmentButton「占据内容区内最大可用宽度」直接成立
    // ——消息页（Stack 包裹）铺满生效、举报中心（Column 直放、根 Row 拦截）不生效，
    // 唯一差异就是这层。fillWidth → Stack '100%'；定宽/推导 → Stack 拿确定宽度。
    // ⚠️ 官方组件不支持通用属性（SegmentButton.d.ets NOTE），.width() 链上去无效。
    Stack() {
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
