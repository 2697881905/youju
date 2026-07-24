// 图片选择器 + 腾讯云 COS 直传：
// PhotoViewPicker 拉相册 → 压缩(jpeg) → 调 getUploadSignature 拿预签名 PUT URL → 直传二进制。
// 本地用 PixelMap 即时预览；直传成功后把远端 URL 写入 @Link selected（供发布器提交）。
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { LengthMetrics } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { compressImage, CompressedImage } from '../utils/image';
import { getUploadSignature, resolveUploadPutUrl } from '../services/api';
import { ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { User } from '../models/types';

interface PickedImage {
  id: string; // 稳定 key
  preview: image.PixelMap; // 本地预览
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

  // 外部（发布器 reset）把 selected 清空时，同步清空本地预览
  private onSelectedChange(): void {
    if (this.selected.length === 0 && this.items.length > 0) {
      this.items = [];
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
          const sig = await getUploadSignature('image/jpeg');
          await this.putBinary(resolveUploadPutUrl(sig), bytes, sig.contentType);
          item.remoteUrl = sig.viewUrl;
          item.uploading = false;
          this.items = [...this.items];
          this.selected = [...this.selected, sig.viewUrl];
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

  build() {
    Column({ space: 8 }) {
      Text('图片（最多 ' + this.maxCount + ' 张，选图后自动上传到腾讯云 COS）')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, space: { main: LengthMetrics.px(8), cross: LengthMetrics.px(8) } }) {
        ForEach(this.items, (item: PickedImage, idx: number) => {
          Stack() {
            Image(item.preview)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
              .borderRadius(8)
            if (item.uploading) {
              LoadingProgress()
                .width(28)
                .height(28)
                .color(Color.White)
            }
            Text('×')
              .fontSize(16)
              .fontColor(Color.White)
              .backgroundColor('#00000066')
              .width(20)
              .height(20)
              .borderRadius(10)
              .textAlign(TextAlign.Center)
              .position({ top: 2, right: 2 })
              .onClick(() => this.removeAt(idx))
          }
          .width('30%')
          .aspectRatio(1)
        }, (item: PickedImage) => item.id)

        if (this.items.length < this.maxCount) {
          Column() {
            Text('+')
              .fontSize(28)
              .fontColor($r('app.color.text_secondary'))
            Text('添加')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('30%')
          .aspectRatio(1)
          .justifyContent(FlexAlign.Center)
          .border({ width: 1, color: $r('app.color.text_secondary'), style: BorderStyle.Dashed })
          .borderRadius(8)
          .onClick(() => this.pick())
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
  }
}
