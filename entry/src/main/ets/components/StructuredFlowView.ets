import { StructuredBlock, StructuredDocument, StructuredEvidence } from '../models/types';
import { evidenceOf, structuredBlockHasContent, structuredBlockTypeLabel } from '../utils/structuredDocument';
import { resolveDisplayImageUrl } from '../services/api';
import { GlassBlurStyle, getSheetImmersiveMaterial, isSystemMaterialActive } from '../utils/immersiveMaterial';
import { Pressable } from '../design/motion/Pressable';
import { stepCheckStore } from '../utils/stepCheckStore';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 详情页的完整结构化信息流。每种数据关系使用不同版式，而不是退化成统一字段表。
@Component
export struct StructuredFlowView {
  @Prop @Watch('onCheckInScopeChanged') document: StructuredDocument | null = null;
  // 教程步骤打卡：>0 才开放勾选。预览页没有帖子 id，进度无处落盘，就不该给出一个会骗人的复选框。
  @Prop @Watch('onCheckInScopeChanged') checkInPostId: number = 0;
  // 证据清单弹层：整份信息流共用一个 bindSheet，而不是每个块各绑一个——
  // 多个块同时挂同一个 isShow 会一起弹出来。
  @State evidenceBlockId: string = '';
  @State evidenceVisible: boolean = false;
  // 打卡状态从 store 投影成一份「blockId#index,...」快照：
  // @Builder 的参数是值快照，直读这个 @State 才能让勾选立刻反映到行上。
  @State private checkedKeys: string = '';
  private unsubscribeChecks: () => void = (): void => {};

  aboutToAppear(): void {
    this.refreshChecked();
    this.unsubscribeChecks = stepCheckStore.subscribe((_postId: number): void => {
      this.refreshChecked();
    });
  }

  aboutToDisappear(): void {
    this.unsubscribeChecks();
    this.unsubscribeChecks = (): void => {};
  }

  // 帖子 id 与信息流都是异步到达的 @Prop：换帖、详情回填都要重新拉一次进度，
  // 否则首帧拿到 checkInPostId=0 之后，勾选状态就永远停在空。
  private onCheckInScopeChanged(): void {
    this.refreshChecked();
  }

  private refreshChecked(): void {
    if (this.checkInPostId <= 0 || this.document === null) {
      this.checkedKeys = '';
      return;
    }
    const keys: string[] = [];
    for (const block of this.document.blocks) {
      for (let i = 0; i < block.items.length; i++) {
        if (stepCheckStore.isChecked(this.checkInPostId, block.id, i)) {
          keys.push(block.id + '#' + String(i));
        }
      }
    }
    this.checkedKeys = keys.join(',');
  }

  private isStepChecked(blockId: string, index: number): boolean {
    return (',' + this.checkedKeys + ',').indexOf(',' + blockId + '#' + String(index) + ',') >= 0;
  }

  private doneSteps(block: StructuredBlock): number {
    let done: number = 0;
    for (let i = 0; i < block.items.length; i++) {
      if (this.isStepChecked(block.id, i)) {
        done += 1;
      }
    }
    return done;
  }

  private canCheckIn(block: StructuredBlock): boolean {
    return this.checkInPostId > 0 && block.items.length > 0;
  }

  private accentColor(): ResourceColor {
    if (this.document?.theme === 'warm') return '#A85D24';
    if (this.document?.theme === 'cool') return '#2D746E';
    // brandPress（浅 #0055BB / 深 #3D9BFF）：本函数的返回值既做图形（进度条、勾选、序号球）
    // 也做 11–14px 标签文字，而文字会落在 brandTint 主视觉卡或 subtle 药丸底上；
    // brand 字压 tint 深色只有 3.58:1（不达 AA），brandPress 最差 4.56:1，蓝调不变。
    return ColorTokens.brandPress;
  }

  private surfaceColor(primary: boolean): ResourceColor {
    if (this.document?.theme === 'warm') return primary ? '#FFF1E2' : '#FFF8F1';
    if (this.document?.theme === 'cool') return primary ? '#E8F5F2' : '#F4F9F8';
    return primary ? ColorTokens.brandTint : ColorTokens.subtle;
  }

  private visibleBlocks(): StructuredBlock[] {
    if (this.document === null || this.document.schemaVersion < 2) return [];
    const primary: StructuredBlock[] = [];
    const rest: StructuredBlock[] = [];
    for (const block of this.document.blocks) {
      if (!structuredBlockHasContent(block)) continue;
      if (block.id === this.document.primaryBlockId) primary.push(block);
      else rest.push(block);
    }
    return primary.concat(rest);
  }

  private blockById(id: string): StructuredBlock | null {
    if (this.document === null) return null;
    for (const block of this.document.blocks) {
      if (block.id === id) return block;
    }
    return null;
  }

  private sheetEvidence(): StructuredEvidence[] {
    const block: StructuredBlock | null = this.blockById(this.evidenceBlockId);
    return block === null ? [] : evidenceOf(block);
  }

  private sheetTitle(): string {
    const block: StructuredBlock | null = this.blockById(this.evidenceBlockId);
    if (block === null) return '证据清单';
    return block.title.length > 0 ? block.title : structuredBlockTypeLabel(block.type);
  }

  @Builder
  private evidenceCell(item: StructuredEvidence): void {
    Column({ space: SpaceTokens.sm }) {
      if (item.type === 'image') {
        Image(resolveDisplayImageUrl(item.ref))
          .width('100%')
          .height(200)
          .objectFit(ImageFit.Cover)
          .borderRadius(RadiusTokens.md)
        if (item.note.length > 0) {
          Text(item.note)
            .fontSize(TypeTokens.callout.size)
            .fontFamily(TypeTokens.fontFamily)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.primary)
            .width('100%')
        }
      } else {
        Row({ space: SpaceTokens.sm }) {
          Text('出处')
            .fontSize(TypeTokens.overline.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontWeight(600)
            .fontColor(this.accentColor())
            .backgroundColor(ColorTokens.elevated)
            .borderRadius(RadiusTokens.pill)
            .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 5, bottom: 5 })
          Text(item.ref)
            .fontSize(TypeTokens.callout.size)
            .fontFamily(TypeTokens.fontFamily)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.primary)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        // 出处也可以带说明（协议里 note ≤60，编辑器允许填）：不渲染就等于把用户写的话丢掉
        if (item.note.length > 0) {
          Text(item.note)
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .lineHeight(TypeTokens.caption.lineHeight)
            .fontColor(ColorTokens.secondary)
            .width('100%')
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private evidenceSheet(): void {
    Column({ space: SpaceTokens.base }) {
      Row({ space: SpaceTokens.sm }) {
        Column({ space: SpaceTokens.inlineTight }) {
          Text('证据清单')
            .fontSize(TypeTokens.headline.size)
            .fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.primary)
          Text(this.sheetTitle() + ' · ' + String(this.sheetEvidence().length) + ' 条')
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Pressable({
          visualHeight: 32,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => { this.evidenceVisible = false; },
        }) {
          Text('关闭')
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brand)
            .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 6, bottom: 6 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      List({ space: SpaceTokens.base }) {
        ForEach(this.sheetEvidence(), (item: StructuredEvidence, _index: number) => {
          ListItem() {
            this.evidenceCell(item)
          }
        }, (item: StructuredEvidence, index: number) => 'ev_' + String(index) + '_' + item.type)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%')
    .height('100%')
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.sm })
    // 材质由 SheetOptions.systemMaterial 承载，内容侧保持透明，避免自绘底色压掉磨砂
    .backgroundColor(isSystemMaterialActive() ? Color.Transparent : ColorTokens.canvas)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private blockHeading(block: StructuredBlock, primary: boolean): void {
    Row({ space: SpaceTokens.sm }) {
      Text(primary ? '主视觉' : structuredBlockTypeLabel(block.type))
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.overline.weight)
        .letterSpacing(1)
        .fontColor(this.accentColor())
      Text(block.title)
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (evidenceOf(block).length > 0) {
        Pressable({
          visualHeight: 26,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => {
            this.evidenceBlockId = block.id;
            this.evidenceVisible = true;
          },
        }) {
          Text('有依据 ' + String(evidenceOf(block).length))
            .fontSize(TypeTokens.overline.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontWeight(600)
            .fontColor(this.accentColor())
            .backgroundColor(this.surfaceColor(false))
            .borderRadius(RadiusTokens.pill)
            .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: 5, bottom: 5 })
        }
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private metricBody(block: StructuredBlock, primary: boolean): void {
    Row({ space: SpaceTokens.sm }) {
      Text(block.value)
        .fontSize(primary ? 38 : 28)
        .fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(700)
        .fontColor(ColorTokens.primary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (block.unit.length > 0) {
        Text(block.unit)
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .padding({ bottom: SpaceTokens.xs })
      }
      Blank().layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  private insightBody(block: StructuredBlock, primary: boolean): void {
    Text(block.value)
      .fontSize(primary ? TypeTokens.headline.size : TypeTokens.body.size)
      .fontFamily(TypeTokens.fontFamilySerifBody)
      .fontWeight(primary ? 600 : 500)
      .lineHeight(primary ? 30 : 26)
      .fontColor(ColorTokens.primary)
      .width('100%')
  }

  @Builder
  private listBody(block: StructuredBlock): void {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(block.items, (item: string) => {
        Text(item)
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.primary)
          .backgroundColor(ColorTokens.elevated)
          .borderRadius(RadiusTokens.pill)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: 7, bottom: 7 })
          .margin({ right: SpaceTokens.sm, bottom: SpaceTokens.sm })
      }, (item: string) => item)
    }
    .width('100%')
  }

  @Builder
  private stepsProgress(block: StructuredBlock): void {
    Row({ space: SpaceTokens.md }) {
      Progress({ value: this.doneSteps(block), total: block.items.length, type: ProgressType.Linear })
        .layoutWeight(1)
        .color(this.accentColor())
        .backgroundColor(ColorTokens.separator)
        .style({ strokeWidth: SpaceTokens.xs, strokeRadius: RadiusTokens.xs, enableSmoothEffect: true })
      Text('已完成 ' + String(this.doneSteps(block)) + '/' + String(block.items.length))
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontColor(this.doneSteps(block) === block.items.length ? this.accentColor() : ColorTokens.tertiary)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private stepsBody(block: StructuredBlock): void {
    Column({ space: SpaceTokens.md }) {
      if (this.canCheckIn(block)) {
        this.stepsProgress(block)
      }
      ForEach(block.items, (item: string, index: number) => {
        Row({ space: SpaceTokens.md }) {
          if (this.canCheckIn(block)) {
            Checkbox()
              .select(this.isStepChecked(block.id, index))
              .selectedColor(this.accentColor())
              .width(22)
              .height(22)
              .onChange((value: boolean): void => {
                stepCheckStore.setChecked(this.checkInPostId, block.id, index, value);
              })
          } else {
            Text(String(index + 1))
              .width(24)
              .height(24)
              .fontSize(TypeTokens.caption.size)
              .fontFamily(TypeTokens.fontFamily)
              .fontWeight(600)
              .fontColor(this.accentColor())
              .backgroundColor(ColorTokens.elevated)
              .borderRadius(RadiusTokens.pill)
              .textAlign(TextAlign.Center)
          }
          Text(item)
            .fontSize(TypeTokens.callout.size)
            .fontFamily(TypeTokens.fontFamily)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(this.isStepChecked(block.id, index) ? ColorTokens.tertiary : ColorTokens.primary)
            .decoration({
              type: this.isStepChecked(block.id, index) ? TextDecorationType.LineThrough : TextDecorationType.None,
              color: ColorTokens.tertiary,
            })
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }, (item: string, index: number) => block.id + '#' + String(index) + ':' + item
        + (this.isStepChecked(block.id, index) ? '_on' : ''))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private compareSide(label: string, value: string): void {
    Column({ space: SpaceTokens.sm }) {
      Text(label)
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(600)
        .fontColor(this.accentColor())
      Text(value)
        .fontSize(TypeTokens.body.size)
        .fontFamily(TypeTokens.fontFamilySerifBody)
        .fontWeight(500)
        .lineHeight(TypeTokens.body.lineHeight)
        .fontColor(ColorTokens.primary)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private compareBody(block: StructuredBlock): void {
    Row({ space: SpaceTokens.md }) {
      this.compareSide(block.leftLabel.length > 0 ? block.leftLabel : 'A', block.leftValue)
      Divider().vertical(true).height(64).color(ColorTokens.separator)
      this.compareSide(block.rightLabel.length > 0 ? block.rightLabel : 'B', block.rightValue)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private blockCard(block: StructuredBlock, primary: boolean): void {
    Column({ space: primary ? SpaceTokens.base : SpaceTokens.md }) {
      this.blockHeading(block, primary)
      if (block.type === 'metric') {
        this.metricBody(block, primary)
      } else if (block.type === 'insight') {
        this.insightBody(block, primary)
      } else if (block.type === 'list') {
        this.listBody(block)
      } else if (block.type === 'steps') {
        this.stepsBody(block)
      } else {
        this.compareBody(block)
      }
      if (block.helper.length > 0) {
        Text(block.helper)
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .width('100%')
      }
    }
    .width('100%')
    .padding(primary ? SpaceTokens.lg : SpaceTokens.base)
    .backgroundColor(this.surfaceColor(primary))
    .borderRadius(primary ? RadiusTokens.lg : RadiusTokens.md)
    .border({ width: primary ? 0 : LayoutTokens.hairlineWidth, color: ColorTokens.separator, style: BorderStyle.Solid })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    if (this.visibleBlocks().length > 0) {
      Column({ space: SpaceTokens.md }) {
        ForEach(this.visibleBlocks(), (block: StructuredBlock, index: number) => {
          this.blockCard(block, index === 0 && block.id === this.document?.primaryBlockId)
        }, (block: StructuredBlock) => block.id)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .bindSheet($$this.evidenceVisible, this.evidenceSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
        // 材质载体是 SheetOptions.systemMaterial（半模态的唯一生效入口）
        systemMaterial: getSheetImmersiveMaterial(),
        blurStyle: isSystemMaterialActive() ? BlurStyle.NONE : GlassBlurStyle.Floating,
        backgroundColor: isSystemMaterialActive() ? undefined : ColorTokens.canvas,
        showClose: false,
        maskColor: '#33000000',
        onDisappear: (): void => { this.evidenceVisible = false; },
      })
    }
  }
}
