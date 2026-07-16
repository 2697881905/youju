// 发布器（Tab 内容）：四步流程
// Step0 选体裁 → Step1 选标签(1~3) → Step2 填标题/正文/结构化表单/图片 → Step3 预览&发布
// 发布前自动用 dev 账号 login 拿 token（Account Kit 未接，先用 dev 桩）。
// 图片在 ImagePicker 内选图即直传腾讯云 COS，selected 已是远端 URL，本页直接提交。
import { promptAction, LengthMetrics } from '@kit.ArkUI';
import {
  createPost,
  listTags,
  CreatePostBody,
} from '../services/api';
import { ensureLogin } from '../utils/auth';
import { Genre, StructuredData, Tag } from '../models/types';
import { ImagePicker } from '../components/ImagePicker';

// 体裁元数据
interface GenreItem {
  key: Genre;
  label: string;
  icon: string;
  desc: string;
}
const GENRE_LIST: GenreItem[] = [
  { key: 'review', label: '测评报告', icon: '📊', desc: '深度体验某产品 / 服务' },
  { key: 'pitfall', label: '避坑指南', icon: '⚠️', desc: '分享踩过的坑' },
  { key: 'tutorial', label: '实操教程', icon: '🛠️', desc: '手把手教做一件事' },
  { key: 'debate', label: '辩论投票', icon: '🗳️', desc: '抛出两难让大家选' },
];

// 各体裁结构化字段：[字段键, 中文标签]
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

// 显式复制结构化字段（ArkTS V1 禁止对象展开/计算键）
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

// 长文本字段用多行输入
function isLongField(key: keyof StructuredData): boolean {
  return key === 'pros' || key === 'cons' || key === 'pitfallExperience' ||
    key === 'correctApproach' || key === 'steps' || key === 'tools' ||
    key === 'planA' || key === 'planB';
}

const STEP_LABELS: string[] = ['选体裁', '选标签', '填内容', '预览发布'];

@Component
export struct PublishPage {
  @State step: number = 0;
  @State genre: Genre = 'review';
  @State selectedTags: string[] = [];
  @State title: string = '';
  @State content: string = '';
  @State sd: StructuredData = {};
  @State images: string[] = [];
  @State tags: Tag[] = [];
  @State publishing: boolean = false;
  @State error: string = '';

  aboutToAppear(): void {
    this.loadTags();
  }

  private async loadTags(): Promise<void> {
    try {
      this.tags = await listTags();
    } catch (e) {
      // 标签加载失败不阻断，留空
    }
  }

  // 发布前确保有登录态（走统一 AuthManager）
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

  // 把表单字符串组装成后端结构化对象（rating 转数字）
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
        promptAction.showToast({ message: '最多选 3 个标签' });
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
      promptAction.showToast({ message: '请填写标题' });
      return;
    }
    const okTok: boolean = await this.ensureToken();
    if (!okTok) {
      return;
    }
    this.publishing = true;
    this.error = '';
    try {
      // 图片已在 ImagePicker 内直传 COS，images 已是远端 URL
      const images: string[] = this.images;
      const body: CreatePostBody = {
        title: this.title.trim(),
        content: this.content,
        genre: this.genre,
        tags: this.selectedTags,
        structuredData: this.buildStructuredData(),
        images: images,
      };
      const p = await createPost(body);
      promptAction.showToast({ message: '发布成功！帖子ID=' + (p.id ?? '') });
      this.reset();
    } catch (e) {
      this.error = (e as Error).message;
      promptAction.showToast({ message: '发布失败：' + this.error });
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
    this.step = 0;
  }

  @Builder
  stepBar(): void {
    Row() {
      ForEach(STEP_LABELS, (label: string, idx: number) => {
        Column({ space: 4 }) {
          Text((idx + 1).toString())
            .fontSize(13)
            .fontColor(this.step === idx ? Color.White : $r('app.color.text_secondary'))
            .backgroundColor(this.step === idx ? $r('app.color.brand_primary') : $r('app.color.bg_secondary'))
            .width(22)
            .height(22)
            .borderRadius(11)
            .textAlign(TextAlign.Center)
          Text(label)
            .fontSize(11)
            .fontColor(this.step === idx ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Center)
        if (idx < STEP_LABELS.length - 1) {
          Row()
            .width(18)
            .height(1)
            .backgroundColor($r('app.color.text_secondary'))
        }
      }, (label: string) => label)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  @Builder
  step0Genre(): void {
    Column({ space: 12 }) {
      ForEach(GENRE_LIST, (g: GenreItem) => {
        Row({ space: 12 }) {
          Text(g.icon).fontSize(28)
          Column({ space: 2 }) {
            Text(g.label).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            Text(g.desc).fontSize(12).fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.bg_secondary'))
        .borderRadius(12)
        .onClick(() => {
          this.genre = g.key;
          this.step = 1;
        })
      }, (g: GenreItem) => g.key)
    }
    .width('100%')
    .padding(16)
  }

  @Builder
  step1Tags(): void {
    Column({ space: 12 }) {
      Text('选择 1~3 个标签')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.px(10), cross: LengthMetrics.px(10) } }) {
        ForEach(this.tags, (t: Tag) => {
          Text((t.emoji ? t.emoji + ' ' : '') + (t.name ?? ''))
            .fontSize(14)
            .fontColor(this.selectedTags.indexOf(t.name ?? '') >= 0 ? Color.White : $r('app.color.text_primary'))
            .backgroundColor(this.selectedTags.indexOf(t.name ?? '') >= 0 ? $r('app.color.brand_primary') : $r('app.color.bg_secondary'))
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(16)
            .onClick(() => this.toggleTag(t.name ?? ''))
        }, (t: Tag) => t.name ?? '')
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
  }

  @Builder
  step2Form(): void {
    Scroll() {
      Column({ space: 14 }) {
        Text('标题')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        TextInput({ text: this.title, placeholder: '一句话说清你的经验' })
          .width('100%')
          .onChange((v: string) => { this.title = v; })

        Text('正文')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        TextArea({ text: this.content, placeholder: '展开讲讲背景、过程、结论…' })
          .width('100%')
          .height(120)

        ImagePicker({ selected: $images, maxCount: 9 })

        Text('结构化信息')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        ForEach(genreFieldDefs(this.genre), (item: FieldDef) => {
          Column({ space: 4 }) {
            Text(item[1])
              .fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
            if (isLongField(item[0])) {
              TextArea({ text: String(readField(this.sd, item[0]) ?? ''), placeholder: item[1] })
                .width('100%')
                .height(80)
                .onChange((v: string) => this.onFieldChange(item[0], v))
            } else {
              TextInput({ text: String(readField(this.sd, item[0]) ?? ''), placeholder: item[1] })
                .width('100%')
                .onChange((v: string) => this.onFieldChange(item[0], v))
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }, (item: FieldDef) => item[0] as string)
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  step3Preview(): void {
    Scroll() {
      Column({ space: 14 }) {
        Text('预览')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        // 体裁 chip
        Row() {
          Text(GENRE_LIST.find((g: GenreItem) => g.key === this.genre)?.label ?? '')
            .fontSize(12)
            .fontColor($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.bg_secondary'))
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(10)
        }
        .width('100%')
        // 标题
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        // 标签
        if (this.selectedTags.length > 0) {
          Row({ space: 8 }) {
            ForEach(this.selectedTags, (n: string) => {
              Text('#' + n)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }, (n: string) => n)
          }
          .width('100%')
        }
        // 图片
        if (this.images.length > 0) {
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.px(8), cross: LengthMetrics.px(8) } }) {
            ForEach(this.images, (uri: string) => {
              Image(uri)
                .width('30%')
                .aspectRatio(1)
                .objectFit(ImageFit.Cover)
                .borderRadius(8)
            }, (uri: string) => uri)
          }
          .width('100%')
        }
        // 结构化字段
        ForEach(genreFieldDefs(this.genre), (item: FieldDef) => {
          if (readField(this.sd, item[0]) !== undefined && readField(this.sd, item[0]) !== '') {
            Column({ space: 2 }) {
              Text(item[1])
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
              Text(String(readField(this.sd, item[0])))
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(10)
            .backgroundColor($r('app.color.bg_secondary'))
            .borderRadius(8)
          }
        }, (item: FieldDef) => item[0] as string)
        // 正文
        if (this.content) {
          Text(this.content)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
        }
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  footer(): void {
    Row({ space: 12 }) {
      if (this.step > 0) {
        Button('上一步')
          .layoutWeight(1)
          .onClick(() => { this.step = this.step - 1; })
      }
      Button(this.step < 3 ? '下一步' : '发布')
        .layoutWeight(1)
        .enabled(!this.publishing)
        .onClick(() => {
          if (this.step < 3) {
            if (this.step === 1 && this.selectedTags.length === 0) {
              promptAction.showToast({ message: '至少选 1 个标签' });
              return;
            }
            this.step = this.step + 1;
          } else {
            this.publish();
          }
        })
    }
    .width('100%')
    .padding(16)
  }

  build() {
    Column() {
      this.stepBar()
      if (this.step === 0) {
        this.step0Genre()
      } else if (this.step === 1) {
        this.step1Tags()
      } else if (this.step === 2) {
        this.step2Form()
      } else {
        this.step3Preview()
      }
      if (this.step === 0) {
        // 体裁页占满剩余空间
        Blank()
      }
      this.footer()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
