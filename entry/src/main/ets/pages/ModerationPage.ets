// 内容审核台（admin）：待审帖子列表 + 通过/驳回
// 数据：GET /v1/admin/posts/pending（含举报记录）；操作：POST /v1/admin/posts/:id/moderate

import { PendingPost, ReportItem, ReportReason, ModerateAction } from '../models/types';
import { getPendingPosts, moderatePost } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { resolveActionIcon } from '../utils/actionIcons';

// 举报理由 → 中文标签
function reasonLabel(reason: ReportReason): string {
  switch (reason) {
    case 'political': return '涉政敏感';
    case 'pornographic': return '色情低俗';
    case 'personal_attack': return '人身攻击';
    case 'gender_war': return '男女对立引战';
    case 'advertisement': return '广告推广';
    case 'spam': return '垃圾信息';
    case 'other': return '其他';
    default: return reason;
  }
}

// 驳回理由弹窗（复用 @CustomDialog 模式，不可用 AlertDialog 修饰 Column）
@CustomDialog
struct RejectDialog {
  controller: CustomDialogController;
  onSubmit: (reason: string) => void = (_r: string) => {};

  @State reason: string = '';

  build() {
    Column({ space: 16 }) {
      Text('驳回理由')
        .fontSize(18)
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))

      TextArea({ placeholder: '请填写驳回理由（将通知作者，选填）', text: this.reason })
        .height(90)
        .fontSize(14)
        .backgroundColor($r('app.color.bg_primary'))
        .borderRadius(8)
        .onChange((v: string) => {
          this.reason = v;
        })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor($r('app.color.bg_primary'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.controller.close();
          })
        Button('确认驳回')
          .layoutWeight(1)
          .backgroundColor($r('app.color.semantic_red'))
          .fontColor('#FFFFFF')
          .onClick(() => {
            const r: string = this.reason.trim();
            this.controller.close();
            this.onSubmit(r);
          })
      }
      .width('100%')
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

@Entry
@Component
struct ModerationPage {
  @State posts: PendingPost[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State forbidden: boolean = false;
  @State isRefreshing: boolean = false;
  @State processingId: number = 0;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  // 当前待驳回的帖子 id（打开弹窗时写入，提交回调读取）
  private rejectId: number = 0;
  private rejectController: CustomDialogController = new CustomDialogController({
    builder: RejectDialog({
      onSubmit: (reason: string): void => {
        this.doModerate(this.rejectId, 'reject', reason);
      },
    }),
    alignment: DialogAlignment.Center,
    customStyle: false,
  });

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      const res = await getPendingPosts(1, 20);
      this.posts = res.list;
      this.forbidden = false;
    } catch (e) {
      const msg: string = (e as Error).message;
      // 后端 403 文案为「无管理员权限」
      if (msg.includes('权限') || msg.includes('403') || msg.includes('管理员')) {
        this.forbidden = true;
      }
      this.error = msg;
    } finally {
      this.loading = false;
    }
  }

  async doModerate(id: number, action: ModerateAction, reason?: string): Promise<void> {
    if (this.processingId !== 0) {
      return;
    }
    this.processingId = id;
    try {
      await moderatePost(id, action, reason);
      // 审核后从列表移除
      this.posts = this.posts.filter((p: PendingPost) => p.id !== id);
      safeShowToast(this.getUIContext(), {
        message: action === 'approve' ? '已通过' : '已驳回',
      });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.processingId = 0;
    }
  }

  private openReject(id: number): void {
    this.rejectId = id;
    this.rejectController.open();
  }

  // 单条举报理由 chip
  @Builder
  reportReasonChip(reason: ReportReason, desc?: string): void {
    Column({ space: 2 }) {
      Text(reasonLabel(reason))
        .fontSize(12)
        .fontColor($r('app.color.semantic_red'))
        .backgroundColor('#FFE5E5')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .borderRadius(10)
      if (desc && desc.length > 0) {
        Text('“' + desc + '”')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .alignItems(HorizontalAlign.Start)
  }

  // 待审帖子卡片
  @Builder
  postCard(post: PendingPost): void {
    Column({ space: 10 }) {
      // 头部：作者 + 举报数
      Row({ space: 8 }) {
        if (post.user?.avatar) {
          Image(post.user.avatar)
            .width(28)
            .height(28)
            .borderRadius(14)
            .objectFit(ImageFit.Cover)
        } else {
          Text((post.user?.nickname ?? '匿名').charAt(0))
            .width(28)
            .height(28)
            .borderRadius(14)
            .fontSize(13)
            .fontColor('#fff')
            .backgroundColor($r('app.color.brand_primary'))
            .textAlign(TextAlign.Center)
        }
        Text(post.user?.nickname ?? '匿名')
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('举报 ' + String(post.reportCount ?? post.reports?.length ?? 0))
          .fontSize(12)
          .fontColor($r('app.color.semantic_red'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor('#FFE5E5')
          .borderRadius(10)
      }
      .width('100%')

      // 标题 + 正文
      Text(post.title ?? '')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      if (post.content) {
        Text(post.content)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      // 封面
      if (post.coverImage) {
        Image(post.coverImage)
          .width('100%')
          .height(160)
          .objectFit(ImageFit.Cover)
          .borderRadius(10)
      }

      // 举报理由列表
      if (post.reports && post.reports.length > 0) {
        Column({ space: 6 }) {
          Text('举报理由')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          ForEach(
            post.reports,
            (r: ReportItem) => {
              Row({ space: 6 }) {
                this.reportReasonChip(r.reason ?? 'other', r.description)
                Text('— ' + (r.reporter?.nickname ?? '匿名'))
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            },
            (r: ReportItem) => 'r' + String(r.id ?? 0)
          )
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(10)
        .backgroundColor($r('app.color.bg_primary'))
        .borderRadius(10)
      }

      // 操作按钮
      Row({ space: 12 }) {
        Button('通过')
          .layoutWeight(1)
          .backgroundColor('#34C759')
          .fontColor('#FFFFFF')
          .enabled(this.processingId === 0 || this.processingId === (post.id ?? 0))
          .onClick(() => {
            this.doModerate(post.id ?? 0, 'approve');
          })
        Button('驳回')
          .layoutWeight(1)
          .backgroundColor($r('app.color.semantic_red'))
          .fontColor('#FFFFFF')
          .enabled(this.processingId === 0 || this.processingId === (post.id ?? 0))
          .onClick(() => {
            if (post.id !== undefined) {
              this.openReject(post.id);
            }
          })
      }
      .width('100%')
    }
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .width('100%')
  }

  @Builder
  loadingBuilder(): void {
    Row({ space: 8 }) {
      LoadingProgress().width(20).height(20)
      Text('刷新中…').fontSize(12).fontColor($r('app.color.text_secondary'))
    }
  }

  build() {
    Column() {
      // 顶栏：返回 + 标题 + 刷新
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor($r('app.color.text_primary'))
          .width(48)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })
        Text('内容审核')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('刷新')
          .fontSize(15)
          .fontColor($r('app.color.brand_primary'))
          .width(48)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            if (this.isRefreshing || this.loading) {
              return;
            }
            this.isRefreshing = true;
            this.load().finally(() => {
              this.isRefreshing = false;
            });
          })
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 })

      // 内容区
      if (this.loading && this.posts.length === 0) {
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
      } else if (this.forbidden) {
        Column() {
          Image(resolveActionIcon('lock'))
            .width(48)
            .height(48)
            .fillColor($r('app.color.text_secondary'))
          Text('无管理员权限')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 12 })
          Text('请联系管理员或检查登录账号')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.posts.length === 0) {
        Column() {
          Text(this.error ? ('加载失败：' + this.error) : '暂无待审核内容')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: this.isRefreshing, builder: this.loadingBuilder }) {
          List() {
            ForEach(
              this.posts,
              (post: PendingPost) => {
              ListItem() {
                this.postCard(post)
              }
              },
              (post: PendingPost) => 'p' + String(post.id ?? 0)
            )
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor($r('app.color.bg_primary'))
        }
        .onRefreshing(() => {
          this.isRefreshing = true;
          this.load().finally(() => {
            this.isRefreshing = false;
          });
        })
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .padding({ top: this.statusBarHeight })
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
}
