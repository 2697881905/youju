// 发布器 — Apple 风格（分组卡片 + 紧凑标签 + 全屏标签选择面板）
import { LengthMetrics } from '@kit.ArkUI';
import {
  createPost, updatePost, getPost, listTags,
  CreatePostBody, UpdatePostBody,
} from '../services/api';
import { ensureLogin } from '../utils/auth';
import { Genre, StructuredData, Tag } from '../models/types';
import { ImagePicker } from '../components/ImagePicker';
import { safeShowToast } from '../utils/toast';

interface GenreItem {
  key: Genre;
  label: string;
  icon: string;
}
const GENRE_LIST: GenreItem[] = [
  { key: 'review', label: '测评', icon: '📊' },
  { key: 'pitfall', label: '避坑', icon: '⚠️' },
  { key: 'tutorial', label: '教程', icon: '🛠️' },
  { key: 'debate', label: '辩论', icon: '🗳️' },
];

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

// 可复用分组卡片
@Component
struct SectionCard {
  @BuilderParam content: () => void = this.emptyContent;
  @Builder emptyContent(): void {}
  build() {
    Column() { this.content() }
      .width('100%')
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(14)
      .shadow({ radius: 12, color: '#0A000000', offsetY: 1 })
      .padding(16)
  }
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
  @State showFields: boolean = false;
  @State showTagPanel: boolean = false;
  // 标签分类数据（@State 驱动，ForEach 可靠刷新）
  @State categoryList: string[] = [];
  @State tagsByCategory: Record<string, Tag[]> = {};

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
      this.buildTagCategoryData();
    } catch (e) { /* 不阻断 */ }
  }

  // 将标签按分类聚合到 @State 数据（供面板 ForEach 渲染）
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
    // 转换为 Record + 分类列表
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
    try { await ensureLogin(); return true; }
    catch (e) { this.error = '登录失败：' + (e as Error).message; return false; }
  }

  private onFieldChange(key: keyof StructuredData, value: string): void {
    this.sd = withField(this.sd, key, value);
  }

  private buildStructuredData(): StructuredData {
    const out: Record<string, string | number> = {};
    for (const item of genreFieldDefs(this.genre)) {
      const raw = readField(this.sd, item[0]);
      if (raw !== undefined && raw !== '') {
        if (item[0] === 'rating') { const n = Number(raw); if (!isNaN(n)) out['rating'] = n; }
        else out[item[0] as string] = String(raw);
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
    if (!this.title.trim()) { safeShowToast(this.getUIContext(),{ message: '请填写标题' }); return; }
    const okTok = await this.ensureToken();
    if (!okTok) return;
    this.publishing = true;
    try {
      const images = this.images;
      if (this.isEditMode) {
        await updatePost(this.editPostId, {
          title: this.title.trim(), content: this.content,
          tags: this.selectedTags, structuredData: this.buildStructuredData(), images: images,
        });
        safeShowToast(this.getUIContext(),{ message: '编辑成功' });
      } else {
        const p = await createPost({
          title: this.title.trim(), content: this.content,
          genre: this.genre, tags: this.selectedTags,
          structuredData: this.buildStructuredData(), images: images,
        });
        safeShowToast(this.getUIContext(),{ message: '发布成功！帖子ID=' + (p.id ?? '') });
      }
      this.reset();
    } catch (e) {
      safeShowToast(this.getUIContext(),{ message: (this.isEditMode ? '编辑' : '发布') + '失败：' + (e as Error).message });
    } finally {
      this.publishing = false;
    }
  }

  private reset(): void {
    this.genre = 'review'; this.selectedTags = [];
    this.title = ''; this.content = ''; this.sd = {};
    this.images = []; this.showFields = false; this.showTagPanel = false;
    this.isEditMode = false; this.editPostId = 0;
  }

  // 体裁 chip 行
  @Builder genreChips(): void {
    Row({ space: 10 }) {
      ForEach(GENRE_LIST, (g: GenreItem) => {
        Row({ space: 4 }) {
          Text(g.icon).fontSize(15).fontColor(this.genre === g.key ? '#FFFFFF' : $r('app.color.text_primary'))
          Text(g.label).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.genre === g.key ? '#FFFFFF' : $r('app.color.text_primary'))
        }
        .backgroundColor(this.genre === g.key ? $r('app.color.brand_primary') : $r('app.color.bg_secondary'))
        .borderRadius(18).padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .onClick(() => { this.genre = g.key; })
      }, (g: GenreItem) => g.key)
    }
  }

  @Builder sectionTitle(text: string): void {
    Text(text).fontSize(13).fontColor($r('app.color.text_secondary')).fontWeight(FontWeight.Bold).width('100%')
  }

  build() {
    Stack() {
      // ===== 主发布页 =====
      Column() {
        // 顶部栏
        Row() {
          Button({ type: ButtonType.Normal }) {
            Text('取消').fontSize(15).fontColor($r('app.color.text_secondary'))
          }
          .backgroundColor(Color.Transparent).onClick(() => { this.reset(); })
          Blank()
          Button(this.isEditMode ? '保存' : '发布')
            .fontSize(14).fontWeight(600).height(34).padding({ left: 20, right: 20 })
            .enabled(this.canPublish)
            .backgroundColor(this.canPublish ? $r('app.color.brand_primary') : '#A0A0A8')
            .fontColor('#FFFFFF').borderRadius(17)
            .onClick(() => { this.publish(); })
        }
        .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 6 })

        Scroll() {
          Column({ space: 20 }) {
            // ① 图片
            ImagePicker({ selected: $images, maxCount: 9 })

            // ② 体裁
            Column({ space: 10 }) {
              this.sectionTitle('体裁')
              this.genreChips()
            }.width('100%').padding({ left: 16, right: 16 })

            // ③ 内容
            Column({ space: 10 }) {
              this.sectionTitle('内容')
              SectionCard() {
                Column({ space: 12 }) {
                  TextInput({ text: this.title, placeholder: '标题' })
                    .width('100%').fontSize(17).fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary')).placeholderColor($r('app.color.text_tertiary'))
                    .backgroundColor(Color.Transparent).onChange((v: string) => { this.title = v; })
                  Divider().height(0.5).color($r('app.color.divider'))
                  TextArea({ text: this.content, placeholder: '展开讲讲背景、过程、结论…' })
                    .width('100%').height(100).fontSize(15)
                    .fontColor($r('app.color.text_primary')).placeholderColor($r('app.color.text_tertiary'))
                    .backgroundColor(Color.Transparent).onChange((v: string) => { this.content = v; })
                }
              }
            }.width('100%').padding({ left: 16, right: 16 })

            // ④ 标签（紧凑行）
            Column({ space: 10 }) {
              this.sectionTitle('标签 · 最多 3 个')
              SectionCard() {
                Column({ space: 8 }) {
                  if (this.selectedTags.length > 0) {
                    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.px(8), cross: LengthMetrics.px(8) } }) {
                      ForEach(this.selectedTags, (name: string) => {
                        Row({ space: 4 }) {
                          Text(name).fontSize(13).fontColor('#FFFFFF')
                          Text('✕').fontSize(11).fontColor('#FFFFFF').onClick(() => this.toggleTag(name))
                        }
                        .backgroundColor($r('app.color.brand_primary')).borderRadius(14)
                        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                      }, (name: string) => 'st_' + name)
                    }.width('100%')
                  }
                  Row({ space: 6 }) {
                    Text('＋').fontSize(15).fontColor($r('app.color.brand_primary'))
                    Text('添加标签').fontSize(13).fontColor($r('app.color.brand_primary'))
                  }
                  .width('100%').height(36).justifyContent(FlexAlign.Center)
                  .backgroundColor($r('app.color.bg_secondary')).borderRadius(10)
                  .onClick(() => { this.showTagPanel = true; })
                }
              }
            }.width('100%').padding({ left: 16, right: 16 })

            // ⑤ 结构化字段（可折叠）
            Column({ space: 10 }) {
              Row() {
                Text('结构化信息 · 选填')
                  .fontSize(13).fontColor($r('app.color.text_secondary')).fontWeight(FontWeight.Bold).layoutWeight(1)
                Text(this.showFields ? '收起 ▲' : '展开 ▼').fontSize(12).fontColor($r('app.color.brand_primary'))
              }.width('100%').padding({ left: 16, right: 16 }).onClick(() => { this.showFields = !this.showFields; })
              if (this.showFields) {
                SectionCard() {
                  Column({ space: 12 }) {
                    ForEach(genreFieldDefs(this.genre), (item: FieldDef) => {
                      Column({ space: 4 }) {
                        Text(item[1]).fontSize(12).fontColor($r('app.color.text_secondary')).width('100%')
                        if (isLongField(item[0])) {
                          TextArea({ text: String(readField(this.sd, item[0]) ?? ''), placeholder: item[1] })
                            .width('100%').height(64).fontSize(14).placeholderColor($r('app.color.text_tertiary'))
                            .backgroundColor($r('app.color.bg_secondary')).borderRadius(10).padding(10)
                            .onChange((v: string) => this.onFieldChange(item[0], v))
                        } else {
                          TextInput({ text: String(readField(this.sd, item[0]) ?? ''), placeholder: item[1] })
                            .width('100%').fontSize(14).placeholderColor($r('app.color.text_tertiary'))
                            .backgroundColor($r('app.color.bg_secondary')).borderRadius(10).padding(10)
                            .onChange((v: string) => this.onFieldChange(item[0], v))
                        }
                      }.width('100%').alignItems(HorizontalAlign.Start)
                    }, (item: FieldDef) => item[0] as string)
                  }
                }
              }
            }.width('100%').padding({ left: 16, right: 16 })

            Row().height(32).width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }
      .width('100%').height('100%').backgroundColor($r('app.color.bg_primary'))

      // ===== 标签选择面板（全屏覆盖）=====
      if (this.showTagPanel) {
        Column() {
          Row() {
            Text('选择标签').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
            Blank()
            Text('1-3个').fontSize(13).fontColor($r('app.color.text_secondary')).margin({ right: 16 })
            Button('完成').fontSize(13).fontWeight(600).height(32).padding({ left: 16, right: 16 })
              .backgroundColor($r('app.color.brand_primary')).fontColor('#FFFFFF').borderRadius(16)
              .onClick(() => { this.showTagPanel = false; })
          }
          .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 }).backgroundColor($r('app.color.bg_primary'))
          Divider().height(0.5).color($r('app.color.divider')).width('100%')

          Scroll() {
            Column({ space: 20 }) {
              ForEach(this.categoryList, (cat: string) => {
                Column({ space: 8 }) {
                  Text(cat).fontSize(13).fontColor($r('app.color.text_secondary')).fontWeight(FontWeight.Bold).width('100%')
                  Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.px(8), cross: LengthMetrics.px(8) } }) {
                    ForEach(this.tagsByCategory[cat] ?? [], (t: Tag) => {
                      Row({ space: 4 }) {
                        if (t.emoji && t.emoji.length > 0) {
                          Text(t.emoji).fontSize(13).fontColor(this.selectedTags.indexOf(t.name ?? '') >= 0 ? '#FFFFFF' : $r('app.color.text_primary'))
                        }
                        Text(t.name ?? '').fontSize(13).fontColor(this.selectedTags.indexOf(t.name ?? '') >= 0 ? '#FFFFFF' : $r('app.color.text_primary'))
                      }
                      .backgroundColor(this.selectedTags.indexOf(t.name ?? '') >= 0 ? $r('app.color.brand_primary') : $r('app.color.bg_secondary'))
                      .borderRadius(14).padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .onClick(() => this.toggleTag(t.name ?? ''))
                    }, (t: Tag) => t.name ?? '')
                  }.width('100%')
                }
              }, (cat: string) => cat)
              Row().height(32).width('100%')
            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 16 }).alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1).width('100%').scrollBar(BarState.Off)
        }
        .width('100%').height('100%').backgroundColor($r('app.color.bg_primary'))
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.bg_primary'))
  }
}