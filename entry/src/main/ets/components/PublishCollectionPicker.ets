// 发布页「加入合集」选择器：一行入口 + 展开的合集单选列表。
// 内联展开而非 bindSheet：发布页根组件已同时挂 bindSheet(圈子) 与 bindContentCover(AI/审稿)，
// 再加一个 bindSheet 会踩「同组件双模态」的平台规格坑。内联列表零模态冲突。
// 单选：一篇帖子同一时间只属一个合集（后端 CollectionPost.postId 唯一）。
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { Pressable } from '../design/motion/Pressable';
import { getUserId } from '../utils/auth';
import { listCollections } from '../services/api';
import { CollectionItem } from '../models/types';

@Component
export struct PublishCollectionPicker {
  @Link selectedId: number;
  @State private expanded: boolean = false;
  @State private items: CollectionItem[] = [];
  @State private loading: boolean = false;

  private async load(): Promise<void> {
    const uid: number = getUserId();
    if (uid <= 0) {
      return;
    }
    this.loading = true;
    try {
      this.items = (await listCollections(uid)).list;
    } catch (e) {
      this.items = [];
    } finally {
      this.loading = false;
    }
  }

  private selectedTitle(): string {
    for (let i: number = 0; i < this.items.length; i++) {
      if (this.items[i].id === this.selectedId) {
        return this.items[i].title;
      }
    }
    return '';
  }

  private toggle(id: number): void {
    this.selectedId = this.selectedId === id ? 0 : id;
    this.expanded = false;
  }

  @Builder
  private entryRow(): void {
    Row() {
      Pressable({
        visualHeight: LayoutTokens.segmentedHeight,
        action: (): void => {
          if (!this.expanded && this.items.length === 0 && !this.loading) {
            this.load();
          }
          this.expanded = !this.expanded;
        },
      }) {
        Row({ space: SpaceTokens.inlineTight }) {
          Text('加入合集')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.primary)
            .layoutWeight(1)
          Text(this.selectedTitle().length > 0 ? this.selectedTitle() : (this.loading ? '加载中…' : '不加入'))
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(this.selectedId > 0 ? ColorTokens.brand : ColorTokens.tertiary)
          Image($r('app.media.chevron_right'))
            .width(IconTokens.compact).height(IconTokens.compact)
            .fillColor(ColorTokens.tertiary)
        }
        .width('100%')
        .height(LayoutTokens.segmentedHeight)
      }
    }
  }

  @Builder
  private optionList(): void {
    Column({ space: 0 }) {
      ForEach(this.items, (item: CollectionItem) => {
        Pressable({
          visualHeight: LayoutTokens.segmentedHeight,
          action: (): void => { this.toggle(item.id); },
        }) {
          Row({ space: SpaceTokens.inlineTight }) {
            Text(item.title)
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(item.id === this.selectedId ? ColorTokens.brand : ColorTokens.primary)
              .layoutWeight(1)
            Text(item.postCount + ' 篇')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.tertiary)
            if (item.id === this.selectedId) {
              Image($r('app.media.check_round'))
                .width(IconTokens.compact).height(IconTokens.compact)
                .fillColor(ColorTokens.brand)
            }
          }
          .width('100%')
          .height(LayoutTokens.segmentedHeight)
        }
      }, (item: CollectionItem): string => 'collection_' + item.id)
      if (this.selectedId > 0) {
        Pressable({
          visualHeight: LayoutTokens.segmentedHeight,
          action: (): void => { this.toggle(this.selectedId); },
        }) {
          Text('不加入合集')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.tertiary)
            .width('100%')
            .height(LayoutTokens.segmentedHeight)
        }
      }
      if (this.items.length === 0 && !this.loading) {
        Pressable({
          visualHeight: LayoutTokens.segmentedHeight,
          action: (): void => { this.getUIContext().getRouter().pushUrl({ url: 'pages/CollectionPage' }); },
        }) {
          Row({ space: SpaceTokens.inlineTight }) {
            Text('还没有合集，先到「我的合集」创建一个')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.tertiary)
            Text('去创建 →')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.brand)
          }
          .width('100%')
          .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.sm })
        }
      }
    }
    .width('100%')
    .backgroundColor(ColorTokens.elevated)
    .borderRadius(RadiusTokens.md)
    .padding({ left: SpaceTokens.item, right: SpaceTokens.item })
  }

  build() {
    Column({ space: 0 }) {
      this.entryRow()
      if (this.expanded) {
        this.optionList()
      }
    }
    .width('100%')
  }
}
