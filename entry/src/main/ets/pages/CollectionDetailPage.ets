// 合集详情页：有序帖子目录；作者可加帖（从自己已发布帖子中选）与移除
import { BackButton } from '../design/components/BackButton';
import {
  getCollection, addPostToCollection, removePostFromCollection, listPosts,
} from '../services/api';
import { Post, CollectionDetail } from '../models/types';
import { openPostDetail } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { getUserId } from '../utils/auth';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Entry
@Component
export struct CollectionDetailPage {
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @State collectionId: number = 0;
  @State authorId: number = 0;
  @State title: string = '合集';
  @State detail: CollectionDetail | null = null;
  @State posts: Post[] = [];
  @State ready: boolean = false;
  @State error: string = '';
  // 加帖选择器：展开后列出我的已发布帖子，避免新增浮层/弹窗组件
  @State pickerVisible: boolean = false;
  @State pickCandidates: Post[] = [];
  @State pickLoading: boolean = false;

  aboutToAppear(): void {
    if (getUserId() === 0) {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    const params = this.getUIContext().getRouter().getParams() as Record<string, string> | undefined;
    this.collectionId = Number(params?.collectionId ?? 0);
    this.authorId = Number(params?.authorId ?? 0);
    this.title = params?.title ?? '合集';
    this.load();
  }

  get isOwner(): boolean {
    return this.authorId === getUserId();
  }

  private async load(): Promise<void> {
    if (!(this.collectionId > 0)) {
      this.ready = true;
      this.error = '合集参数缺失，请返回重新进入';
      return;
    }
    try {
      const res = await getCollection(this.collectionId, 1, 50);
      this.detail = res.collection;
      this.posts = res.list;
      this.authorId = res.collection.authorId;
      this.title = res.collection.title;
      this.ready = true;
    } catch (e) {
      this.error = (e as Error).message;
      this.ready = true;
    }
  }

  // 展开选择器时拉取我的已发布帖子（最多 50 条）
  private async openPicker(): Promise<void> {
    if (this.pickLoading) {
      return;
    }
    this.pickerVisible = true;
    this.pickLoading = true;
    try {
      const res = await listPosts({ page: 1, limit: 50, sort: 'latest', author: getUserId() });
      this.pickCandidates = res.list;
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.pickLoading = false;
    }
  }

  private async onAdd(post: Post): Promise<void> {
    if (!(post.id! > 0)) {
      return;
    }
    try {
      await addPostToCollection(this.collectionId, post.id!);
      this.pickerVisible = false;
      this.load();
      safeShowToast(this.getUIContext(), { message: '已加入合集' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  private confirmRemove(post: Post): void {
    this.getUIContext().showAlertDialog({
      title: '从合集移除？',
      message: '帖子本身不会被删除',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '移除',
        fontColor: $r('app.color.semantic_red'),
        action: async (): Promise<void> => {
          try {
            await removePostFromCollection(this.collectionId, post.id!);
            this.load();
            safeShowToast(this.getUIContext(), { message: '已移除' });
          } catch (e) {
            safeShowToast(this.getUIContext(), { message: (e as Error).message });
          }
        },
      },
    });
  }

  @Builder
  postRow(index: number, post: Post) {
    Row({ space: SpaceTokens.sm }) {
      Text(String(index + 1))
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.brand).width(24).textAlign(TextAlign.Center)
      Column({ space: SpaceTokens.xs }) {
        Text(post.title ?? '')
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.primary).maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (post.user !== undefined && post.user.nickname !== undefined) {
          Text(post.user.nickname)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => { openPostDetail(String(post.id ?? 0)); })
      if (this.isOwner) {
        Text('移除')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor($r('app.color.semantic_red'))
          .onClick(() => { this.confirmRemove(post); });
      }
    }
    .width('100%')
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
  }

  @Builder
  pickerPanel() {
    Column({ space: SpaceTokens.xs }) {
      Row() {
        Text('选择要加入的帖子')
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight).fontColor(ColorTokens.primary);
        Text('收起').fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.brand)
          .onClick(() => { this.pickerVisible = false; });
      }
      .width('100%').justifyContent(FlexAlign.SpaceBetween)
      if (this.pickLoading) {
        Text('加载中…').fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary);
      } else if (this.pickCandidates.length === 0) {
        Text('还没有已发布的帖子').fontSize(TypeTokens.caption.size)
          .fontFamily(TypeTokens.fontFamily).fontColor(ColorTokens.tertiary);
      } else {
        ForEach(this.pickCandidates, (post: Post) => {
          Row() {
            Text(post.title ?? '').fontSize(TypeTokens.caption.size)
              .fontFamily(TypeTokens.fontFamily).fontColor(ColorTokens.primary)
              .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('加入').fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.brand)
              .onClick(() => { this.onAdd(post); });
          }
          .width('100%').padding({ top: 6, bottom: 6 })
        }, (post: Post) => String(post.id));
      }
    }
    .width('100%')
    .padding(SpaceTokens.base)
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(RadiusTokens.md)
  }

  build() {
    Column() {
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Text(this.title)
          .fontSize(17).fontFamily($r('app.string.font_family')).fontWeight(600)
          .layoutWeight(1).textAlign(TextAlign.Center)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
        Text('').width(44);
      }
      .width('100%').padding({ top: this.statusBarHeight + 12, bottom: 8 });

      if (!this.ready) {
        Column() {
          LoadingProgress().width(28).height(28);
          Text('加载中…').fontSize(13).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary')).margin({ top: 10 });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else if (this.error !== '') {
        Column() {
          Text('加载失败：' + this.error).fontSize(14).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'));
          Button('重试').margin({ top: 12 }).onClick(() => { this.error = ''; this.load(); });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else {
        if (this.detail !== null && this.detail.description !== null) {
          Text(this.detail.description)
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary).width('100%')
            .padding({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: SpaceTokens.sm });
        }
        if (this.isOwner && this.pickerVisible) {
          Column() {
            this.pickerPanel()
          }
          .width('100%')
          .padding({ left: SpaceTokens.base, right: SpaceTokens.base, bottom: SpaceTokens.sm })
        }
        if (this.posts.length === 0) {
          Column() {
            Text('合集还是空的').fontSize(14).fontFamily($r('app.string.font_family'))
              .fontColor(ColorTokens.tertiary);
            if (this.isOwner) {
              Text('点下方「添加帖子」开始连载').fontSize(12)
                .fontFamily($r('app.string.font_family')).fontColor(ColorTokens.tertiary)
                .margin({ top: 6 });
            }
          }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
        } else {
          List() {
            ForEach(this.posts, (post: Post, index: number) => {
              ListItem() { this.postRow(index, post) }
            }, (post: Post) => String(post.id));
          }
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .layoutWeight(1).width('100%');
        }
        if (this.isOwner) {
          Button(this.pickerVisible ? '收起选择器' : '添加帖子')
            .width('calc(100% - 32vp)').height(44)
            .margin({ left: 16, right: 16, top: 8, bottom: 20 })
            .backgroundColor($r('app.color.ds_brand_solid'))
            .fontColor($r('app.color.ds_on_brand'))
            .borderRadius(22)
            .onClick(() => {
              if (this.pickerVisible) {
                this.pickerVisible = false;
              } else {
                this.openPicker();
              }
            });
        }
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.bg_primary'));
  }
}
