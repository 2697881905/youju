import { StructuredBlock, StructuredDocument, StructuredEvidence } from '../models/types';
import { evidenceOf, structuredBlockHasContent, structuredBlockTypeLabel } from '../utils/structuredDocument';
import { resolveDisplayImageUrl } from '../services/api';
import { GlassBlurStyle, getSheetImmersiveMaterial, isSystemMaterialActive } from '../utils/immersiveMaterial';
import { Pressable } from '../design/motion/Pressable';
import { stepCheckStore } from '../utils/stepCheckStore';
import { openSearch } from '../utils/nav';
import { formatCount } from '../utils/format';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 槽位规格：每个体裁按顺序声明「哪个槽位吃哪种类型的块」。
interface StructuredSlotSpec {
  role: string;
  type: string;
}

// 一个槽位的落位结果：role 决定版式，block 决定内容。
interface StructuredSlot {
  role: string;
  block: StructuredBlock;
}

// 详情页的完整结构化信息流——「可核验阅读」版式（2026-11-05 重设计）。
//
// 与旧版的差别：
// 1. 零卡片。旧版每块一张「底色+描边+圆角」的卡，块标题行三件套（类型字+默认标题+据胶囊）
//    语义重复；本版全区纯排版，块间 hairline 分隔，标题行合一。
// 2. 体裁动线。块按「类型+体裁」映射到槽位（判词先行 / 步骤即正文 / 对决合一），
//    骨架外的块（含存量 metric）回退 generic 行——信息一行不删，装饰全撤。
// 3. 论点可验。块挂了证据 → 论点带「据 N ↗」链接，点击开验货层（出处/截图/口径）。
//    这是产品标准（主张→证据→可证伪）在阅读侧的表达，不是装饰。
// 4. helper（编辑器补充说明）阅读侧不再渲染。
@Component
export struct StructuredFlowView {
  @Prop @Watch('onCheckInScopeChanged') document: StructuredDocument | null = null;
  // 教程步骤打卡：>0 才开放勾选。预览页没有帖子 id，进度无处落盘，就不该给出一个会骗人的复选框。
  @Prop @Watch('onCheckInScopeChanged') checkInPostId: number = 0;
  // 体裁驱动槽位表：预览页传 draft.genre，详情页传帖子体裁；缺省全部走 generic 行。
  @Prop genre: string = '';
  // —— 辩论对决槽的投票接线（可选）：票数快照与回调由 DetailPostContent 透传，
  // 请求与回滚仍归 DetailPage 持有。debateInteractive=false（发布预览）只渲染静态对照。
  @Prop planAVotes: number = 0;
  @Prop planBVotes: number = 0;
  @Prop myVote: string = '';
  @Prop debateInteractive: boolean = false;
  onVote: (choice: string) => void = (_choice: string): void => {};
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

  // warm/cool 两档必须走成对资源，不能写死浅色值（旧版整块底色卡已退役，
  // 主题只落在 accent 上：类型字、据链接、序号球、勾选）。
  private accentColor(): ResourceColor {
    if (this.document?.theme === 'warm') return ColorTokens.warmAccent;
    if (this.document?.theme === 'cool') return ColorTokens.coolAccent;
    // brandPress（浅 #0055BB / 深 #3D9BFF）：本函数的返回值既做图形（进度条、勾选、序号球）
    // 也做 11–14px 标签文字，而文字会落在页面画布上；brand 字压 tint 深色只有 3.58:1（不达 AA）。
    return ColorTokens.brandPress;
  }

  // 对照/对决的语义色：label 精确命中才上色，不做模糊匹配、不猜左右语义（规格 4.3）。
  private sideAccent(label: string): ResourceColor {
    if (label === '优点') return ColorTokens.success;
    if (label === '缺点') return ColorTokens.danger;
    return ColorTokens.brandPress;
  }

  // —— 槽位落位：每个槽位取第一个「类型匹配且有内容」的块，同类多块时 primary 优先；
  // 版式顺序由体裁定义（slotSpecs），不随 primaryBlockId 改变（规格 4.2）。
  private slots(): StructuredSlot[] {
    const out: StructuredSlot[] = [];
    if (this.document === null || this.document.schemaVersion < 2) {
      return out;
    }
    const content: StructuredBlock[] = [];
    for (const block of this.document.blocks) {
      if (structuredBlockHasContent(block)) {
        content.push(block);
      }
    }
    const usedIds: string[] = [];
    const primaryId: string = this.document.primaryBlockId;
    for (const spec of this.slotSpecs(this.genre)) {
      let pick: StructuredBlock | null = null;
      for (const block of content) {
        if (usedIds.indexOf(block.id) < 0 && block.type === spec.type && block.id === primaryId) {
          pick = block;
          break;
        }
      }
      if (pick === null) {
        for (const block of content) {
          if (usedIds.indexOf(block.id) < 0 && block.type === spec.type) {
            pick = block;
            break;
          }
        }
      }
      if (pick !== null) {
        usedIds.push(pick.id);
        out.push({ role: spec.role, block: pick });
      }
    }
    // 骨架外的块（含存量 metric、未知类型）一律兜底行：信息不删，只是不进版式。
    for (const block of content) {
      if (usedIds.indexOf(block.id) < 0) {
        out.push({ role: 'generic', block: block });
      }
    }
    return out;
  }

  private slotSpecs(genre: string): StructuredSlotSpec[] {
    if (genre === 'review') {
      return [
        { role: 'verdict', type: 'insight' },
        { role: 'compare', type: 'compare' },
        { role: 'list', type: 'list' },
      ];
    }
    if (genre === 'pitfall') {
      return [
        { role: 'verdict', type: 'insight' },
        { role: 'steps', type: 'steps' },
        { role: 'list', type: 'list' },
      ];
    }
    if (genre === 'tutorial') {
      return [
        { role: 'verdict', type: 'insight' },
        { role: 'list', type: 'list' },
        { role: 'steps', type: 'steps' },
      ];
    }
    if (genre === 'debate') {
      return [
        { role: 'duel', type: 'compare' },
        { role: 'verdict', type: 'insight' },
      ];
    }
    return [];
  }

  // 判词槽的类型字按体裁换词：同一个 insight 在避坑里读「教训」、教程里读「要点」。
  private verdictLabel(): string {
    if (this.genre === 'pitfall') return '教训';
    if (this.genre === 'tutorial') return '要点';
    if (this.genre === 'debate') return '立场';
    return '结论';
  }

  private blockById(id: string): StructuredBlock | null {
    if (this.document === null) return null;
    for (const block of this.document.blocks) {
      if (block.id === id) return block;
    }
    return null;
  }

  private openEvidence(blockId: string): void {
    this.evidenceBlockId = blockId;
    this.evidenceVisible = true;
  }

  private sheetEvidence(): StructuredEvidence[] {
    const block: StructuredBlock | null = this.blockById(this.evidenceBlockId);
    return block === null ? [] : evidenceOf(block);
  }

  // 验货层标题：块自定义 title 优先；对照/对决块为空时用「A/B 对照」（规格 5.2）。
  private sheetTitle(): string {
    const block: StructuredBlock | null = this.blockById(this.evidenceBlockId);
    if (block === null) return '论点';
    if (block.title.length > 0) return block.title;
    if (block.type === 'compare') return 'A/B 对照';
    return structuredBlockTypeLabel(block.type);
  }

  private voteWidth(votes: number): string {
    const total: number = this.planAVotes + this.planBVotes;
    return total > 0 ? (votes / total) * 100 + '%' : '0%';
  }

  // —— 可验标记：块挂了证据 → 「据 N ↗」。不使用虚线下划线（ArkUI TextDecorationType
  // 无虚线型，规格 5.2 已定案用角标）。
  @Builder
  private evidenceLink(block: StructuredBlock): void {
    Pressable({
      visualHeight: 26,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: (): void => { this.openEvidence(block.id); },
    }) {
      Text('据 ' + String(evidenceOf(block).length) + ' ↗')
        .fontSize(TypeTokens.caption.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(600)
        .fontColor(this.accentColor())
    }
  }

  @Builder
  private typeLabel(text: string): void {
    Text(text)
      .fontSize(TypeTokens.overline.size)
      .fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.overline.weight)
      .letterSpacing(2)
      .fontColor(this.accentColor())
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
          Text('验一验')
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

  // —— 判词槽：先结论后依据。overline 类型字 + 衬线判词 + 据链接，最多三行（规格 5.3）。
  @Builder
  private verdictSection(block: StructuredBlock): void {
    Column({ space: SpaceTokens.sm }) {
      this.typeLabel(this.verdictLabel())
      Text(block.value)
        .fontSize(TypeTokens.headline.size)
        .fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.headline.weight)
        .lineHeight(30)
        .fontColor(ColorTokens.primary)
        .width('100%')
      if (evidenceOf(block).length > 0) {
        this.evidenceLink(block)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: SpaceTokens.xs, bottom: SpaceTokens.md })
  }

  // —— 对照槽（测评优缺点）：双列 + 竖 hairline + 左侧 2px 语义色条。
  @Builder
  private compareSection(block: StructuredBlock): void {
    Column({ space: SpaceTokens.sm }) {
      Row({ space: SpaceTokens.md }) {
        this.compareColumn(block.leftLabel.length > 0 ? block.leftLabel : 'A', block.leftValue)
        Divider()
          .vertical(true)
          .height(64)
          .strokeWidth(0.5)
          .color(ColorTokens.separator)
        this.compareColumn(block.rightLabel.length > 0 ? block.rightLabel : 'B', block.rightValue)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      // 证据挂在块上（不假装条目级）：两侧共用一个入口，右对齐不与色条抢视线。
      if (evidenceOf(block).length > 0) {
        Row() {
          Blank().layoutWeight(1)
          this.evidenceLink(block)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.md })
  }

  @Builder
  private compareColumn(label: string, value: string): void {
    Column({ space: SpaceTokens.sm }) {
      Text(label)
        .fontSize(TypeTokens.overline.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(600)
        .fontColor(this.sideAccent(label))
      Text(value)
        .fontSize(TypeTokens.body.size)
        .fontFamily(TypeTokens.fontFamilySerifBody)
        .fontWeight(500)
        .lineHeight(TypeTokens.body.lineHeight)
        .fontColor(ColorTokens.primary)
        .width('100%')
        .padding({ left: SpaceTokens.md })
        // 左侧色条用色而不只用字，扫读时第一眼可分；文字标签仍在（WCAG 1.4.1）
        .border({ width: { left: 2 }, color: this.sideAccent(label), style: BorderStyle.Solid })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  // —— 对决槽（辩论）：A/B 大字对照 + 票数条与投票合一，方案文案只出现这一次。
  @Builder
  private duelSection(block: StructuredBlock): void {
    Column({ space: SpaceTokens.md }) {
      this.typeLabel('对决')
      Row({ space: SpaceTokens.md }) {
        this.duelSide(block.leftLabel.length > 0 ? block.leftLabel : '方案A', block.leftValue, 'A')
        Divider()
          .vertical(true)
          .height(88)
          .strokeWidth(0.5)
          .color(ColorTokens.separator)
        this.duelSide(block.rightLabel.length > 0 ? block.rightLabel : '方案B', block.rightValue, 'B')
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.md })
  }

  @Builder
  private duelSide(label: string, value: string, choice: string): void {
    Column({ space: SpaceTokens.sm }) {
      Text(label)
        .fontSize(TypeTokens.callout.size)
        .fontFamily(TypeTokens.fontFamily)
        .fontWeight(600)
        .fontColor(this.sideAccent(label))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text(value)
        .fontSize(TypeTokens.body.size)
        .fontFamily(TypeTokens.fontFamilySerifBody)
        .fontWeight(500)
        .lineHeight(TypeTokens.body.lineHeight)
        .fontColor(ColorTokens.primary)
        .width('100%')
      if (this.debateInteractive) {
        this.duelVoteRow(choice)
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private duelVoteRow(choice: string): void {
    Column({ space: SpaceTokens.xs }) {
      Row() {
        Column()
          .width(this.voteWidth(choice === 'A' ? this.planAVotes : this.planBVotes))
          .height(6)
          .borderRadius(3)
          .backgroundColor(ColorTokens.brand)
        Column()
          .layoutWeight(1)
          .height(6)
          .borderRadius(3)
          .backgroundColor(ColorTokens.sunken)
      }
      .width('100%')

      Row() {
        Text(formatCount(choice === 'A' ? this.planAVotes : this.planBVotes) + ' 票')
          .fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
        Blank()
        Row({ space: 2 }) {
          if (this.myVote === choice) {
            Image(resolveActionIcon('check'))
              .width(13)
              .height(13)
              .fillColor(ColorTokens.icon)
          }
          Text(this.myVote === choice ? '已投' : '投票')
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(this.myVote === choice ? ColorTokens.brand : ColorTokens.secondary)
        }
        .onClick((): void => { this.onVote(choice); })
      }
      .width('100%')
    }
    .width('100%')
  }

  // —— 清单槽：chips 可点 → 搜索该关键词（工具、适合人群天然是检索词，规格 B1）。
  @Builder
  private listSection(block: StructuredBlock): void {
    Column({ space: SpaceTokens.sm }) {
      Row({ space: SpaceTokens.sm }) {
        this.typeLabel('清单')
        Blank().layoutWeight(1)
        if (evidenceOf(block).length > 0) {
          this.evidenceLink(block)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      this.chipRow(block.items)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.md })
  }

  @Builder
  private chipRow(items: string[]): void {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(items, (item: string) => {
        Text(item)
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.brandPress)
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.pill)
          .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: 7, bottom: 7 })
          .margin({ right: SpaceTokens.sm, bottom: SpaceTokens.sm })
          .onClick((): void => { openSearch(item); })
      }, (item: string) => item)
    }
    .width('100%')
  }

  // —— 步骤槽：步骤即正文（教程主载体）。打卡与进度逻辑原样保留（stepCheckStore）。
  @Builder
  private stepsSection(block: StructuredBlock): void {
    Column({ space: SpaceTokens.md }) {
      Row({ space: SpaceTokens.sm }) {
        this.typeLabel('步骤')
        Blank().layoutWeight(1)
        if (evidenceOf(block).length > 0) {
          this.evidenceLink(block)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      if (this.canCheckIn(block)) {
        this.stepsProgress(block)
      }
      ForEach(block.items, (item: string, index: number) => {
        this.stepRow(block.id, item, index, this.canCheckIn(block))
      }, (item: string, index: number) => block.id + '#' + String(index) + ':' + item
        + (this.isStepChecked(block.id, index) ? '_on' : ''))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.md })
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

  // 行参数全部走标量（blockId/item/index/checkable）：@Builder 的块对象参数是值快照，
  // 勾选状态必须直读 @State 快照串才能即时刷新。
  @Builder
  private stepRow(blockId: string, item: string, index: number, checkable: boolean): void {
    Row({ space: SpaceTokens.md }) {
      if (checkable) {
        Checkbox()
          .select(this.isStepChecked(blockId, index))
          .selectedColor(this.accentColor())
          .width(22)
          .height(22)
          .onChange((value: boolean): void => {
            stepCheckStore.setChecked(this.checkInPostId, blockId, index, value);
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
        .fontColor(this.isStepChecked(blockId, index) ? ColorTokens.tertiary : ColorTokens.primary)
        .decoration({
          type: this.isStepChecked(blockId, index) ? TextDecorationType.LineThrough : TextDecorationType.None,
          color: ColorTokens.tertiary,
        })
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  // —— 兜底行：骨架外自由块与存量 metric 块。标题行合一（title 优先），
  // 正文按类型走最小渲染；metric 降级为普通行（不再大字头条，规格 5.1）。
  @Builder
  private genericSection(slot: StructuredSlot): void {
    Column({ space: SpaceTokens.sm }) {
      Row({ space: SpaceTokens.sm }) {
        Text(slot.block.title.length > 0 ? slot.block.title : structuredBlockTypeLabel(slot.block.type))
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(600)
          .fontColor(ColorTokens.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (evidenceOf(slot.block).length > 0) {
          this.evidenceLink(slot.block)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      this.genericBody(slot.block)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.md })
  }

  @Builder
  private genericBody(block: StructuredBlock): void {
    if (block.type === 'metric') {
      Row({ space: SpaceTokens.xs }) {
        Text(block.value)
          .fontSize(TypeTokens.callout.size)
          .fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(600)
          .fontColor(ColorTokens.primary)
        if (block.unit.length > 0) {
          Text(block.unit)
            .fontSize(TypeTokens.caption.size)
            .fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        Blank().layoutWeight(1)
      }
      .width('100%')
    } else if (block.type === 'insight') {
      Text(block.value)
        .fontSize(TypeTokens.body.size)
        .fontFamily(TypeTokens.fontFamilySerifBody)
        .fontWeight(500)
        .lineHeight(TypeTokens.body.lineHeight)
        .fontColor(ColorTokens.primary)
        .width('100%')
    } else if (block.type === 'list') {
      this.chipRow(block.items)
    } else if (block.type === 'steps') {
      Column({ space: SpaceTokens.sm }) {
        ForEach(block.items, (item: string, index: number) => {
          Text(String(index + 1) + '. ' + item)
            .fontSize(TypeTokens.callout.size)
            .fontFamily(TypeTokens.fontFamily)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.primary)
            .width('100%')
        }, (item: string, index: number) => String(index) + ':' + item)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else {
      Row({ space: SpaceTokens.md }) {
        this.compareColumn(block.leftLabel.length > 0 ? block.leftLabel : 'A', block.leftValue)
        Divider()
          .vertical(true)
          .height(64)
          .strokeWidth(0.5)
          .color(ColorTokens.separator)
        this.compareColumn(block.rightLabel.length > 0 ? block.rightLabel : 'B', block.rightValue)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  @Builder
  private slotSection(slot: StructuredSlot): void {
    if (slot.role === 'verdict') {
      this.verdictSection(slot.block)
    } else if (slot.role === 'compare') {
      this.compareSection(slot.block)
    } else if (slot.role === 'duel') {
      this.duelSection(slot.block)
    } else if (slot.role === 'list') {
      this.listSection(slot.block)
    } else if (slot.role === 'steps') {
      this.stepsSection(slot.block)
    } else {
      this.genericSection(slot)
    }
  }

  build() {
    if (this.slots().length > 0) {
      Column() {
        ForEach(this.slots(), (slot: StructuredSlot, index: number) => {
          if (index > 0) {
            Divider()
              .strokeWidth(0.5)
              .color(ColorTokens.separator)
          }
          this.slotSection(slot)
        }, (slot: StructuredSlot) => slot.role + ':' + slot.block.id)
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
