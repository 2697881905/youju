// 帖子详情页（真实内容）：标签 → 体裁 → 标题 → 九宫格图 → 结构化字段 → 正文 → 评论区 → 底部操作栏
import { router } from '@kit.ArkUI';
import {
  getPost,
  createComment,
  upPost,
  cancelUpPost,
  bookmarkPost,
  cancelBookmarkPost,
  PostWithComments,
} from '../services/api';
import { Genre, Comment, StructuredData } from '../models/types';
import { timeAgo, formatCount } from '../utils/format';
import { CommentList } from '../components/CommentList';
import { takeDetailPostId } from '../utils/nav';
import { safeShowToast } from '../utils/toast';

// 字段定义：[结构化字段键, 中文标签]，按产品文档 2.4 各体裁字段表
type FieldDef = [keyof StructuredData, string];
// 渲染用：[中文标签, 值]
type FieldPair = [string, string];

// ArkTS V1 禁止按变量索引对象，这里用显式 switch 读取结构化字段
function readField(sd: StructuredData, key: keyof StructuredData): string | number | undefined {
  switch (key) {
    case 'pros':
      return sd.pros;
    case 'cons':
      return sd.cons;
    case 'rating':
      return sd.rating;
    case 'targetAudience':
      return sd.targetAudience;
    case 'pitfallExperience':
      return sd.pitfallExperience;
    case 'lossAmount':
      return sd.lossAmount;
    case 'correctApproach':
      return sd.correctApproach;
    case 'tools':
      return sd.tools;
    case 'steps':
      return sd.steps;
    case 'timeDifficulty':
      return sd.timeDifficulty;
    case 'planA':
      return sd.planA;
    case 'planB':
      return sd.planB;
    default:
      return undefined;
  }
}

interface GenreMeta {
  label: string;
  icon: string;
}

function genreMeta(genre?: Genre): GenreMeta {
  switch (genre) {
    case 'review':
      return { label: '测评报告', icon: '📊' };
    case 'pitfall':
      return { label: '避坑指南', icon: '⚠️' };
    case 'tutorial':
      return { label: '实操教程', icon: '🛠️' };
    case 'debate':
      return { label: '辩论投票', icon: '🗳️' };
    default:
      return { label: '经验分享', icon: '📝' };
  }
}

function structuredFieldDefs(genre?: Genre): FieldDef[] {
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

@Entry
@Component
struct DetailPage {
  @State postId: string = '';
  @State post: PostWithComments | null = null;
  @State fields: FieldPair[] = [];
  @State images: string[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State uped: boolean = false;
  @State bookmarked: boolean = false;
  @State commenting: boolean = false;
  @State commentText: string = '';

  private get pid(): number {
    return Number(this.postId);
  }

  aboutToAppear(): void {
    // API 24 router.getParams 失效；AppStorage 是框架级全局单例（主通道），模块单例作 fallback
    const fromApp: string | undefined = AppStorage.get<string>('detailPostId');
    const fromSingleton: string = takeDetailPostId();
    this.postId = (fromApp ?? fromSingleton ?? '').trim();
    this.load();
  }

  async load(): Promise<void> {
    const raw: string = this.postId;
    if (raw === '') {
      this.loading = false;
      this.error = '帖子参数缺失(raw empty)';
      return;
    }
    const idNum: number = parseInt(raw, 10);
    if (isNaN(idNum)) {
      this.loading = false;
      this.error = '帖子参数缺失(raw=' + JSON.stringify(raw) + ',type=' + typeof raw + ')';
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      const p = await getPost(idNum);
      if (!p) {
        this.error = '帖子不存在或已下架';
        return;
      }
      this.post = p;
      this.fields = this.buildFields(p);
      this.images = this.imagesOf(p);
    } catch (e) {
      this.error = (e as Error).message;
    } finally {
      this.loading = false;
    }
  }

  // 把后端自由结构的结构化字段，按体裁映射成 [中文标签, 值] 列表
  private buildFields(p: PostWithComments): FieldPair[] {
    const defs = structuredFieldDefs(p.genre);
    if (defs.length === 0) {
      return [];
    }
    const sd: StructuredData | undefined = p.structuredData;
    const out: FieldPair[] = [];
    if (sd) {
      for (const item of defs) {
        const raw = readField(sd, item[0]);
        if (raw !== undefined && raw !== null) {
          out.push([item[1], String(raw)]);
        }
      }
    }
    return out;
  }

  private imagesOf(p: PostWithComments): string[] {
    const imgs = p.images ?? [];
    if (imgs.length === 0 && p.coverImage) {
      return [p.coverImage];
    }
    return imgs;
  }

  async onUp(): Promise<void> {
    if (!this.post || this.post.id === undefined) {
      return;
    }
    const id = this.post.id;
    const willUp = !this.uped;
    this.uped = willUp;
    this.post.upCount = (this.post.upCount ?? 0) + (willUp ? 1 : -1);
    try {
      if (willUp) {
        await upPost(id);
      } else {
        await cancelUpPost(id);
      }
    } catch (e) {
      this.uped = !willUp;
      this.post.upCount = (this.post.upCount ?? 0) + (willUp ? -1 : 1);
      safeShowToast(this.getUIContext(),{ message: '操作失败，请先登录' });
    }
  }

  async onBookmark(): Promise<void> {
    if (!this.post || this.post.id === undefined) {
      return;
    }
    const id = this.post.id;
    const willMark = !this.bookmarked;
    this.bookmarked = willMark;
    this.post.bookmarkCount = (this.post.bookmarkCount ?? 0) + (willMark ? 1 : -1);
    try {
      if (willMark) {
        await bookmarkPost(id);
      } else {
        await cancelBookmarkPost(id);
      }
    } catch (e) {
      this.bookmarked = !willMark;
      this.post.bookmarkCount = (this.post.bookmarkCount ?? 0) + (willMark ? -1 : 1);
      safeShowToast(this.getUIContext(),{ message: '操作失败，请先登录' });
    }
  }

  onShare(): void {
    safeShowToast(this.getUIContext(),{ message: '分享功能开发中' });
  }

  async onSendComment(): Promise<void> {
    const text = this.commentText.trim();
    if (!text || !this.post || this.post.id === undefined) {
      return;
    }
    try {
      await createComment(this.post.id, { content: text });
      this.commentText = '';
      this.commenting = false;
      await this.load();
    } catch (e) {
      safeShowToast(this.getUIContext(),{ message: '评论失败，请先登录' });
    }
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('← 返回')
          .fontSize(16)
          .fontColor($r('app.color.brand_primary'))
          .onClick(() => router.back())
        Text('帖子详情')
          .fontSize(17)
          .fontWeight(600)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('')
          .width(48)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      if (this.loading) {
        Column() {
          LoadingProgress().width(28).height(28)
          Text('加载中…')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 10 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.error) {
        Column() {
          Text(this.error)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
          Button('重试')
            .margin({ top: 16 })
            .onClick(() => this.load())
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.post) {
        Scroll() {
          Column({ space: 16 }) {
            // 标签 + 体裁 + 标题 + 作者
            Column({ space: 8 }) {
              if (this.post.tags && this.post.tags.length > 0) {
                Row({ space: 8 }) {
                  ForEach(
                    this.post.tags,
                    (t: string) => {
                      Text(t.startsWith('#') ? t : ('#' + t))
                        .fontSize(13)
                        .fontColor($r('app.color.brand_primary'))
                    },
                    (t: string) => t
                  )
                }
              }
              Row() {
                Text(genreMeta(this.post.genre).icon + ' ' + genreMeta(this.post.genre).label)
                  .fontSize(12)
                  .fontColor($r('app.color.brand_primary'))
                  .backgroundColor('#E8F1FF')
                  .borderRadius(4)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              }
              Text(this.post.title ?? '')
                .fontSize(20)
                .fontWeight(700)
                .fontColor($r('app.color.text_primary'))
              Row({ space: 8 }) {
                Text(this.post.user?.nickname ?? '匿名用户')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                Text(timeAgo(this.post.createdAt))
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 九宫格图
            if (this.images.length > 0) {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                ForEach(
                  this.images,
                  (url: string) => {
                    Image(url)
                      .width('32%')
                      .aspectRatio(1)
                      .objectFit(ImageFit.Cover)
                      .borderRadius(8)
                  },
                  (url: string) => url
                )
              }
              .width('100%')
            }

            // 结构化字段
            if (this.fields.length > 0) {
              Column({ space: 10 }) {
                ForEach(
                  this.fields,
                  (f: FieldPair) => {
                    Row({ space: 8 }) {
                      Text(f[0])
                        .fontSize(14)
                        .fontColor($r('app.color.text_secondary'))
                        .width(76)
                      Text(f[1])
                        .fontSize(14)
                        .fontColor($r('app.color.text_primary'))
                        .layoutWeight(1)
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Top)
                  },
                  (f: FieldPair) => f[0]
                )
              }
              .width('100%')
              .padding(14)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(12)
            }

            // 正文
            if (this.post.content) {
              Text(this.post.content)
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .lineHeight(24)
                .width('100%')
            }

            // 评论区
            Column({ space: 10 }) {
              Text('评论 ' + formatCount(this.post.commentCount))
                .fontSize(16)
                .fontWeight(600)
                .fontColor($r('app.color.text_primary'))
              CommentList({ comments: this.post.comments ?? [] })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .padding(16)
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')

        // 评论输入框
        if (this.commenting) {
          Row({ space: 8 }) {
            TextInput({ placeholder: '理性补充，有图有真相', text: this.commentText })
              .layoutWeight(1)
              .height(40)
              .backgroundColor($r('app.color.bg_primary'))
              .borderRadius(20)
              .onChange((v: string) => {
                this.commentText = v;
              })
            Button('发送')
              .height(36)
              .onClick(() => this.onSendComment())
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor($r('app.color.card_bg'))
        }

        // 底部操作栏
        Row() {
          Column({ space: 2 }) {
            Text('👍').fontSize(20)
            Text((this.uped ? '已' : '') + '顶 ' + formatCount(this.post.upCount))
              .fontSize(11)
              .fontColor(this.uped ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .onClick(() => this.onUp())

          Column({ space: 2 }) {
            Text('📥').fontSize(20)
            Text((this.bookmarked ? '已' : '') + '抄作业 ' + formatCount(this.post.bookmarkCount))
              .fontSize(11)
              .fontColor(this.bookmarked ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .onClick(() => this.onBookmark())

          Column({ space: 2 }) {
            Text('💬').fontSize(20)
            Text('评论 ' + formatCount(this.post.commentCount))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .onClick(() => {
            this.commenting = true;
          })

          Column({ space: 2 }) {
            Text('🔗').fontSize(20)
            Text('分享')
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .onClick(() => this.onShare())
        }
        .width('100%')
        .padding({ top: 8, bottom: 12 })
        .backgroundColor($r('app.color.card_bg'))
        .borderWidth({ top: 0.5 })
        .borderColor($r('app.color.divider'))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
  }
}
