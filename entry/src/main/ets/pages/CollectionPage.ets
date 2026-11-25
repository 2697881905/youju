// 合集（连载）管理页：创建/重命名/删除自己的合集，点击进入合集详情
// 顶栏驻留 HdsNavigation，返回键走官方 content.backIcon（40vp 玻璃圆，与详情页同一套栏级材质）。
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import type { HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { buildPageTitleBarOptions, GlassTitleRow, GlassBarInsetRow } from '../design/components/HdsGlassBackSurface';
import { EmptyState } from '../design/components/EmptyState';
import { resolveActionIcon } from '../utils/actionIcons';
import { listCollections, createCollection, updateCollection, deleteCollection, resolveDisplayImageUrl } from '../services/api';
import { CollectionItem } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { FolderNameDialog } from '../components/FolderNameDialog';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { getUserId } from '../utils/auth';
import { AppModalController } from '../utils/modal';
import { ComponentContent } from '@kit.ArkUI';

// 合集命名弹窗参数对象：ComponentContent 需要「全局 @Builder + class 参数」；editing 由
// openNameDialog 在 open 前写入（含局部变量 item——builder 体不可捕获方法局部变量）。
// 关闭走 closeCustomDialog(content) 同步可靠（不依赖 dialogId，2026-11-25 双层弹窗实锤）。
export class CollectionFolderNameDialogParams {
  editing: CollectionItem | null = null;
  onSubmit: (name: string) => void = (_n: string) => {};
  onClose: () => void = (): void => {};
}

@Builder
function collectionFolderNameDialogBuilder(p: CollectionFolderNameDialogParams) {
  FolderNameDialog({
    title: p.editing === null ? '新建合集' : '重命名合集',
    placeholder: '输入合集名称（最多 20 字）',
    initial: p.editing === null ? '' : p.editing.title,
    onSubmit: (name: string): void => {
      p.onSubmit(name);
    },
    onClose: (): void => {
      p.onClose();
    },
  })
}

@Entry
@Component
export struct CollectionPage {
  // 弹窗内容 @Builder：builder 闭包内联组件调用真机崩（class constructor without new，
  // 2026-11-25 实锤），统一改方法引用（同 Index.privacyConsentDialogBuilder 修复）。
  @State collections: CollectionItem[] = [];
  @State ready: boolean = false;
  @State error: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  private nameModal: AppModalController = new AppModalController();
  // 顶栏渐变模糊的滚动源
  private pageScroller: Scroller = new Scroller();
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
    this.nameModal.close();
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
    const params: CollectionFolderNameDialogParams = new CollectionFolderNameDialogParams();
    params.editing = item;
    params.onSubmit = (name: string): void => { this.onSubmitName(name); };
    params.onClose = (): void => { this.nameModal.close(); };
    const content: ComponentContent<CollectionFolderNameDialogParams> =
      new ComponentContent(this.getUIContext(), wrapBuilder(collectionFolderNameDialogBuilder), params);
    this.nameModal.openContent(this.getUIContext(), content, { onDismiss: (): void => { this.nameModal.close(); } });
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

  @Builder
  collectionRow(item: CollectionItem) {
    Row({ space: SpaceTokens.base }) {
      if (item.cover !== null && item.cover.image !== '') {
        Image(resolveDisplayImageUrl(item.cover.image))
          .width(56).height(56).borderRadius(RadiusTokens.md).objectFit(ImageFit.Cover)
      } else {
        Column() {
          Text('合集').fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        .width(56).height(56).borderRadius(RadiusTokens.md).backgroundColor(ColorTokens.sunken)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      }
      Column({ space: SpaceTokens.xs }) {
        Text(item.title)
          .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight).fontColor(ColorTokens.primary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.postCount + ' 篇 · ' + (item.description ?? '连载合集'))
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('⋯')
        .fontSize(18).fontFamily($r('app.string.font_family')).fontColor(ColorTokens.secondary)
        .width(32).textAlign(TextAlign.Center)
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
        });
    }
    .width('100%')
    .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
  }

  private collectionTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildPageTitleBarOptions({
      back: (): void => { this.getUIContext().getRouter().back(); },
      stackBuilder: (): void => { this.collectionTitleRow(); },
    });
  }

  @Builder
  collectionTitleRow(): void {
    GlassTitleRow({ title: '我的合集' });
  }

  build() {
    HdsNavigation() {
      Column() {
        if (!this.ready) {
          Column() {
            LoadingProgress().width(28).height(28);
            Text('加载中…').fontSize(13).fontFamily($r('app.string.font_family'))
              .fontColor($r('app.color.text_secondary')).margin({ top: 10 });
          }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
        } else if (this.collections.length === 0) {
          Column() {
            EmptyState({
              icon: this.error !== '' ? resolveActionIcon('warning') : $r('app.media.empty_inbox'),
              title: this.error !== '' ? '加载失败' : '还没有合集',
              message: this.error !== '' ? this.error : '把相关帖子编成连载，便于读者系统阅读',
              actionLabel: this.error !== '' ? '重试' : '',
              onAction: (): void => { this.load(); },
            })
          }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
        } else {
          List({ scroller: this.pageScroller }) {
            // 穿底让位：内容可画到标题栏下，顶部用「状态栏 + 栏高」空占位补回
            ListItem() {
              GlassBarInsetRow({ statusBarHeight: this.statusBarHeight })
            }

            ForEach(this.collections, (item: CollectionItem) => {
              ListItem() {
                Pressable({
                  fillWidth: true,
                  visualHeight: 72,
                  touchTargetHeight: LayoutTokens.minTouchTarget,
                  action: (): void => { this.openDetail(item); },
                }) {
                  this.collectionRow(item)
                }
              }
              .transition(
                TransitionEffect.OPACITY
                  .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate })
                  .combine(TransitionEffect.translate({ y: 16 })
                    .animation({ duration: MotionTokens.slow, curve: MotionCurves.decelerate }))
              )
            }, (item: CollectionItem) => String(item.id));
          }
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .layoutWeight(1).width('100%')
          .scrollBar(BarState.Off);
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
      .width('100%').height('100%');
    }
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .titleBar(this.collectionTitleBarOptions())
    .bindToScrollable([this.pageScroller])
    .clip(false)
    .width('100%').height('100%')
    .backgroundColor($r('app.color.bg_primary'));
  }
}
