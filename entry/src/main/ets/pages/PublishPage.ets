// 发布器 — Phase 2.5：玻璃操作栏 + 渐进式发布工作流；业务提交语义保持不变。
import { LengthMetrics } from '@kit.ArkUI';
import { createPost, listTags } from '../services/api';
import { ensureLogin } from '../utils/auth';
import { Genre, StructuredData, Tag, User } from '../models/types';
import { ImagePicker } from '../components/ImagePicker';
import { TagIcon } from '../components/TagIcon';
import { safeShowToast } from '../utils/toast';
import { resolveActionIcon } from '../utils/actionIcons';
import { BaseCard } from '../design/components/BaseCard';
import { DesignButton } from '../design/components/DesignButton';
import { GlassPanel } from '../design/components/GlassPanel';
import { IconTile } from '../design/components/IconTile';
import { ChipItem, ChipRow } from '../design/components/ChipRow';
import { Collapse } from '../design/motion/Collapse';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { barBottomReserve } from '../utils/cardTokens';

interface GenreItem {
  key: Genre;
  label: string;
  hint: string;
  iconRes: Resource;
}

const GENRE_LIST: GenreItem[] = [
  { key: 'review', label: '测评', hint: '优缺点与推荐指数', iconRes: $r('app.media.genre_review') },
  { key: 'pitfall', label: '避坑', hint: '踩坑经历与正确做法', iconRes: $r('app.media.genre_pitfall') },
  { key: 'tutorial', label: '教程', hint: '工具与步骤拆解', iconRes: $r('app.media.genre_tutorial') },
  { key: 'debate', label: '辩论', hint: 'A/B 方案投票', iconRes: $r('app.media.genre_debate') },
];

const GENRE_CHIPS: ChipItem[] = [
  { key: 'review', label: '测评' },
  { key: 'pitfall', label: '避坑' },
  { key: 'tutorial', label: '教程' },
  { key: 'debate', label: '辩论' },
];

const MAX_SELECTED_TAGS: number = 3;
const MAX_PICKED_IMAGES: number = 9;
const DRAFT_PROGRESS_TOTAL: number = 3;

type FieldDef = [keyof StructuredData, string];

function genreFieldDefs(genre: Genre): FieldDef[] {
  switch (genre) {
    case 'review':
      return [['pros', '优点'], ['cons', '缺点'], ['rating', '推荐指数'], ['targetAudience', '适合人群']];
    case 'pitfall':
      return [['pitfallExperience', '踩坑经历'], ['lossAmount', '损失金额'], ['correctApproach', '正确做法']];
    case 'tutorial':
      return [['tools', '准备工具'], ['steps', '步骤拆解'], ['timeDifficulty', '耗时/难度']];
    case 'debate':
      return [['planA', '方案A'], ['planB', '方案B']];
    default:
      return [];
  }
}

function readField(sd: StructuredData, key: keyof StructuredData): string | number | undefined {
  switch (key) {
    case 'pros': return sd.pros;
    case 'cons': return sd.cons;
    case 'rating': return sd.rating;
    case 'targetAudience': return sd.targetAudience;
    case 'pitfallExperience': return sd.pitfallExperience;
    case 'lossAmount': return sd.lossAmount;
    case 'correctApproach': return sd.correctApproach;
    case 'tools': return sd.tools;
    case 'steps': return sd.steps;
    case 'timeDifficulty': return sd.timeDifficulty;
    case 'planA': return sd.planA;
    case 'planB': return sd.planB;
    default: return undefined;
  }
}

function withField(sd: StructuredData, key: keyof StructuredData, value: string): StructuredData {
  const out: StructuredData = {
    pros: sd.pros,
    cons: sd.cons,
    rating: sd.rating,
    targetAudience: sd.targetAudience,
    pitfallExperience: sd.pitfallExperience,
    lossAmount: sd.lossAmount,
    correctApproach: sd.correctApproach,
    tools: sd.tools,
    steps: sd.steps,
    timeDifficulty: sd.timeDifficulty,
    planA: sd.planA,
    planB: sd.planB,
  };
  switch (key) {
    case 'pros': out.pros = value; break;
    case 'cons': out.cons = value; break;
    case 'rating': out.rating = value; break;
    case 'targetAudience': out.targetAudience = value; break;
    case 'pitfallExperience': out.pitfallExperience = value; break;
    case 'lossAmount': out.lossAmount = value; break;
    case 'correctApproach': out.correctApproach = value; break;
    case 'tools': out.tools = value; break;
    case 'steps': out.steps = value; break;
    case 'timeDifficulty': out.timeDifficulty = value; break;
    case 'planA': out.planA = value; break;
    case 'planB': out.planB = value; break;
    default: break;
  }
  return out;
}

function isLongField(key: keyof StructuredData): boolean {
  return key === 'pros' || key === 'cons' || key === 'pitfallExperience' ||
    key === 'correctApproach' || key === 'steps' || key === 'tools' ||
    key === 'planA' || key === 'planB';
}

function currentGenreMeta(genre: Genre): GenreItem {
  for (const item of GENRE_LIST) {
    if (item.key === genre) {
      return item;
    }
  }
  return GENRE_LIST[0];
}

@Component
export struct PublishPage {
  @State genre: Genre = 'review';
  @State genreIndex: number = 0;
  @State selectedTags: string[] = [];
  @State title: string = '';
  @State content: string = '';
  @State sd: StructuredData = {};
  @State images: string[] = [];
  @State tags: Tag[] = [];
  @State publishing: boolean = false;
  @State error: string = '';
  @State showFields: boolean = false;
  @State showTagPanel: boolean = false;
  @StorageLink('authUserId') @Watch('onUserChange') uid: string = '';
  @State categoryList: string[] = [];
  @State tagsByCategory: Record<string, Tag[]> = {};

  private calcDraftProgress(): number {
    let done: number = 0;
    if (this.title.trim().length > 0) {
      done += 1;
    }
    if (this.content.trim().length > 0 || this.images.length > 0) {
      done += 1;
    }
    if (this.selectedTags.length > 0) {
      done += 1;
    }
    return done;
  }

  private draftProgressText(): string {
    return '草稿完成 ' + this.calcDraftProgress() + '/' + DRAFT_PROGRESS_TOTAL;
  }

  aboutToAppear(): void {
    this.loadTags();
  }

  private onUserChange(): void {
    this.reset();
  }

  private async loadTags(): Promise<void> {
    try {
      this.tags = await listTags();
      this.buildTagCategoryData();
    } catch (e) {
      // 标签加载失败不阻断正文编辑；打开面板时只展示空列表。
    }
  }

  private buildTagCategoryData(): void {
    const map: Map<string, Tag[]> = new Map();
    for (const t of this.tags) {
      const cat: string = t.category ?? '其他';
      const arr: Tag[] | undefined = map.get(cat);
      if (arr !== undefined) {
        arr.push(t);
      } else {
        map.set(cat, [t]);
      }
    }
    const rec: Record<string, Tag[]> = {};
    const cats: string[] = [];
    map.forEach((value: Tag[], key: string) => {
      rec[key] = value;
      cats.push(key);
    });
    this.tagsByCategory = rec;
    this.categoryList = cats;
  }

  private async ensureToken(): Promise<boolean> {
    try {
      const u: User | null = await ensureLogin();
      return !!u;
    } catch (e) {
      this.error = '登录失败：' + (e as Error).message;
      return false;
    }
  }

  private onFieldChange(key: keyof StructuredData, value: string): void {
    this.sd = withField(this.sd, key, value);
  }

  private buildStructuredData(): StructuredData {
    const out: Record<string, string | number> = {};
    for (const item of genreFieldDefs(this.genre)) {
      const raw = readField(this.sd, item[0]);
      if (raw !== undefined && raw !== '') {
        if (item[0] === 'rating') {
          const n = Number(raw);
          if (!isNaN(n)) {
            out['rating'] = n;
          }
        } else {
          out[item[0] as string] = String(raw);
        }
      }
    }
    return out as StructuredData;
  }

  private toggleTag(name: string): void {
    if (name.length === 0) {
      return;
    }
    if (this.selectedTags.indexOf(name) >= 0) {
      this.selectedTags = this.selectedTags.filter((n: string) => n !== name);
    } else {
      if (this.selectedTags.length >= MAX_SELECTED_TAGS) {
        safeShowToast(this.getUIContext(), { message: '最多选 ' + MAX_SELECTED_TAGS + ' 个标签' });
        return;
      }
      this.selectedTags = [...this.selectedTags, name];
    }
  }

  private async publish(): Promise<void> {
    if (this.publishing) {
      return;
    }
    if (!this.title.trim()) {
      safeShowToast(this.getUIContext(), { message: '请填写标题' });
      return;
    }
    const okTok = await this.ensureToken();
    if (!okTok) {
      return;
    }
    this.publishing = true;
    try {
      const images = this.images;
      const p = await createPost({
        title: this.title.trim(),
        content: this.content,
        genre: this.genre,
        tags: this.selectedTags,
        structuredData: this.buildStructuredData(),
        images: images,
        coverImage: this.images.length > 0 ? this.images[0] : undefined,
      });
      safeShowToast(this.getUIContext(), { message: '发布成功！帖子ID=' + (p.id ?? '') });
      this.reset();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '发布失败：' + (e as Error).message });
    } finally {
      this.publishing = false;
    }
  }

  private reset(): void {
    this.genre = 'review';
    this.genreIndex = 0;
    this.selectedTags = [];
    this.title = '';
    this.content = '';
    this.sd = {};
    this.images = [];
    this.showFields = false;
    this.showTagPanel = false;
  }

  private tagName(t: Tag): string {
    return t.name ?? '';
  }

  private isTagSelected(t: Tag): boolean {
    return this.selectedTags.indexOf(this.tagName(t)) >= 0;
  }

  private currentGenreIcon(): Resource {
    return currentGenreMeta(this.genre).iconRes;
  }

  private currentGenreHint(): string {
    return currentGenreMeta(this.genre).hint;
  }

  @Builder
  sectionHeader(icon: Resource, titleText: string, caption: string): void {
    Row({ space: SpaceTokens.item }) {
      IconTile({ icon: icon, tileSize: IconTokens.empty, iconSize: IconTokens.standard })
      Column({ space: SpaceTokens.xs }) {
        Text(titleText)
          .fontSize(TypeTokens.headline.size)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .letterSpacing(TypeTokens.headline.tracking)
          .fontColor(ColorTokens.primary)
        Text(caption)
          .fontSize(TypeTokens.callout.size)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .letterSpacing(TypeTokens.callout.tracking)
          .fontColor(ColorTokens.secondary)
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  genreSectionHeader(): void {
    Row({ space: SpaceTokens.item }) {
      IconTile({ icon: this.currentGenreIcon(), tileSize: IconTokens.empty, iconSize: IconTokens.standard })
      Column({ space: SpaceTokens.xs }) {
        Text('创作类型')
          .fontSize(TypeTokens.headline.size)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.headline.lineHeight)
          .letterSpacing(TypeTokens.headline.tracking)
          .fontColor(ColorTokens.primary)
        Text(this.currentGenreHint())
          .fontSize(TypeTokens.callout.size)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .letterSpacing(TypeTokens.callout.tracking)
          .fontColor(ColorTokens.secondary)
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  topComposerBar(): void {
    GlassPanel({ panelPadding: SpaceTokens.item, radius: RadiusTokens.xl }) {
      Row({ space: SpaceTokens.item }) {
        Pressable({
          visualHeight: LayoutTokens.minTouchTarget,
          action: () => { this.reset(); },
        }) {
          Text('清空')
            .fontSize(TypeTokens.callout.size)
            .fontWeight(TypeTokens.callout.weight)
            .lineHeight(TypeTokens.callout.lineHeight)
            .fontColor(ColorTokens.secondary)
            .height(LayoutTokens.minTouchTarget)
            .textAlign(TextAlign.Center)
        }
        Column({ space: SpaceTokens.xs }) {
          Text('发布内容')
            .fontSize(TypeTokens.headline.size)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.headline.lineHeight)
            .letterSpacing(TypeTokens.headline.tracking)
            .fontColor(ColorTokens.primary)
            .textAlign(TextAlign.Center)
          Text(this.draftProgressText())
            .fontSize(TypeTokens.caption.size)
            .fontWeight(TypeTokens.caption.weight)
            .lineHeight(TypeTokens.caption.lineHeight)
            .fontColor(ColorTokens.secondary)
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        DesignButton({
          label: this.publishing ? '发布中' : '发布',
          disabled: this.publishing || this.title.trim().length === 0,
          action: (): void => { this.publish(); },
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  genreSection(): void {
    BaseCard({ cardPadding: SpaceTokens.base, radius: RadiusTokens.lg, elevation: 1 }) {
      Column({ space: SpaceTokens.block }) {
        this.genreSectionHeader()
        ChipRow({
          items: GENRE_CHIPS,
          selectedIndex: $genreIndex,
          showIcon: false,
          sidePadding: SpaceTokens.none,
          itemGap: SpaceTokens.inline,
          onSelect: (index: number): void => {
            this.genre = GENRE_LIST[index].key;
          },
        })
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  editorSection(): void {
    BaseCard({ cardPadding: SpaceTokens.base, radius: RadiusTokens.lg, elevation: 1 }) {
      Column({ space: SpaceTokens.item }) {
        this.sectionHeader($r('app.media.book_doc'), '正文', '先写清楚结论，再补充过程与证据')
        TextInput({ text: this.title, placeholder: '一句话标题' })
          .width('100%')
          .fontSize(TypeTokens.title.size)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .letterSpacing(TypeTokens.title.tracking)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.quaternary)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => { this.title = value; })
        Divider().height(LayoutTokens.hairlineWidth).color(ColorTokens.separator)
        TextArea({ text: this.content, placeholder: '展开讲讲背景、过程、结论。尽量给出你踩过的坑、判断标准和适用人群。' })
          .width('100%')
          .height(LayoutTokens.composerBodyHeight)
          .fontSize(TypeTokens.body.size)
          .fontWeight(TypeTokens.body.weight)
          .lineHeight(TypeTokens.body.lineHeight)
          .letterSpacing(TypeTokens.body.tracking)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.quaternary)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => { this.content = value; })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  mediaSection(): void {
    BaseCard({ cardPadding: SpaceTokens.xs, radius: RadiusTokens.lg, elevation: 1 }) {
      Column({ space: SpaceTokens.item }) {
        Row({ space: SpaceTokens.item }) {
          IconTile({ icon: $r('app.media.layered_image'), tileSize: IconTokens.empty, iconSize: IconTokens.standard })
          Column({ space: SpaceTokens.xs }) {
            Text('图片')
              .fontSize(TypeTokens.headline.size)
              .fontWeight(TypeTokens.headline.weight)
              .lineHeight(TypeTokens.headline.lineHeight)
              .fontColor(ColorTokens.primary)
            Text('最多 ' + MAX_PICKED_IMAGES + ' 张，第一张会作为封面')
              .fontSize(TypeTokens.callout.size)
              .fontWeight(TypeTokens.callout.weight)
              .lineHeight(TypeTokens.callout.lineHeight)
              .fontColor(ColorTokens.secondary)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .padding({ left: SpaceTokens.item, right: SpaceTokens.item, top: SpaceTokens.item })
        ImagePicker({ selected: $images, maxCount: MAX_PICKED_IMAGES })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  tagPill(name: string): void {
    Pressable({
      visualHeight: LayoutTokens.segmentedHeight,
      action: () => { this.toggleTag(name); },
    }) {
      Row({ space: SpaceTokens.inlineTight }) {
        Text(name)
          .fontSize(TypeTokens.callout.size)
          .fontWeight(TypeTokens.caption.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.onBrand)
        Image(resolveActionIcon('close'))
          .width(IconTokens.compact)
          .height(IconTokens.compact)
          .fillColor(ColorTokens.onBrand)
      }
      .height(LayoutTokens.segmentedHeight)
      .padding({ left: SpaceTokens.item, right: SpaceTokens.item })
      .backgroundColor(ColorTokens.brand)
      .borderRadius(RadiusTokens.sm)
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  tagSection(): void {
    BaseCard({ cardPadding: SpaceTokens.base, radius: RadiusTokens.lg, elevation: 1 }) {
      Column({ space: SpaceTokens.block }) {
        this.sectionHeader($r('app.media.tag_all'), '发布到圈子', '最多选择 ' + MAX_SELECTED_TAGS + ' 个，让帖子去对的地方')
        if (this.selectedTags.length > 0) {
          Flex({
            wrap: FlexWrap.Wrap,
            space: { main: LengthMetrics.px(SpaceTokens.inline), cross: LengthMetrics.px(SpaceTokens.inline) },
          }) {
            ForEach(this.selectedTags, (name: string) => {
              this.tagPill(name)
            }, (name: string) => 'selected_' + name)
          }
          .width('100%')
        }
        DesignButton({
          label: this.selectedTags.length > 0 ? '调整圈子' : '选择圈子',
          variant: this.selectedTags.length > 0 ? 'ghost' : 'primary',
          fillWidth: true,
          action: (): void => { this.showTagPanel = true; },
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  fieldInput(item: FieldDef): void {
    Column({ space: SpaceTokens.inline }) {
      Text(item[1])
        .fontSize(TypeTokens.caption.size)
        .fontWeight(TypeTokens.caption.weight)
        .lineHeight(TypeTokens.caption.lineHeight)
        .fontColor(ColorTokens.secondary)
        .width('100%')
      if (isLongField(item[0])) {
        TextArea({ text: String(readField(this.sd, item[0]) ?? ''), placeholder: item[1] })
          .width('100%')
          .height(LayoutTokens.composerFieldHeight)
          .fontSize(TypeTokens.callout.size)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.quaternary)
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.sm)
          .padding(SpaceTokens.item)
          .onChange((value: string) => { this.onFieldChange(item[0], value); })
      } else {
        TextInput({ text: String(readField(this.sd, item[0]) ?? ''), placeholder: item[1] })
          .width('100%')
          .fontSize(TypeTokens.callout.size)
          .fontWeight(TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(ColorTokens.primary)
          .placeholderColor(ColorTokens.quaternary)
          .backgroundColor(ColorTokens.subtle)
          .borderRadius(RadiusTokens.sm)
          .padding(SpaceTokens.item)
          .onChange((value: string) => { this.onFieldChange(item[0], value); })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  structuredSection(): void {
    BaseCard({ cardPadding: SpaceTokens.base, radius: RadiusTokens.lg, elevation: 1 }) {
      Column({ space: SpaceTokens.block }) {
        Pressable({
          fillWidth: true,
          visualHeight: LayoutTokens.minTouchTarget,
          action: () => { this.showFields = !this.showFields; },
        }) {
          Row({ space: SpaceTokens.item }) {
            IconTile({ icon: $r('app.media.set_edit'), tileSize: IconTokens.empty, iconSize: IconTokens.standard })
            Column({ space: SpaceTokens.xs }) {
              Text('结构化补充')
                .fontSize(TypeTokens.headline.size)
                .fontWeight(TypeTokens.headline.weight)
                .lineHeight(TypeTokens.headline.lineHeight)
                .fontColor(ColorTokens.primary)
              Text(this.currentGenreHint())
                .fontSize(TypeTokens.callout.size)
                .fontWeight(TypeTokens.callout.weight)
                .lineHeight(TypeTokens.callout.lineHeight)
                .fontColor(ColorTokens.secondary)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Image(this.showFields ? resolveActionIcon('chevronUp') : resolveActionIcon('chevronDown'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
              .fillColor(ColorTokens.brand)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        Collapse({ expanded: this.showFields }) {
          Column({ space: SpaceTokens.item }) {
            ForEach(genreFieldDefs(this.genre), (item: FieldDef) => {
              this.fieldInput(item)
            }, (item: FieldDef) => item[0] as string)
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  tagChoice(t: Tag): void {
    Pressable({
      visualHeight: LayoutTokens.segmentedHeight,
      action: () => { this.toggleTag(this.tagName(t)); },
    }) {
      Row({ space: SpaceTokens.inline }) {
        TagIcon({
          name: this.tagName(t),
          iconSize: IconTokens.compact,
          tint: this.isTagSelected(t) ? ColorTokens.onBrand : ColorTokens.primary,
        })
        Text(this.tagName(t))
          .fontSize(TypeTokens.callout.size)
          .fontWeight(this.isTagSelected(t) ? TypeTokens.headline.weight : TypeTokens.callout.weight)
          .lineHeight(TypeTokens.callout.lineHeight)
          .fontColor(this.isTagSelected(t) ? ColorTokens.onBrand : ColorTokens.primary)
      }
      .height(LayoutTokens.segmentedHeight)
      .padding({ left: SpaceTokens.item, right: SpaceTokens.item })
      .backgroundColor(this.isTagSelected(t) ? ColorTokens.brand : ColorTokens.sunken)
      .borderRadius(RadiusTokens.sm)
      .alignItems(VerticalAlign.Center)
      .animation({ duration: MotionTokens.fast, curve: MotionCurves.standard })
    }
  }

  @Builder
  tagPanel(): void {
    Column() {
      Row() {
        GlassPanel({ panelPadding: SpaceTokens.item, radius: RadiusTokens.xl }) {
          Row({ space: SpaceTokens.item }) {
            Column({ space: SpaceTokens.xs }) {
              Text('选择圈子')
                .fontSize(TypeTokens.headline.size)
                .fontWeight(TypeTokens.headline.weight)
                .lineHeight(TypeTokens.headline.lineHeight)
                .fontColor(ColorTokens.primary)
              Text('已选择 ' + this.selectedTags.length + '/' + MAX_SELECTED_TAGS)
                .fontSize(TypeTokens.caption.size)
                .fontWeight(TypeTokens.caption.weight)
                .lineHeight(TypeTokens.caption.lineHeight)
                .fontColor(ColorTokens.secondary)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            DesignButton({
              label: '完成',
              action: (): void => { this.showTagPanel = false; },
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
      }
      .width('100%')
      .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, top: SpaceTokens.item, bottom: SpaceTokens.item })

      Scroll() {
        Column({ space: SpaceTokens.section }) {
          if (this.categoryList.length === 0) {
            BaseCard({ cardPadding: SpaceTokens.xl, radius: RadiusTokens.lg, elevation: 1 }) {
              Text('圈子加载中，稍后再试')
                .fontSize(TypeTokens.callout.size)
                .fontColor(ColorTokens.secondary)
                .width('100%')
                .textAlign(TextAlign.Center)
            }
          }
          ForEach(this.categoryList, (cat: string) => {
            Column({ space: SpaceTokens.item }) {
              Text(cat)
                .fontSize(TypeTokens.overline.size)
                .fontWeight(TypeTokens.overline.weight)
                .lineHeight(TypeTokens.overline.lineHeight)
                .letterSpacing(TypeTokens.overline.tracking)
                .fontColor(ColorTokens.secondary)
                .width('100%')
              Flex({
                wrap: FlexWrap.Wrap,
                space: { main: LengthMetrics.px(SpaceTokens.inline), cross: LengthMetrics.px(SpaceTokens.inline) },
              }) {
                ForEach(this.tagsByCategory[cat] ?? [], (t: Tag) => {
                  this.tagChoice(t)
                }, (t: Tag) => t.name ?? '')
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }, (cat: string) => cat)
          Row().height(SpaceTokens.x2l).width('100%')
        }
        .width('100%')
        .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.base })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .padding({ bottom: barBottomReserve() })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
    .transition(TransitionEffect.OPACITY
      .animation({ duration: MotionTokens.fast, curve: MotionCurves.standard })
      .combine(TransitionEffect.translate({ y: SpaceTokens.item })
        .animation({ duration: MotionTokens.base, curve: MotionCurves.standard })))
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll() {
        Column({ space: SpaceTokens.section }) {
          Row().height(LayoutTokens.composerTopOverlayReserve).width('100%')
          this.genreSection()
          this.editorSection()
          this.mediaSection()
          this.tagSection()
          this.structuredSection()
          Row().height(SpaceTokens.x2l).width('100%')
        }
        .width('100%')
        .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, bottom: SpaceTokens.base })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .padding({ bottom: barBottomReserve() })
      .backgroundColor(ColorTokens.canvas)

      Row() {
        this.topComposerBar()
      }
      .width('100%')
      .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, top: SpaceTokens.sm, bottom: SpaceTokens.item })

      if (this.showTagPanel) {
        this.tagPanel()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.canvas)
  }
}
