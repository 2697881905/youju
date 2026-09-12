// 收藏夹（专辑）管理页：创建/重命名/删除收藏夹，点击进入夹内帖子列表
import { BackButton } from '../design/components/BackButton';
import { listBookmarkFolders, createBookmarkFolder, renameBookmarkFolder, deleteBookmarkFolder, resolveDisplayImageUrl } from '../services/api';
import { BookmarkFolderItem } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { FolderNameDialog } from '../components/FolderNameDialog';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Entry
@Component
export struct BookmarkFolderPage {
  @State folders: BookmarkFolderItem[] = [];
  @State ready: boolean = false;
  @State error: string = '';
  @State editingFolder: BookmarkFolderItem | null = null;

  private createController: CustomDialogController | null = null;
  private renameController: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.load();
  }

  aboutToDisappear(): void {
    this.createController?.close();
    this.renameController?.close();
  }

  private async load(): Promise<void> {
    this.ready = false;
    this.error = '';
    try {
      const list = await listBookmarkFolders();
      this.folders = list;
      this.ready = true;
    } catch (e) {
      this.error = (e as Error).message;
      this.ready = true;
    }
  }

  // 新建：弹命名窗
  private openCreate(): void {
    this.editingFolder = null;
    this.createController = new CustomDialogController({
      builder: FolderNameDialog({
        title: '新建收藏夹',
        placeholder: '输入收藏夹名称（最多 20 字）',
        onSubmit: (name: string): void => { this.onCreate(name); },
      }),
      autoCancel: true,
      customStyle: true,
    });
    this.createController.open();
  }

  private async onCreate(name: string): Promise<void> {
    try {
      await createBookmarkFolder(name);
      this.load();
      safeShowToast(this.getUIContext(), { message: '已创建收藏夹' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  // 重命名：弹命名窗（带初始值）
  private openRename(item: BookmarkFolderItem): void {
    this.editingFolder = item;
    this.renameController = new CustomDialogController({
      builder: FolderNameDialog({
        title: '重命名收藏夹',
        placeholder: '输入收藏夹名称（最多 20 字）',
        initial: item.name,
        onSubmit: (name: string): void => { this.onRename(item, name); },
      }),
      autoCancel: true,
      customStyle: true,
    });
    this.renameController.open();
  }

  private async onRename(item: BookmarkFolderItem, name: string): Promise<void> {
    try {
      await renameBookmarkFolder(item.id, name);
      this.load();
      safeShowToast(this.getUIContext(), { message: '已重命名' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  // 删除：二次确认 → 调 API → 刷新
  private confirmDelete(item: BookmarkFolderItem): void {
    this.getUIContext().showAlertDialog({
      title: '删除收藏夹？',
      message: '删除后其中的收藏会移入「未分类」，不会丢失',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '确认删除',
        fontColor: $r('app.color.semantic_red'),
        action: async (): Promise<void> => {
          try {
            await deleteBookmarkFolder(item.id);
            this.load();
            safeShowToast(this.getUIContext(), { message: '已删除收藏夹' });
          } catch (e) {
            safeShowToast(this.getUIContext(), { message: (e as Error).message });
          }
        },
      },
    });
  }

  // 夹内列表
  private openFolder(item: BookmarkFolderItem): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/BookmarkFolderDetailPage',
      params: { folderId: String(item.id), folderName: item.name },
    });
  }

  @Builder
  folderRow(item: BookmarkFolderItem) {
    Row({ space: SpaceTokens.base }) {
      if (item.cover !== null && item.cover.image !== '') {
        Image(resolveDisplayImageUrl(item.cover.image))
          .width(56).height(56).borderRadius(RadiusTokens.md).objectFit(ImageFit.Cover)
      } else {
        Column() {
          Text(item.cover !== null && item.cover.genre !== '' ? item.cover.genre : '收藏')
            .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        .width(56).height(56).borderRadius(RadiusTokens.md).backgroundColor(ColorTokens.sunken)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      }
      Column({ space: SpaceTokens.xs }) {
        Text(item.name)
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.primary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.count + ' 条收藏')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 操作：重命名 / 删除
      Text('⋯')
        .fontSize(18).fontFamily($r('app.string.font_family')).fontColor(ColorTokens.secondary)
        .width(32).textAlign(TextAlign.Center)
        .onClick(() => {
          this.getUIContext().showAlertDialog({
            title: '操作',
            message: '',
            primaryButton: { value: '重命名', action: (): void => { this.openRename(item); } },
            secondaryButton: {
              value: '删除收藏夹',
              fontColor: $r('app.color.semantic_red'),
              action: (): void => { this.confirmDelete(item); },
            },
          });
        });
    }
    .width('100%')
    .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
  }

  build() {
    Column() {
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Text('收藏夹')
          .fontSize(17).fontFamily($r('app.string.font_family')).fontWeight(600).layoutWeight(1).textAlign(TextAlign.Center);
        Text('').width(44);
      }
      .width('100%').padding({ top: 12, bottom: 8 });

      if (!this.ready) {
        Column() {
          LoadingProgress().width(28).height(28);
          Text('加载中…').fontSize(13).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary')).margin({ top: 10 });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else if (this.folders.length === 0) {
        Column({ space: 12 }) {
          Text(this.error !== '' ? ('加载失败：' + this.error) : '还没有收藏夹\n收藏帖子时可选分类归入')
            .fontSize(14).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center);
          if (this.error !== '') {
            Button('重试').onClick(() => { this.load(); });
          }
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else {
        List() {
          ForEach(this.folders, (item: BookmarkFolderItem) => {
            ListItem() {
              Pressable({
                fillWidth: true,
                visualHeight: 72,
                touchTargetHeight: LayoutTokens.minTouchTarget,
                action: (): void => { this.openFolder(item); },
              }) {
                this.folderRow(item)
              }
            }
            // 列表项出现/消失过渡：ForEach key 稳定，仅被删项单独退场，其余项不重播
            .transition(
              TransitionEffect.OPACITY
                .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate })
                .combine(TransitionEffect.translate({ y: 16 })
                  .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate }))
            )
          }, (item: BookmarkFolderItem) => String(item.id));
        }
        .layoutWeight(1).width('100%');
      }

      // 底部新建按钮
      Button('新建收藏夹')
        .width('calc(100% - 32vp)')
        .height(44)
        .margin({ left: 16, right: 16, top: 8, bottom: 20 })
        .backgroundColor($r('app.color.brand_primary'))
        .fontColor(Color.White)
        .borderRadius(22)
        .onClick(() => { this.openCreate(); });
    }
    .width('100%').height('100%').backgroundColor($r('app.color.bg_primary'));
  }
}
