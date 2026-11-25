// 图片选择器 + 腾讯云 COS 直传：
// PhotoViewPicker 拉相册 → 压缩(jpeg) → 调 getUploadSignature 拿预签名 PUT URL → 直传二进制。
// 本地用 PixelMap 即时预览；直传成功后把远端 URL 写入 @Link selected（供发布器提交）。
// 多图场景下支持长按单张图片拖拽排序：Grid 进入编辑模式后长按拖动即可调整图片顺序。
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { dataSharePredicates } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { compressImage, CompressedImage } from '../utils/image';
import { getUploadSignature, resolveDisplayImageUrl, resolveUploadPutUrl, toStoredMediaRef } from '../services/api';
import { ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { User } from '../models/types';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

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
        // 方向优先走媒体库数据库（PhotoAsset.ORIENTATION）：文件 EXIF 可能被导出链路剥掉（2339.jpg 实锤），
        // 而相册显示仍正——方向存在数据库不在文件里。picker URI 查询无需 READ_IMAGEVIDEO 权限。
        const dbOrientation = await this.orientationOf(u);
        // cacheDir 取自全局 getContext（getHostContext 在此组件实测返回 undefined，导致 staged 路径被跳过）
        const cacheDir = (getContext(this) as common.Context).cacheDir ?? '';
        const compressed: CompressedImage = await compressImage(u, 1920, cacheDir, dbOrientation);
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

  // 从媒体库数据库读方向（picker URI 查询无需 READ_IMAGEVIDEO 权限——官方「指定URI获取图片或视频资源」路径）。
  // 相册方向存在数据库而非文件 EXIF：导出链路会剥掉文件 EXIF 但相册仍显示正（2339.jpg 字节实锤无 EXIF 段）。
  private async orientationOf(uri: string): Promise<number> {
    try {
      const ctx = getContext(this) as common.Context;
      const helper = photoAccessHelper.getPhotoAccessHelper(ctx);
      const pred: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
      pred.equalTo(photoAccessHelper.PhotoKeys.URI, uri);
      const options: photoAccessHelper.FetchOptions = {
        fetchColumns: [photoAccessHelper.PhotoKeys.ORIENTATION],
        predicates: pred,
      };
      const result = await helper.getAssets(options);
      const asset: photoAccessHelper.PhotoAsset | undefined = await result.getFirstObject();
      const rawO = asset !== undefined ? asset.get(photoAccessHelper.PhotoKeys.ORIENTATION) : '0';
      const o: number = asset !== undefined ? parseInt(String(rawO), 10) || 0 : 0;
      result.close();
      console.info('IMG_EXIF_DB ' + o);
      return o;
    } catch (e) {
      console.info('IMG_EXIF_DB fail: ' + (e as Error).message);
      return 0;
    }
  }

  // 图片预览由宿主页面承载（Reveal 内自挂 bindContentCover 渲染异常——黑屏实证）：
  // 这里上抛点击图片的 remoteUrl，宿主页面在已上传列表中定位并支持左右切换。
  onPreview?: (url: string) => void = undefined;

  private openPreview(idx: number): void {
    // 仅已上传完成（remoteUrl 已回填）的格子可预览：上传中的图不在宿主已上传列表里
    const url = this.items[idx].remoteUrl ?? '';
    if (url.length > 0 && this.onPreview !== undefined) {
      this.onPreview(url);
    }
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
          .borderRadius(RadiusTokens.nested)
          .opacity(0.9)
          .draggable(false)
      } else {
        Image(resolveDisplayImageUrl(this.items[this.dragIndex].remoteUrl ?? ''))
          .width(90)
          .height(90)
          .objectFit(ImageFit.Cover)
          .borderRadius(RadiusTokens.nested)
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
          .borderRadius(RadiusTokens.nested)
          // 关闭 Image 自带拖拽，避免长按被系统拖拽接管、抢走 Grid 的排序手势。
          .draggable(false)
      } else {
        Image(resolveDisplayImageUrl(item.remoteUrl ?? ''))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(RadiusTokens.nested)
          .draggable(false)
      }
      if (item.uploading) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(Color.White)
      }
      // 删除键：28vp 可视圆底 + 44vp 命中包装（与视频删除键同一形态），整块落在格子内不越界。
      Row() {
        Row() {
          Image($r('app.media.close_x_white'))
            .width(14)
            .height(14)
            .fillColor(Color.White)
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(ColorTokens.mediaScrim)
        .borderRadius(RadiusTokens.pill)
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .position({ top: 0, right: 0 })
      .onClick(() => this.removeAt(idx))
    }
    .onClick(() => this.openPreview(idx))
    .width('100%')
    .aspectRatio(1)
    // 拖拽中高亮当前落点格子，给出明确的插入位置反馈。
    .border({
      width: this.dragIndex >= 0 && this.dragTargetIndex === idx ? 2 : 0,
      color: $r('app.color.ds_brand'),
      radius: RadiusTokens.nested,
    })
  }

  build() {
    Column({ space: SpaceTokens.sm }) {
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
                .fontSize(TypeTokens.display.size).fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.tertiary)
              Text('添加')
                .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                .fontColor(ColorTokens.tertiary)
            }
            .width('100%')
            .aspectRatio(1)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(ColorTokens.subtle)
            .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Dashed })
            .borderRadius(RadiusTokens.nested)
            .onClick(() => this.pick())
          }
        }
      }
      .edgeEffect(EdgeEffect.Spring)
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(SpaceTokens.sm)
      .rowsGap(SpaceTokens.sm)
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
      .scrollBar(BarState.Off)
    }
    .width('100%')

  }
}
