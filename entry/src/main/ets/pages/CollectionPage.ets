// 合集（连载）管理页：创建/重命名/删除自己的合集，点击进入合集详情
import { BackButton } from '../design/components/BackButton';
import { listCollections, createCollection, updateCollection, deleteCollection, resolveDisplayImageUrl } from '../services/api';
import { CollectionItem } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { FolderNameDialog } from '../components/FolderNameDialog';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { getUserId } from '../utils/auth';

@Entry
@Component
export struct CollectionPage {
  @State collections: CollectionItem[] = [];
  @State ready: boolean = false;
  @State error: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  private nameController: CustomDialogController | null = null;
  // 非 null 表示重命名，null 表示新建
  private editing: CollectionItem | null = null;

  aboutToAppear(): void {
    if (getUserId() === 0) {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.load();
  }

  aboutToDisappear(): void {
    this.nameController?.close();
  }

  private async load(): Promise<void> {
    this.ready = false;
    this.error = '';
    try {
      const res = await listCollections();
      this.collections = res.list;
      this.ready = true;
    } catch (e) {
      this.error = (e as Error).message;
      this.ready = true;
    }
  }

  private openNameDialog(item: CollectionItem | null): void {
    this.editing = item;
    this.nameController = new CustomDialogController({
      builder: FolderNameDialog({
        title: item === null ? '新建合集' : '重命名合集',
        placeholder: '输入合集名称（最多 20 字）',
        initial: item === null ? '' : item.title,
        onSubmit: (name: string): void => { this.onSubmitName(name); },
      }),
      autoCancel: true,
      customStyle: true,
    });
    this.nameController.open();
  }

  private async onSubmitName(name: string): Promise<void> {
    try {
      if (this.editing === null) {
        await createCollection(name, '');
        safeShowToast(this.getUIContext(), { message: '合集已创建，去详情页添加帖子' });
      } else {
        await updateCollection(this.editing.id, name, this.editing.description ?? '');
        safeShowToast(this.getUIContext(), { message: '已重命名' });
      }
      this.load();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  private confirmDelete(item: CollectionItem): void {
    this.getUIContext().showAlertDialog({
      title: '删除合集？',
      message: '合集内的帖子不会被删除，只是解除连载关系',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '确认删除',
        fontColor: $r('app.color.semantic_red'),
        action: async (): Promise<void> => {
          try {
            await deleteCollection(item.id);
            this.load();
            safeShowToast(this.getUIContext(), { message: '已删除合集' });
          } catch (e) {
            safeShowToast(this.getUIContext(), { message: (e as Error).message });
          }
        },
      },
    });
  }

  private openDetail(item: CollectionItem): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/CollectionDetailPage',
      params: { collectionId: String(item.id), title: item.title, authorId: String(item.authorId) },
    });
  }

  // 双列分列：与主页信息流同一套「按原始下标 % 列数」口径，首项固定左上角。
  private colItems(colIdx: number): CollectionItem[] {
    return this.collections.filter((_item: CollectionItem, idx: number): boolean => idx % 2 === colIdx);
  }

  @Builder
  collectionCard(item: CollectionItem) {
    Pressable({
      fillWidth: true,
      fullResponseRegion: true,
      action: (): void => { this.openDetail(item); },
    }) {
      Column({ space: SpaceTokens.none }) {
        // 3:4 封面（与主页帖子卡同一比例/裁切），无封面用「合集」占位。
        if (item.cover !== null && item.cover.image !== '') {
          Image(resolveDisplayImageUrl(item.cover.image))
            .width('100%')
            .aspectRatio(LayoutTokens.cardMediaAspectRatio)
            .objectFit(ImageFit.Cover)
            .backgroundColor(ColorTokens.sunken)
            .draggable(false)
            .borderRadius({ topLeft: RadiusTokens.xs, topRight: RadiusTokens.xs, bottomLeft: 0, bottomRight: 0 })
            .clip(true)
        } else {
          Column() {
            Text('合集')
              .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
          }
          .width('100%')
          .aspectRatio(LayoutTokens.cardMediaAspectRatio)
          .backgroundColor(ColorTokens.sunken)
          .borderRadius({ topLeft: RadiusTokens.xs, topRight: RadiusTokens.xs, bottomLeft: 0, bottomRight: 0 })
          .justifyContent(FlexAlign.Center)
          .clip(true)
        }
        // 信息区：标题 + 篇数/描述，同一块 elevated 底（与帖子卡信息区一致）。
        Column({ space: SpaceTokens.inlineTight }) {
          Row() {
            Text(item.title)
              .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight).fontColor(ColorTokens.primary)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text('⋯')
              .fontSize(18).fontFamily(TypeTokens.fontFamily).fontColor(ColorTokens.secondary)
              .width(24).textAlign(TextAlign.Center)
              .onClick(() => {
                this.getUIContext().showAlertDialog({
                  title: '合集操作',
                  message: '',
                  primaryButton: { value: '重命名', action: (): void => { this.openNameDialog(item); } },
                  secondaryButton: {
                    value: '删除合集',
                    fontColor: $r('app.color.semantic_red'),
                    action: (): void => { this.confirmDelete(item); },
                  },
                });
              })
          }
          .width('100%')
          Text(item.postCount + ' 篇 · ' + (item.description ?? '连载合集'))
            .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .padding(SpaceTokens.xs)
        .width('100%')
      }
      .width('100%')
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.xs)
      .clip(true)
    }
  }

  build() {
    Column() {
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Text('我的合集')
          .fontSize(17).fontFamily($r('app.string.font_family')).fontWeight(600)
          .layoutWeight(1).textAlign(TextAlign.Center);
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
      } else if (this.collections.length === 0) {
        Column({ space: 12 }) {
          Text(this.error !== '' ? ('加载失败：' + this.error) : '还没有合集\n把相关帖子编成连载，便于读者系统阅读')
            .fontSize(14).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center);
          if (this.error !== '') {
            Button('重试').onClick(() => { this.load(); });
          }
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else {
        // 双列瀑布流（与主页信息流同一套结构）：Scroll > Row > 每列一个 Column，按原始下标 %2 分列。
        Scroll() {
          Column({ space: SpaceTokens.xs }) {
            Row({ space: SpaceTokens.xs }) {
              ForEach([0, 1], (colIdx: number) => {
                Column({ space: SpaceTokens.xs }) {
                  ForEach(this.colItems(colIdx), (item: CollectionItem) => {
                    this.collectionCard(item)
                  }, (item: CollectionItem) => String(item.id))
                }
                .layoutWeight(1)
              }, (colIdx: number) => String(colIdx))
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }
          .width('100%')
          // 撑满视口：否则内容不足一屏时 Scroll 会把卡片垂直居中（顶部留大片空白）。
          .constraintSize({ minHeight: '100%' })
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.md })
        }
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollable(ScrollDirection.Vertical)
        .layoutWeight(1).width('100%');
      }

      Button('新建合集')
        .width('calc(100% - 32vp)')
        .height(44)
        .margin({ left: 16, right: 16, top: 8, bottom: 20 })
        .backgroundColor($r('app.color.ds_brand_solid'))
        .fontColor($r('app.color.ds_on_brand'))
        .borderRadius(22)
        .onClick(() => { this.openNameDialog(null); });
    }
    .width('100%').height('100%').backgroundColor($r('app.color.bg_primary'));
  }
}
