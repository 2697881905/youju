import { StructuredFieldPair } from '../utils/structuredFields';
import { StructuredFieldBlock, withoutHeadline } from './StructuredFieldView';
import { formatCount } from '../utils/format';import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { debateVoteStore } from '../utils/debateVoteStore';
import { doesTextFitInPoster } from '../utils/poster/posterRender';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { ShadowTokens } from '../design/tokens/shadow';
import { HighlightSegment, parseHighlightSegments } from '../utils/textHighlight';
import { openCircleDetail, openUserProfile } from '../utils/nav';
import { openCircleDetailViaNav } from '../utils/navigationTransition';
import { MentionRef, StructuredDocument } from '../models/types';
import { StructuredFlowView } from './StructuredFlowView';

// 详情正文只负责体裁内容的展示；投票的请求和回滚仍由 DetailPage 持有。

// 结构化帖正文收起/展开（2026-11-23 口径）：不设字数门槛，所有有正文的结构化帖均可收起展开

@Component
export struct DetailPostContent {
  // 当前详情壳是否走 Navigation：正文里的 #话题# 跟随壳走对应导航方式
  @Prop navMode: boolean = false;
  // 结构化字段投影（含 kind）：字段表与读取都来自 utils/structuredFields
  @Prop pairs: StructuredFieldPair[] = [];
  @Prop structuredDocument: StructuredDocument | null = null;
  @Prop genre: string = '';
  @Prop content: string = '';
  @Prop coverOnlyTextPoster: boolean = false;
  @Prop planA: string = '';
  @Prop planB: string = '';
  @Prop votePostId: number = 0;
  // 正文 @提及 → 用户映射（后端按 userId 解析入库），命中时点击跳转用户主页
  @Prop mentions: MentionRef[] = [];
  onVote: (choice: string) => void = (_choice: string): void => {};
  // 长按结构化卡片回调：详情页弹「复制正文」菜单。只挂结构化卡片（见 build）——
  // 正文 Text 已开启系统文本选择复制（copyOption），长按正文走原生选择，
  // 外层长按菜单不得与之竞争；标题同理在 DetailPostHeader 单独开启。
  onLongPressContent: (event: GestureEvent) => void = (_event: GestureEvent): void => {};
  // 用户点击「收起正文」、bodyExpanded true→false 完成后同步回调（每次收起恰一次，展开不调用）。
  // 详情页据此把滚动位置锚定回正文顶部（PostDetailView.anchorScrollToBodyTop）。
  onBodyCollapsed: () => void = (): void => {};
  // 正文展开态：支持收起展开的结构化帖打开时为 false（结构化优先，只展示导语预览，不设字数门槛），
  // 其余帖子恒为 true（渲染与现状一致）。v1 不持久化、不跨组件提升。
  @State bodyExpanded: boolean = false;
  // 智感握姿（PostDetailView 订阅 motion.holdingHandChanged → animateTo 写 AppStorage.gripOnRight，
  // 与 DetailPostHeader 同款消费范式）：收起/展开入口随握持手整组贴边——右手握持入口居右（拇指侧），
  // 左手/未握持/双手/设备不支持/系统开关关闭 → 默认居左。换边过渡由 PostDetailView 的 animateTo 驱动。
  @StorageProp('gripOnRight') gripOnRight: boolean = false;
  @State planAVotes: number = 0;
  @State planBVotes: number = 0;
  @State myVote: string = '';
  private unsubscribeVote: () => void = () => {};

  aboutToAppear(): void {
    // 默认收起判定在这里落地：支持收起展开的帖子初始为收起态（结构化优先，不设字数门槛），
    // 其余帖子恒为展开态，build 输出与现状完全一致。
    this.bodyExpanded = !this.supportsBodyCollapse();
    this.refreshVoteState();
    this.unsubscribeVote = debateVoteStore.subscribe((postId: number): void => {
      if (postId === this.votePostId) {
        this.refreshVoteState();
      }
    });
  }

  aboutToDisappear(): void {
    this.unsubscribeVote();
    this.unsubscribeVote = () => {};
  }

  private refreshVoteState(): void {
    const vote = debateVoteStore.get(this.votePostId);
    if (!vote) {
      return;
    }
    // 给本组件的原始 @State 赋值，确保 ArkUI 重新计算票数文本和进度宽度。
    this.planAVotes = vote.planAVotes;
    this.planBVotes = vote.planBVotes;
    this.myVote = vote.choice;
  }

  // 分段配色：正文常规色 / @提及 蓝 / #话题# 品牌棕。
  // @提及与话题原先共用 brand，用户分不清点的是「人」还是「话题」，故 mention 单列蓝色 token。
  private colorOfSegment(type: string): ResourceColor {
    if (type === 'text') {
      return ColorTokens.primary;
    }
    if (type === 'mention') {
      return ColorTokens.mention;
    }
    return ColorTokens.brand;
  }

  // 长按结构化卡片 → 详情页「复制正文」菜单（三处结构化分支共用，见 build）
  private contentLongPress(): LongPressGestureInterface {
    return LongPressGesture({ repeat: false, duration: 400 })
      .onAction((event: GestureEvent): void => { this.onLongPressContent(event); });
  }

  // 正文高亮分段：@提及 与 #话题# 以各自强调色加粗展示（解析代价小，正文通常 < 2K）
  @Builder
  private highlightBody(): void {
    Text() {
      ForEach(parseHighlightSegments(this.content), (seg: HighlightSegment) => {
        Span(seg.raw)
          .fontColor(this.colorOfSegment(seg.type))
          .fontWeight(FontWeight.Bold)
          .onClick(() => {
            if (seg.type === 'tag') {
              this.goCircle(seg.name);
            } else if (seg.type === 'mention') {
              this.goMention(seg.name);
            }
          })
      }, (seg: HighlightSegment) => seg.type + ':' + seg.raw + ':' + seg.name)
    }
    // 正文加粗：工程只打包 NotoSerifSC 的 Regular/Bold 两套字形（无 Medium），
    // Body 字族绑的是 Regular——要真粗体字形必须切到 Bold 字族；
    // 在 Regular 字族上设 fontWeight 只会伪粗或被忽略（familyName 只绑一个字体文件）。
    .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamilySerif)
    .fontColor(ColorTokens.primary)
    .lineHeight(32)
    .width('100%')
    .textAlign(TextAlign.Start)
    // 长按正文 → 系统文本选择，可选字复制/全选（官方文档：copyOption 设为
    // InApp/LocalDevice 时长按弹出文本选择菜单）。Span 的 onClick 保留，点击仍可跳话题/用户。
    .copyOption(CopyOptions.LocalDevice)
    .selectedBackgroundColor(ColorTokens.brandTint)
  }

  // 收起态的导语预览：纯文本 2 行截断（不解析 @提及/#话题# 高亮、无文本选择交互——
  // 展开后才是完整可交互正文），底部线性渐隐（透明→canvas 底色）提示下方还有正文。
  @Builder
  private collapsedPreview(): void {
    Stack({ alignContent: Alignment.Bottom }) {
      Text(this.content)
        .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontColor(ColorTokens.primary)
        .lineHeight(32)
        .width('100%')
        .maxLines(2)
        .textAlign(TextAlign.Start)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      // 渐隐条与画布同色，文本底部渐出而非生硬截断；不拦截触控
      Column()
        .width('100%')
        .height(20)
        .linearGradient({
          angle: 180,
          colors: [[Color.Transparent, 0], [ColorTokens.canvas, 1]],
        })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
  }

  // 点击 #话题# → 圈子详情
  private goCircle(name: string): void {
    if (this.navMode && openCircleDetailViaNav(name)) {
      return;
    }
    openCircleDetail(name);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CircleDetailPage' });
  }

  // 点击 @提及 → 命中后端解析的用户映射则跳转其主页，否则仅提示
  private goMention(name: string): void {
    let uid: number = 0;
    for (const m of this.mentions) {
      if (m.name === name && m.userId > 0) {
        uid = m.userId;
        break;
      }
    }
    if (uid === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '@' + name, duration: 1000 });
      return;
    }
    openUserProfile(uid);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
  }

  private totalVotes(): number {
    return this.planAVotes + this.planBVotes;
  }  private voteWidth(votes: number): string {
    const total: number = this.totalVotes();
    return total > 0 ? (votes / total) * 100 + '%' : '0%';
  }

  private voteCount(choice: string): number {
    return choice === 'A' ? this.planAVotes : this.planBVotes;
  }

  private debateValue(left: boolean): string {
    const legacy: string = left ? this.planA : this.planB;
    if (legacy.length > 0) return legacy;
    if (this.structuredDocument !== null) {
      for (const block of this.structuredDocument.blocks) {
        if (block.type === 'compare') return left ? block.leftValue : block.rightValue;
      }
    }
    return '';
  }

  @Builder
  private voteRow(planName: string, fallbackLabel: string, choice: string): void {
    Row() {
      Text(planName.length > 0 ? planName : fallbackLabel)
        .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.primary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ right: SpaceTokens.sm });
      Row() {
        Column()
          .width(this.voteWidth(this.voteCount(choice)))
          .height(6)
          .borderRadius(3)
          .backgroundColor(ColorTokens.brand);
        Column()
          .layoutWeight(1)
          .height(6)
          .borderRadius(3)
          .backgroundColor(ColorTokens.sunken);
      }
      .width(72)
      .height(6)
      .margin({ right: SpaceTokens.sm });
      Text(formatCount(this.voteCount(choice)) + '票')
        .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.secondary)
        .margin({ left: SpaceTokens.sm });
      Row({ space: 2 }) {
        if (this.myVote === choice) {
          Image(resolveActionIcon('check'))
            .width(13)
            .height(13)
            .fillColor(ColorTokens.icon)
        }
        Text(this.myVote === choice ? '已投' : '投票')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(this.myVote === choice ? ColorTokens.brand : ColorTokens.secondary)
      }
      .width(52)
      .justifyContent(FlexAlign.Center)
      .onClick((): void => { this.onVote(choice); });
    }
    .width('100%');
  }

  @Builder
  private debatePanel(): void {
    Column({ space: SpaceTokens.lg }) {
      this.voteRow(this.debateValue(true), '方案A', 'A');
      this.voteRow(this.debateValue(false), '方案B', 'B');
    }
    .width('100%')
    .padding(18)
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(RadiusTokens.md)
    .border({ width: 0.5, color: ColorTokens.separator, style: BorderStyle.Solid })
    .shadow(ShadowTokens.floating)
    .clip(true);
  }

  // V2 信息流判定：与 build 的分支条件同源。V1 辩论帖（无信息流）继续走独立投票面板。
  private hasStructuredFlow(): boolean {
    return this.structuredDocument !== null && this.structuredDocument.blocks.length > 0;
  }

  // 正文收起/展开能力判定（单一出处，不设字数门槛）：结构化信息流非空 + 正文未被海报完整容纳。
  // 海报完整容纳正文时正文本来就不渲染，无收起可言；V1 字段投影旧帖/分享体裁天然不满足。
  private supportsBodyCollapse(): boolean {
    return this.hasStructuredFlow()
      && (!this.coverOnlyTextPoster || !doesTextFitInPoster(this.content));
  }

  // 字段块内容：头条指标（损失金额）已由结论卡承担，这里去掉避免同屏重复；
  // 辩论体裁的方案文字已合并进投票卡片，也不再重复展示。
  private bodyPairs(): StructuredFieldPair[] {
    if (this.genre === 'debate') {
      return [];
    }
    return withoutHeadline(this.pairs);
  }

  build() {
    Column({ space: SpaceTokens.lg }) {
      // V2 用完整视觉信息流；历史帖子继续走旧字段投影，不要求数据迁移后才能阅读。
      if (this.hasStructuredFlow()) {
        StructuredFlowView({
          document: this.structuredDocument,
          checkInPostId: this.votePostId,
          genre: this.genre,
          // 辩论对决槽的投票接线：票数快照与回调透传，请求/回滚仍由 DetailPage 持有
          planAVotes: this.planAVotes,
          planBVotes: this.planBVotes,
          myVote: this.myVote,
          debateInteractive: this.genre === 'debate',
          onVote: (choice: string): void => { this.onVote(choice); },
        })
          .gesture(this.contentLongPress())
      } else {
        // ⚠️ 字段为空时这两个组件 build 出来是"零节点"，但仍占用父/根 Column 的子槽位——
        // space 会照插不误（父 16 + 根 20×2 ≈ 56vp），普通图文/视频帖媒体与正文之间
        // 因此多出一大段空白（结构化帖 FlowView 有真实内容，无此问题）。
        // 必须整段跳过，让它们连槽位都不占。
        if (this.pairs.length > 0) {
          StructuredFieldBlock({ pairs: this.bodyPairs() })
            .gesture(this.contentLongPress())
        }
        // 独立投票面板仅 V1 辩论帖保留：V2 辩论帖的对决槽已含投票，重复渲染会让
        // 方案文案出现两次（2026-11-05 重设计）。
        if (this.genre === 'debate') {
          this.debatePanel();
        }
      }
      if (this.content.length > 0) {
        // 文字海报已完整容纳正文时不再冗余展示纯文本；
        // 海报截断（省略号）时仍显示完整正文，确保读者不丢信息。
        if (!this.coverOnlyTextPoster || !doesTextFitInPoster(this.content)) {
          if (this.supportsBodyCollapse() && !this.bodyExpanded) {
            // 收起态：导语预览 + 展开入口（结构化帖的结构化优先阅读，不设字数门槛）
            this.collapsedPreview()
            // 展开入口随握持手贴边滑动（右手握持 → 居右拇指侧，默认居左）：整行宽 Row 只做对齐
            // 容器，点击热区仍只包文字本身。justifyContent 是可插值布局属性（DetailActionBar
            // 握姿换边同款口径），换边由 PostDetailView 的 animateTo 驱动，无节点重建。
            Row() {
              Text('展开正文（约 ' + formatCount(this.content.length) + ' 字）')
                .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.brand)
                .onClick((): void => {
                  this.getUIContext().animateTo({
                    duration: MotionTokens.container,
                    curve: MotionCurves.springInteract,
                  }, (): void => {
                    this.bodyExpanded = true;
                  });
                })
            }
            .width('100%')
            .justifyContent(this.gripOnRight ? FlexAlign.End : FlexAlign.Start)
          } else {
            this.highlightBody()
            // 展开态的收起入口：仅支持收起功能的帖子渲染，不满足收起条件的帖子
            // 不出现任何入口（build 输出与现状完全一致）
            if (this.supportsBodyCollapse()) {
              // 收起入口与展开入口同组，同随握持手贴边（对称行为，见上方展开入口注释）
              Row() {
                Text('收起正文')
                  .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                  .fontColor(ColorTokens.brand)
                  .onClick((): void => {
                    this.getUIContext().animateTo({
                      duration: MotionTokens.container,
                      curve: MotionCurves.springInteract,
                    }, (): void => {
                      this.bodyExpanded = false;
                    });
                    // animateTo 的闭包同步执行：此刻状态已切换完成，每次收起恰回调一次
                    this.onBodyCollapsed();
                  })
              }
              .width('100%')
              .justifyContent(this.gripOnRight ? FlexAlign.End : FlexAlign.Start)
            }
          }
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
