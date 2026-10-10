// 图片选择器 + 腾讯云 COS 直传：
// PhotoViewPicker 拉相册 → 压缩(jpeg) → 调 getUploadSignature 拿预签名 PUT URL → 直传二进制。
// 本地用 PixelMap 即时预览；直传成功后把远端 URL 写入 @Link selected（供发布器提交）。
// 多图场景下支持长按单张图片拖拽排序：Grid 进入编辑模式后长按拖动即可调整图片顺序。
import { photoAccessHelper } from '@kit.MediaLibraryKit';

import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { compressImage, CompressedImage } from '../utils/image';
import { getUploadSignature, resolveDisplayImageUrl, resolveUploadPutUrl, toStoredMediaRef } from '../services/api';
import { ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { User } from '../models/types';

interface PickedImage {
  id: string; // 稳定 key
  preview?: image.PixelMap; // 当次选择的本地预览；恢复草稿时使用 remoteUrl
  remoteUrl?: string; // 直传成功后的可访问 URL
  uploading: boolean; // 是否上传中（用于显示 loading）
}

@Component
export struct ImagePicker {
  @Link @Watch('onSelectedChange') selected: string[]; // 远端 URL 列表（发布用）
  @Prop maxCount: number = 9;
  @Prop @Watch('onPickerRequestChanged') pickerRequest: number = 0;
  @Prop autoOpen: boolean = false;
  @State items: PickedImage[] = []; // 本地预览 + 上传态（与 selected 同序）
  @State picking: boolean = false;
  private pickSeq: number = 0;
  // 拖拽排序：当前被长按拖起的图片下标（-1 表示未拖拽）。
  private dragIndex: number = -1;
  // 拖拽悬停到的目标格子下标，用于实时高亮落点（-1 表示无）。
  @State dragTargetIndex: number = -1;
  // 重排守卫：moveItem 改写 selected 会触发 @Watch，置位后跳过重建，避免打乱刚排好的顺序与本地预览闪烁。
  private reordering: boolean = false;

  // 外部恢复草稿时，按已保存的 URL 补建远程预览项；避免编辑草稿时图片丢失。
  private onSelectedChange(): void {
    if (this.reordering) {
      return;
    }
    if (this.selected.length === 0) {
      this.items = [];
      return;
    }
    let next: PickedImage[] = this.items.filter((item: PickedImage): boolean => {
      return item.remoteUrl === undefined || this.selected.indexOf(item.remoteUrl) >= 0;
    });
    for (const url of this.selected) {
      let found: boolean = false;
      for (const item of next) {
        if (item.remoteUrl === url) {
          found = true;
          break;
        }
      }
      if (!found) {
        next = [...next, { id: 'remote_' + url, remoteUrl: url, uploading: false }];
      }
    }
    this.items = next;
  }

  aboutToAppear(): void {
    this.onSelectedChange();
    if (this.autoOpen && this.pickerRequest > 0) {
      this.pick();
    }
  }

  private onPickerRequestChanged(): void {
    if (this.pickerRequest > 0) {
      this.pick();
    }
  }

  // 直传二进制到预签名 URL
  private putBinary(url: string, data: ArrayBuffer, contentType: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const req = http.createHttp();
      const header: Record<string, string> = { 'Content-Type': contentType };
      req.request(
        url,
        {
          method: http.RequestMethod.PUT,
          header: header,
          extraData: data,
          connectTimeout: 30000,
          readTimeout: 30000,
        },
        (err: Error | null, resp: http.HttpResponse) => {
          req.destroy();
          if (err) {
            reject(err);
            return;
          }
          if (resp.responseCode >= 200 && resp.responseCode < 300) {
            resolve();
          } else {
            reject(new Error('上传失败 HTTP ' + resp.responseCode));
          }
        }
      );
    });
  }

  private async pick(): Promise<void> {
    if (this.picking) {
      return;
    }
    this.picking = true;
    // 先确保登录（上传接口需 Bearer token），失败则提示并返回
    try {
      const u: User | null = await ensureLogin();
      if (!u) {
        this.picking = false;
        return;
      }
    } catch (e) {
      safeShowToast(this.getUIContext(),{ message: '登录失败，无法上传：' + (e as Error).message });
      this.picking = false;
      return;
    }
    try {
      const ph = new photoAccessHelper.PhotoViewPicker();
      const res = await ph.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: this.maxCount - this.items.length,
      });
      const uris: string[] = res.photoUris ?? [];
      for (const u of uris) {
        if (this.items.length >= this.maxCount) {
          break;
        }
        const compressed: CompressedImage = await compressImage(u);
        const preview: image.PixelMap = compressed.preview;
        const bytes: ArrayBuffer = compressed.bytes;
        const item: PickedImage = { id: 'img_' + this.pickSeq++, preview, uploading: true };
        this.items = [...this.items, item];
        try {
          const sig = await getUploadSignature('image/jpeg', 'posts');
          await this.putBinary(resolveUploadPutUrl(sig), bytes, sig.contentType);
          item.remoteUrl = sig.viewUrl;
          item.uploading = false;
          this.items = [...this.items];
          this.selected = [...this.selected, toStoredMediaRef(sig)];
        } catch (e) {
          // 上传失败：移除该预览，提示用户
          this.items = this.items.filter((it) => it !== item);
          safeShowToast(this.getUIContext(),{ message: '图片上传失败：' + (e as Error).message });
        }
      }
    } catch (e) {
      // 用户取消选择会抛错，忽略
    } finally {
      this.picking = false;
    }
  }

  private removeAt(idx: number): void {
    this.items = this.items.filter((_v: PickedImage, i: number) => i !== idx);
    this.selected = this.selected.filter((_v: string, i: number) => i !== idx);
  }

  // 把落点下标收敛到合法范围：拖到「+ 添加」格（insertIndex == items.length）视为移到末尾，越界则就近吸附。
  private clampTargetIndex(insertIndex: number): number {
    const last: number = this.items.length - 1;
    if (insertIndex < 0) {
      return 0;
    }
    if (insertIndex > last) {
      return last;
    }
    return insertIndex;
  }

  // 长按拖拽后重排：items（本地预览）与 selected（发布用的远端引用）同序，必须一起搬移。
  // 先写 items 再写 selected —— selected 的 @Watch 在 reordering 守卫下跳过重建，保留本地预览不闪烁。
  private moveItem(from: number, to: number): void {
    const count: number = this.items.length;
    if (from === to || from < 0 || to < 0 || from >= count || to >= count) {
      return;
    }
    const nextItems: PickedImage[] = this.items.slice();
    const movedItem: PickedImage = nextItems[from];
    nextItems.splice(from, 1);
    nextItems.splice(to, 0, movedItem);
    const nextSelected: string[] = this.selected.slice();
    const movedRef: string = nextSelected[from];
    nextSelected.splice(from, 1);
    nextSelected.splice(to, 0, movedRef);
    this.reordering = true;
    this.items = nextItems;
    this.selected = nextSelected;
    this.reordering = false;
  }

  // 拖拽浮层：跟随手指的缩略图。
  @Builder
  dragOverlay(): void {
    if (this.dragIndex >= 0 && this.dragIndex < this.items.length) {
      if (this.items[this.dragIndex].preview !== undefined) {
        Image(this.items[this.dragIndex].preview as image.PixelMap)
          .width(90)
          .height(90)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .opacity(0.9)
          .draggable(false)
      } else {
        Image(resolveDisplayImageUrl(this.items[this.dragIndex].remoteUrl ?? ''))
          .width(90)
          .height(90)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .opacity(0.9)
          .draggable(false)
      }
    }
  }

  @Builder
  imageCell(item: PickedImage, idx: number): void {
    Stack() {
      if (item.preview !== undefined) {
        Image(item.preview)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          // 关闭 Image 自带拖拽，避免长按被系统拖拽接管、抢走 Grid 的排序手势。
          .draggable(false)
      } else {
        Image(resolveDisplayImageUrl(item.remoteUrl ?? ''))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .draggable(false)
      }
      if (item.uploading) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(Color.White)
      }
      Text('×')
        .fontSize(16).fontFamily($r('app.string.font_family'))
        .fontColor(Color.White)
        .backgroundColor('#00000066')
        .width(20)
        .height(20)
        .borderRadius(10)
        .textAlign(TextAlign.Center)
        .position({ top: 2, right: 2 })
        .onClick(() => this.removeAt(idx))
    }
    .width('100%')
    .aspectRatio(1)
    // 拖拽中高亮当前落点格子，给出明确的插入位置反馈。
    .border({
      width: this.dragIndex >= 0 && this.dragTargetIndex === idx ? 2 : 0,
      color: $r('app.color.ds_brand'),
      radius: 8,
    })
  }

  build() {
    Column({ space: 8 }) {
      Grid() {
        ForEach(this.items, (item: PickedImage, idx: number) => {
          GridItem() {
            this.imageCell(item, idx)
          }
        }, (item: PickedImage) => item.id)

        if (this.items.length < this.maxCount) {
          GridItem() {
            Column() {
              Text('+')
                .fontSize(28).fontFamily($r('app.string.font_family'))
                .fontColor($r('app.color.text_secondary'))
              Text('添加')
                .fontSize(12).fontFamily($r('app.string.font_family'))
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .aspectRatio(1)
            .justifyContent(FlexAlign.Center)
            .backgroundColor($r('app.color.control_bg'))
            .border({ width: 1, color: $r('app.color.divider'), style: BorderStyle.Dashed })
            .borderRadius(8)
            .onClick(() => this.pick())
          }
        }
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(8)
      .rowsGap(8)
      .width('100%')
      // 长按 170ms 进入编辑模式拖拽；补全拖拽生命周期以提供实时的落点高亮。
      .editMode(true)
      .onItemDragStart((_event: ItemDragInfo, itemIndex: number) => {
        // 末尾「+ 添加」格子不可拖拽。
        if (itemIndex < 0 || itemIndex >= this.items.length) {
          return;
        }
        this.dragIndex = itemIndex;
        this.dragTargetIndex = itemIndex;
        return this.dragOverlay;
      })
      .onItemDragMove((_event: ItemDragInfo, _itemIndex: number, insertIndex: number): void => {
        // 实时更新悬停落点，驱动格子高亮。
        this.dragTargetIndex = this.clampTargetIndex(insertIndex);
      })
      .onItemDragLeave((_event: ItemDragInfo, _itemIndex: number): void => {
        this.dragTargetIndex = -1;
      })
      .onItemDrop((_event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean): void => {
        const from: number = this.dragIndex >= 0 ? this.dragIndex : itemIndex;
        this.dragIndex = -1;
        this.dragTargetIndex = -1;
        if (!isSuccess || from < 0 || from >= this.items.length) {
          return;
        }
        // 把被拖起项移动到落点；拖到「+ 添加」格视为移到末尾。
        this.moveItem(from, this.clampTargetIndex(insertIndex));
      })

      if (this.items.length > 1) {
        Text('长按图片可拖动调整顺序')
          .fontSize(12).fontFamily($r('app.string.font_family'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(12)
  }
}