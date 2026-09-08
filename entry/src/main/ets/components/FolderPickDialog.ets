// 收藏时选择收藏夹弹窗：未分类 + 已有收藏夹 + 新建收藏夹入口
import { SpringPanel } from '../design/motion/SpringPanel';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { Pressable } from '../design/motion/Pressable';
import { BookmarkFolderItem } from '../models/types';

interface FolderPickOption {
  id: number; // 0 = 未分类
  name: string;
  count: number;
}

@CustomDialog
export struct FolderPickDialog {
  controller: CustomDialogController;
  folders: BookmarkFolderItem[] = [];
  onPick: (folderId: number) => void = (_folderId: number): void => {};
  onNewFolder: () => void = (): void => {};

  private options(): FolderPickOption[] {
    const opts: FolderPickOption[] = [{ id: 0, name: '未分类', count: 0 }];
    for (const f of this.folders) {
      opts.push({ id: f.id, name: f.name, count: f.count });
    }
    return opts;
  }

  @Builder
  optionRow(opt: FolderPickOption) {
    Pressable({
      fillWidth: true,
      visualHeight: 48,
      touchTargetHeight: LayoutTokens.minTouchTarget,
      action: (): void => {
        this.controller.close();
        this.onPick(opt.id);
      },
    }) {
      Row({ space: SpaceTokens.sm }) {
        Column({ space: 2 }) {
          Text(opt.name)
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.primary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (opt.count > 0) {
            Text(opt.count + ' 条收藏')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Image(resolveActionIcon('bookmark'))
          .width(IconTokens.compact)
          .height(IconTokens.compact)
      }
      .width('100%')
      .height(48)
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
      .backgroundColor(ColorTokens.sunken)
      .border({ width: 0.5, color: ColorTokens.separator, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.md)
    }
  }

  build() {
    SpringPanel({ panelWidth: 344, panelPadding: SpaceTokens.lg }) {
      Column({ space: SpaceTokens.base }) {
        Row({ space: SpaceTokens.sm }) {
          Column({ space: 2 }) {
            Text('收藏到')
              .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
              .fontWeight(TypeTokens.headline.weight)
              .lineHeight(TypeTokens.headline.lineHeight)
              .fontColor(ColorTokens.primary)
            Text('选择收藏夹，可按分类整理')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.secondary)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Pressable({
            visualHeight: IconTokens.compact,
            touchTargetHeight: LayoutTokens.minTouchTarget,
            action: (): void => { this.controller.close(); },
          }) {
            Image(resolveActionIcon('close'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column({ space: SpaceTokens.xs }) {
          ForEach(this.options(), (opt: FolderPickOption) => {
            this.optionRow(opt)
          }, (opt: FolderPickOption) => String(opt.id))
        }
        .width('100%')

        Pressable({
          fillWidth: true,
          visualHeight: 48,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => {
            this.controller.close();
            this.onNewFolder();
          },
        }) {
          Row({ space: SpaceTokens.sm }) {
            Text('新建收藏夹')
              .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.headline.weight)
              .fontColor(ColorTokens.brand)
            Blank()
            Text('+')
              .fontSize(20).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.brand)
          }
          .width('100%')
          .height(48)
          .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm })
        }
      }
      .width('100%')
    }
  }
}
