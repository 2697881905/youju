import { Post, User } from '../models/types';
import { formatCount } from '../utils/format';

import { upPost, cancelUpPost } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { resolveActionIcon } from '../utils/actionIcons';
import { likeStore } from '../utils/likeStore';
import { CARD_RADIUS, CARD_PADDING, CARD_COVER_RADIUS, CARD_SHADOW, CARD_INNER_GAP } from '../utils/cardTokens';

@Component
export struct PostCard {
  @Prop post: Post = {};

  onCancelBookmark?: (id: number) => void = undefined;

  @State liked: boolean = false;
  @State likeCount: number = 0;
  private unsubLike: () => void = () => {};

  aboutToAppear(): void {
    const id: number | undefined = this.post.id;
    if (id !== undefined) {
      // 从全局点赞仓库注册并读取（保证与详情页/个人主页同帖一致）
      likeStore.ensure(id, this.post.myUp ?? false, this.post.upCount ?? 0);
      const info = likeStore.get(id);
      if (info) {
        this.liked = info.liked;
        this.likeCount = info.count;
      }
      // 订阅该帖点赞态变化：首页点赞后，详情/个人主页的同帖会即时同步
      this.unsubLike = likeStore.subscribe((changedId: number): void => {
        if (changedId === id) {
          const i = likeStore.get(changedId);
          if (i) {
            this.liked = i.liked;
            this.likeCount = i.count;
          }
        }
      });
    } else {
      this.liked = this.post.myUp ?? false;
      this.likeCount = this.post.upCount ?? 0;
    }
  }

  aboutToDisappear(): void {
    this.unsubLike();
  }

  private isDeletedUser(): boolean {
    const u = this.post.user;
    if (u === undefined) {
      return false;
    }
    if (u.deleted === true) {
      return true;
    }
    if (u.nickname === '已注销用户') {
      return true;
    }
    return false;
  }

  private goUser(): void {
    const u: User | undefined = this.post.user;
    if (this.isDeletedUser()) {
      return;
    }
    if (u !== undefined && u.id !== undefined) {
      AppStorage.setOrCreate('targetUserId', String(u.id));
      this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
    }
  }

  async onLike(): Promise<void> {
    const id: number | undefined = this.post.id;
    if (id === undefined) {
      return;
    }
    const willLike: boolean = !this.liked;
    // 乐观更新写入全局仓库（同步广播到所有展示该帖的组件，含本卡片）
    const prev = likeStore.applyOptimistic(id, willLike);
    try {
      if (willLike) {
        await upPost(id);
      } else {
        await cancelUpPost(id);
      }
    } catch (e) {
      likeStore.revert(id, prev);
      safeShowToast(this.getUIContext(), { message: '操作失败，请先登录' });
    }
  }

  build() {
    Column() {
      // 封面图 — Apple 风格大圆角；用 aspectRatio 替代固定高度，宽度自适应避免不同列数下溢出/比例失调
      if (this.post.coverImage) {
        Image(this.post.coverImage)
          .width('100%')
          .aspectRatio(1.2)
          .objectFit(ImageFit.Cover)
          .borderRadius(CARD_COVER_RADIUS)
          .margin({ bottom: CARD_INNER_GAP })
      }

      // 标题 — iOS 17pt Medium 风格
      Text(this.post.title ?? '')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(22)

      // 投票/对比内容预览 — 填充无图卡片空间，同时让用户一眼看到选项
      if (this.post.structuredData !== undefined &&
          (this.post.structuredData.planA !== undefined || this.post.structuredData.planB !== undefined)) {
        Column({ space: 6 }) {
          if (this.post.structuredData.planA !== undefined) {
            Row({ space: 8 }) {
              Text('A')
                .width(20).height(20).borderRadius(10)
                .fontSize(11).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
                .backgroundColor($r('app.color.brand_primary'))
                .textAlign(TextAlign.Center)
              Text(this.post.structuredData.planA)
                .fontSize(13)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
          }
          if (this.post.structuredData.planB !== undefined) {
            Row({ space: 8 }) {
              Text('B')
                .width(20).height(20).borderRadius(10)
                .fontSize(11).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
                .backgroundColor($r('app.color.semantic_orange'))
                .textAlign(TextAlign.Center)
              Text(this.post.structuredData.planB)
                .fontSize(13)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding(10)
        .backgroundColor($r('app.color.bg_secondary'))
        .borderRadius(8)
        .margin({ top: 8 })
      }

      // 作者区
      if (this.post.user !== undefined && this.post.user.id !== undefined) {
        Row({ space: 8 }) {
          if (this.isDeletedUser()) {
            Text('?')
              .width(22).height(22).borderRadius(11)
              .fontSize(12).fontColor('#FFFFFF')
              .backgroundColor('#3A3A3C')
              .textAlign(TextAlign.Center)
          } else if (this.post.user.avatar) {
            Image(this.post.user.avatar)
              .width(22).height(22).borderRadius(11)
              .objectFit(ImageFit.Cover)
          } else {
            Text((this.post.user.nickname ?? '?').charAt(0))
              .width(22).height(22).borderRadius(11)
              .fontSize(12).fontColor('#FFFFFF')
              .backgroundColor($r('app.color.brand_primary'))
              .textAlign(TextAlign.Center)
          }
          Text(this.isDeletedUser() ? '已注销用户' : (this.post.user.nickname ?? '匿名'))
            .fontSize(13).fontColor($r('app.color.text_secondary'))
        }
        .margin({ top: CARD_INNER_GAP })
        .onClick(() => {
          this.goUser();
        })
      }

      // 底部互动行
      Row() {
        Row({ space: 4 }) {
          Image(resolveActionIcon('like'))
            .width(15)
            .height(15)
            .fillColor(this.liked ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
          Text('顶 ' + formatCount(this.likeCount))
            .fontSize(13)
            .fontColor(this.liked ? $r('app.color.brand_primary') : $r('app.color.text_secondary'));
        }
        .onClick(() => {
          this.onLike();
        })

        Row({ space: 4 }) {
          Image(resolveActionIcon('comment'))
            .width(15)
            .height(15)
            .fillColor($r('app.color.text_secondary'))
          Text(formatCount(this.post.commentCount))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .margin({ left: 16 });
      }
      .margin({ top: CARD_INNER_GAP })
      .justifyContent(FlexAlign.Start);

      if (this.onCancelBookmark !== undefined) {
        Row() {
          Text('取消收藏')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'));
        }
        .margin({ top: CARD_INNER_GAP })
        .onClick(() => {
          if (this.post.id !== undefined) {
            this.onCancelBookmark!(this.post.id);
          }
        });
      }
    }
    .width('100%')
    .padding(CARD_PADDING)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(CARD_RADIUS)
    // Apple 卡片阴影 — 浅色模式深灰投影，深色模式淡化（统一令牌）
    .shadow(CARD_SHADOW)
    .stateStyles({
      normal: {
        .opacity(1)
      },
      pressed: {
        .opacity(0.92)
        .scale({ x: 0.985, y: 0.985 })
      }
    });
  }
}