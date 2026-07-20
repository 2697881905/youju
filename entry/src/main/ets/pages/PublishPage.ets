// 发布器（Tab 内容）— 小红书风格：一页到底，无需翻步骤
// 图片置顶 → 体裁 chip 选 → 标题/正文 → 标签弹层 → 结构化字段可折叠
// 图片在 ImagePicker 内选图即直传腾讯云 COS，selected 已是远端 URL
import { LengthMetrics } from '@kit.ArkUI';
import {
  createPost, updatePost, getPost, listTags,
  CreatePostBody, UpdatePostBody,
} from '../services/api';
import { ensureLogin } from '../utils/auth';
import { Genre, StructuredData, Tag } from '../models/types';
import { ImagePicker } from '../components/ImagePicker';
import { safeShowToast } from '../utils/toast';

// 体裁元数据
interface GenreItem {
  key: Genre;
  label: string;
  icon: string;
}
const GENRE_LIST: GenreItem[] = [
  { key: 'review', label: '📊 测评', icon: '📊' },
  { key: 'pitfall', label: '⚠️ 避坑', icon: '⚠️' },
  { key: 'tutorial', label: '🛠️ 教程', icon: '🛠️' },
  { key: 'debate', label: '🗳️ 辩论', icon: '🗳️' },
];

type FieldDef = [keyof StructuredData, string];
function genreFieldDefs(genre: Genre): FieldDef[] {
  switch (genre) {
    case 'review':
      return [['pros', '优点'], ['cons', '缺点'], ['rating', '推荐指数(0-5)'], ['targetAudience', '适合人群']];
    case 'pitfall':
      return [['pitfallExperience', '踩坑经历'], ['lossAmount', '损失金额'], ['correctApproach', '正确做法']];
    case 'tutorial':
      return [['tools', '准备工具'], ['steps', '步骤拆解'], ['timeDifficulty', '耗时 / 难度']];
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
    pros: sd.pros, cons: sd.cons, rating: sd.rating, targetAudience: sd.targetAudience,
    pitfallExperience: sd.pitfallExperience, lossAmount: sd.lossAmount,
    correctApproach: sd.correctApproach, tools: sd.tools, steps: sd.steps,
    timeDifficulty: sd.timeDifficulty, planA: sd.planA, planB: sd.planB,
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

@Component
export struct PublishPage {
  @State genre: Genre = 'review';
  @State selectedTags: string[] = [];
  @State title: string = '';
  @State content: string = '';
  @State sd: StructuredData = {};
  @State images: string[] = [];
  @State tags: Tag[] = [];
  @State publishing: boolean = false;
  @State error: string = '';
  @State editPostId: number = 0;
  @State isEditMode: boolean = false;
  // 小红书风格：结构化字段默认折叠
  @State showFields: boolean = false;

  private get canPublish(): boolean {
    return !this.publishing && this.title.trim().length > 0;
  }

  aboutToAppear(): void {
    const editId: number = (AppStorage.get<number>('editPostId') ?? 0) as number;
    if (editId > 0) {
      this.isEditMode = true;
      this.editPostId = editId;
      AppStorage.setOrCreate('editPostId', 0);
      this.loadPostForEdit(editId);
    }
    this.loadTags();
  }

  private async loadPostForEdit(id: number): Promise<void> {
    try {
      const post = await getPost(id);
      this.title = post.title ?? '';
      this.content = post.content ?? '';
      this.genre = post.genre as Genre ?? 'review';
      this.selectedTags = post.tags as string[] ?? [];
      this.images = post.images ?? [];
      const sd: StructuredData = {};
      if (post.structuredData) {
        const raw = post.structuredData as Record<string, Object>;
        if (typeof raw.pros === 'string') sd.pros = raw.pros as string;
        if (typeof raw.cons === 'string') sd.cons = raw.cons as string;
        if (typeof raw.rating === 'number' || typeof raw.rating === 'string') sd.rating = raw.rating as string;
        if (typeof raw.targetAudience === 'string') sd.targetAudience = raw.targetAudience as string;
        if (typeof raw.pitfallExperience === 'string') sd.pitfallExperience = raw.pitfallExperience as string;
        if (typeof raw.lossAmount === 'string') sd.lossAmount = raw.lossAmount as string;
        if (typeof raw.correctApproach === 'string') sd.correctApproach = raw.correctApproach as string;
        if (typeof raw.tools === 'string') sd.tools = raw.tools as string;
        if (typeof raw.steps === 'string') sd.steps = raw.steps as string;
        if (typeof raw.timeDifficulty === 'string') sd.timeDifficulty = raw.timeDifficulty as string;
        if (typeof raw.planA === 'string') sd.planA = raw.planA as string;
        if (typeof raw.planB === 'string') sd.planB = raw.planB as string;
      }
      this.sd = sd;
      this.showFields = Object.keys(sd).some((k: string) => (sd as Record<string, Object>)[k] !== undefined);
    } catch (e) {
      this.error = '加载帖子失败：' + (e as Error).message;
    }
  }

  private async loadTags(): Promise<void> {
    try {
      this.tags = await listTags();
    } catch (e) {
      // 标签加载失败不阻断
    }
  }

  private async ensureToken(): Promise<boolean> {
    try {
      await ensureLogin();
      return true;
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
    const defs: FieldDef[] = genreFieldDefs(this.genre);
    for (const item of defs) {
      const raw = readField(this.sd, item[0]);
      if (raw !== undefined && raw !== '') {
        if (item[0] === 'rating') {
          const n: number = Number(raw);
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
    if (this.selectedTags.indexOf(name) >= 0) {
      this.selectedTags = this.selectedTags.filter((n: string) => n !== name);
    } else {
      if (this.selectedTags.length >= 3) {
        safeShowToast(this.getUIContext(),{ message: '最多选 3 个标签' });
        return;
      }
      this.selectedTags = [...this.selectedTags, name];
    }
  }

  private async publish(): Promise<void> {
    if (this.publishing) return;
    if (!this.title.trim()) {
      safeShowToast(this.getUIContext(),{ message: '请填写标题' });
      return;
    }
    const okTok: boolean = await this.ensureToken();
    if (!okTok) return;
    this.publishing = true;
    this.error = '';
    try {
      const images: string[] = this.images;
      if (this.isEditMode) {
        const body: UpdatePostBody = {
          title: this.title.trim(), content: this.content,
          tags: this.selectedTags, structuredData: this.buildStructuredData(), images: images,
        };
        await updatePost(this.editPostId, body);
        safeShowToast(this.getUIContext(),{ message: '编辑成功' });
      } else {
        const body: CreatePostBody = {
          title: this.title.trim(), content: this.content,
          genre: this.genre, tags: this.selectedTags,
          structuredData: this.buildStructuredData(), images: images,
        };
        const p = await createPost(body);
        safeShowToast(this.getUIContext(),{ message: '发布成功！帖子ID=' + (p.id ?? '') });
      }
      this.reset();
    } catch (e) {
      this.error = (e as Error).message;
      safeShowToast(this.getUIContext(),{ message: (this.isEditMode ? '编辑' : '发布') + '失败：' + this.error });
    } finally {
      this.publishing = false;
    }
  }

  private reset(): void {
    this.genre = 'review';
    this.selectedTags = [];
    this.title = '';
    this.content = '';
    this.sd = {};
    this.images = [];
    this.showFields = false;
    this.isEditMode = false;
    this.editPostId = 0;
  }

  // ===== 体裁 Chip 行 =====
  @Builder
  genreChips(): void {
    Row({ space: 8 }) {
      ForEach(GENRE_LIST, (g: GenreItem) => {
        Text(g.label)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.genre === g.key ? '#FFFFFF' : $r('app.color.text_primary'))
          .backgroundColor(this.genre === g.key ? $r('app.color.brand_primary') : $r('app.color.bg_secondary'))
          .borderRadius(14)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => { this.genre = g.key; })
      }, (g: GenreItem) => g.key)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  // ===== 标签 Chip 区（横向滚动 Flex 换行）=====
  @Builder
  tagChips(): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('添加标签')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
        Text('(1-3个)')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.px(8), cross: LengthMetrics.px(8) } }) {
        ForEach(this.tags, (t: Tag) => {
          Text((t.emoji ? t.emoji + ' ' : '') + (t.name ?? ''))
            .fontSize(13)
            .fontColor(this.selectedTags.indexOf(t.name ?? '') >= 0 ? '#FFFFFF' : $r('app.color.text_primary'))
            .backgroundColor(this.selectedTags.indexOf(t.name ?? '') >= 0
              ? $r('app.color.brand_primary')
              : $r('app.color.bg_secondary'))
            .borderRadius(14)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => this.toggleTag(t.name ?? ''))
        }, (t: Tag) => t.name ?? '')
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
  }

  // ===== 结构化字段区（可折叠）=====
  @Builder
  structuredFields(): void {
    Column({ space: 10 }) {
      Row() {
        Text('结构化信息（选填）')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
        Blank()
        Text(this.showFields ? '收起 ▲' : '展开 ▼')
          .fontSize(12)
          .fontColor($r('app.color.brand_primary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .onClick(() => { this.showFields = !this.showFields; })

      if (this.showFields) {
        Column({ space: 10 }) {
          ForEach(genreFieldDefs(this.genre), (item: FieldDef) => {
            Column({ space: 4 }) {
              Text(item[1])
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
              if (isLongField(item[0])) {
                TextArea({ text: String(readField(this.sd, item[0]) ?? ''), placeholder: item[1] })
                  .width('100%')
                  .height(72)
                  .fontSize(14)
                  .backgroundColor($r('app.color.bg_secondary'))
                  .borderRadius(10)
                  .padding(10)
                  .onChange((v: string) => this.onFieldChange(item[0], v))
              } else {
                TextInput({ text: String(readField(this.sd, item[0]) ?? ''), placeholder: item[1] })
                  .width('100%')
                  .fontSize(14)
                  .backgroundColor($r('app.color.bg_secondary'))
                  .borderRadius(10)
                  .padding(10)
                  .onChange((v: string) => this.onFieldChange(item[0], v))
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }, (item: FieldDef) => item[0] as string)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
    }
  }

  build() {
    Column() {
      // ===== 顶部栏：取消 | 标题 | 发布 =====
      Row() {
        Text('取消')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => { this.reset(); })
        Blank()
        Text(this.isEditMode ? '编辑帖子' : '发布帖子')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Button(this.isEditMode ? '保存' : '发布')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .height(32)
          .padding({ left: 16, right: 16 })
          .enabled(this.canPublish)
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .onClick(() => { this.publish(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor($r('app.color.bg_primary'))

      // ===== 内容区：一页到底 =====
      Scroll() {
        Column({ space: 16 }) {
          // ① 图片区（置顶，主角）
          ImagePicker({ selected: $images, maxCount: 9 })

          // ② 体裁 Chip 选
          this.genreChips()

          // ③ 标题
          TextInput({ text: this.title, placeholder: '一句话说清你的经验…' })
            .width('100%')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .backgroundColor($r('app.color.bg_primary'))
            .padding({ left: 16, right: 16 })

          // ④ 正文
          TextArea({ text: this.content, placeholder: '展开讲讲背景、过程、结论…' })
            .width('100%')
            .height(120)
            .fontSize(15)
            .backgroundColor($r('app.color.bg_primary'))
            .padding({ left: 16, right: 16 })

          // ⑤ 标签
          this.tagChips()

          // ⑥ 结构化字段（可折叠）
          this.structuredFields()

          // 底部留白
          Row().height(40).width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}