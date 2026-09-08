// 收藏夹内帖子列表页：分页展示夹内收藏的帖子（复用 PostCard 网格），支持取消收藏 / 移入其他收藏夹
import { BackButton } from '../design/components/BackButton';
import { listFolderPosts, cancelBookmarkPost, listBookmarkFolders, createBookmarkFolder, moveBookmarkFolder, resolveDisplayImageUrl } from '../services/api';
import { Post, BookmarkFolderItem } from '../models/types';
import { PostCard } from '../components/PostCard';
import { openPostDetail } from '../utils/nav';
import { safeShowToast } from '../utils/toast';
import { FolderPickDialog } from '../components/FolderPickDialog';
import { FolderNameDialog } from '../components/FolderNameDialog';

@Entry
@Component
export struct BookmarkFolderDetailPage {
  // 独立 @Entry 页无主框架顶部安全区：读全局状态栏高度，标题栏避让不顶到屏幕外
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @State folderId: number = 0;
  @State folderName: string = '';
  @State posts: Post[] = [];
  @State page: number = 1;
  @State loading: boolean = false;
  @State finished: boolean = false;
  @State ready: boolean = false;
  @State error: string = '';
  @State moveFolders: BookmarkFolderItem[] = [];
  private moveTarget: Post | null = null;
  private movePickController: CustomDialogController | null = null;
  private moveNameDialog: CustomDialogController | null = null;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as Record<string, string> | undefined;
    this.folderId = Number(params?.folderId ?? 0);
    this.folderName = params?.folderName ?? '收藏夹';
    if (this.folderId > 0) {
      this.load(true);
    }
  }

  private async load(reset: boolean): Promise<void> {
    if (!reset && (this.loading || this.finished)) {
      return;
    }
    this.loading = true;
    if (reset) {
      this.page = 1;
      this.finished = false;
      this.posts = [];
    }
    try {
      const res = await listFolderPosts(this.folderId, this.page, 20);
      if (reset) {
        this.posts = res.list;
      } else {
        this.posts = this.posts.concat(res.list);
      }
      if (res.list.length < 20) {
        this.finished = true;
      }
      this.page += 1;
      this.ready = true;
      this.error = '';
    } catch (e) {
      this.error = (e as Error).message;
      this.ready = true;
    } finally {
      this.loading = false;
    }
  }

  private onReachEnd(): void {
    this.load(false);
  }

  private goDetail(p: Post): void {
    if (p.id !== undefined) {
      openPostDetail(String(p.id));
      this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
    }
  }

  // 取消收藏：从列表移除
  private onUnbookmark(p: Post): void {
    if (p.id === undefined) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '取消收藏？',
      message: '取消后该帖将从当前收藏夹移除',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '确认取消',
        fontColor: $r('app.color.semantic_red'),
        action: async (): Promise<void> => {
          try {
            await cancelBookmarkPost(p.id ?? 0);
            const idx: number = this.posts.indexOf(p);
            if (idx >= 0) {
              this.posts.splice(idx, 1);
            }
            safeShowToast(this.getUIContext(), { message: '已取消收藏' });
          } catch (e) {
            safeShowToast(this.getUIContext(), { message: (e as Error).message });
          }
        },
      },
    });
  }

  // 移入其他收藏夹：加载收藏夹列表 → 弹选择弹窗（排除当前夹）
  private async onMoveTo(p: Post): Promise<void> {
    if (p.id === undefined) {
      return;
    }
    this.moveTarget = p;
    try {
      const folders = await listBookmarkFolders();
      this.moveFolders = folders;
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '收藏夹加载失败，请稍后重试' });
      return;
    }
    this.movePickController = new CustomDialogController({
      builder: FolderPickDialog({
        folders: this.moveFolders,
        onPick: (folderId: number): void => { this.onMovePick(folderId); },
        onNewFolder: (): void => { this.openMoveNewFolder(); },
      }),
      autoCancel: true,
      customStyle: true,
    });
    this.movePickController.open();
  }

  // 选择目标夹：folderId=0 移出收藏夹；=当前夹 则无变化
  private async onMovePick(folderId: number): Promise<void> {
    const target = this.moveTarget;
    if (target === null || target.id === undefined) {
      return;
    }
    if (folderId === this.folderId) {
      safeShowToast(this.getUIContext(), { message: '已在当前收藏夹' });
      return;
    }
    if (folderId > 0) {
      // 目标夹已存在：仅允许移动到其他收藏夹，移出收藏夹走 folderId=0
      await this.move(target.id, folderId);
    } else {
      await this.move(target.id, 0);
    }
  }

  private async move(postId: number, folderId: number): Promise<void> {
    try {
      await moveBookmarkFolder(postId, folderId);
      const target = this.moveTarget;
      if (target !== null) {
        const idx: number = this.posts.indexOf(target);
        if (idx >= 0) {
          this.posts.splice(idx, 1);
        }
      }
      safeShowToast(this.getUIContext(), { message: folderId > 0 ? '已移入收藏夹' : '已移出收藏夹' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.moveTarget = null;
    }
  }

  // 新建收藏夹并移入
  private openMoveNewFolder(): void {
    this.moveNameDialog = new CustomDialogController({
      builder: FolderNameDialog({
        title: '新建收藏夹',
        onSubmit: (name: string): void => { this.onCreateMoveFolder(name); },
      }),
      autoCancel: true,
      customStyle: true,
    });
    this.moveNameDialog.open();
  }

  private async onCreateMoveFolder(name: string): Promise<void> {
    const target = this.moveTarget;
    if (target === null || target.id === undefined) {
      return;
    }
    try {
      const folder = await createBookmarkFolder(name);
      await moveBookmarkFolder(target.id, folder.id);
      const idx: number = this.posts.indexOf(target);
      if (idx >= 0) {
        this.posts.splice(idx, 1);
      }
      safeShowToast(this.getUIContext(), { message: '已移入新收藏夹' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.moveTarget = null;
    }
  }

  // 夹内帖子卡片 + 操作行（移动到… / 取消收藏），双列卡片流
  @Builder
  folderPostCard(p: Post) {
    Column({ space: 6 }) {
      PostCard({
        post: p,
        compact: true,
        onOpen: (): void => { this.goDetail(p); },
      })
      Row({ space: 16 }) {
        Text('移动到…')
          .fontSize(12).fontFamily($r('app.string.font_family')).fontColor($r('app.color.brand_primary'))
          .onClick(() => { this.onMoveTo(p); });
        Text('取消收藏')
          .fontSize(12).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary'))
          .onClick(() => { this.onUnbookmark(p); });
      }
      .width('100%').padding({ left: 4 });
    }
    .width('100%')
  }

  build() {
    Column() {
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Text(this.folderName)
          .fontSize(17).fontFamily($r('app.string.font_family')).fontWeight(600).layoutWeight(1).textAlign(TextAlign.Center).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
        Text('').width(44);
      }
      .width('100%')
      .padding({ top: this.statusBarHeight + 12, bottom: 8 });

      if (!this.ready) {
        Column() {
          LoadingProgress().width(28).height(28);
          Text('加载中…').fontSize(13).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary')).margin({ top: 10 });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else if (this.posts.length === 0) {
        Column({ space: 12 }) {
          Text(this.error !== '' ? ('加载失败：' + this.error) : '这个收藏夹还是空的')
            .fontSize(14).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center);
          if (this.error !== '') {
            Button('重试').onClick(() => { this.load(true); });
          }
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else {
        // 双列卡片流：偶数项固定左列、奇数项固定右列（与个人主页帖子网格一致的瀑布流效果）
        Scroll() {
          Column() {
            Row({ space: 6 }) {
              Column({ space: 8 }) {
                ForEach(this.posts.filter((_p: Post, idx: number) => idx % 2 === 0), (p: Post) => {
                  this.folderPostCard(p)
                }, (p: Post) => 'left-' + String(p.id))
              }
              .layoutWeight(1)
              Column({ space: 8 }) {
                ForEach(this.posts.filter((_p: Post, idx: number) => idx % 2 === 1), (p: Post) => {
                  this.folderPostCard(p)
                }, (p: Post) => 'right-' + String(p.id))
              }
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            if (!this.finished) {
              Row({ space: 8 }) {
                LoadingProgress().width(20).height(20);
                Text('加载更多…').fontSize(12).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary'));
              }
              .width('100%').justifyContent(FlexAlign.Center).padding({ top: 8, bottom: 8 });
            }
            Column() {
              Blank().width('100%').height(24)
            }
            .width('100%')
          }
          .width('100%')
          // constraintSize minHeight 撑满视口：内容不足一屏时从顶部贴齐（规避 Scroll 内容垂直居中）
          .constraintSize({ minHeight: '100%' })
          .padding({ left: 6, right: 6, top: 4, bottom: 8 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollable(ScrollDirection.Vertical)
        .onScrollEdge((edge: Edge) => {
          if (edge === Edge.Bottom) {
            this.onReachEnd();
          }
        })
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.bg_primary'));
  }
}
