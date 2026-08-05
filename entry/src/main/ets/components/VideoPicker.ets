// 视频选择器 + 腾讯云 COS 直传：
// PhotoViewPicker 拉相册(视频) → 首帧抓封面(jpeg) → 封面走图片上传链路 → 视频本体直传 video folder。
// 与 ImagePicker 二选一（发布页 publishMode 控制），一条帖子仅一段视频。
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { http } from '@kit.NetworkKit';
import { getUploadSignature, resolveUploadPutUrl } from '../services/api';
import { getMediaFileSize, readFileBytes, captureVideoCoverBytes, getMaxVideoSize } from '../utils/video';
import { ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { VideoPlayer } from './VideoPlayer';

@Component
export struct VideoPicker {
  @Link videoUrl: string; // 远端视频 URL（发布用）
  @Link videoCover: string; // 远端封面 URL（发布用）
  @State localUri: string = ''; // 本地预览源（发布前用本地播放）
  @State uploading: boolean = false;
  @State errorTip: string = '';
  private picking: boolean = false;

  // 直传二进制到预签名 URL（视频体积大，超时放宽到 120s）
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
          connectTimeout: 120000,
          readTimeout: 120000,
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
    if (this.picking || this.uploading) {
      return;
    }
    this.picking = true;
    try {
      const u = await ensureLogin();
      if (!u) {
        this.picking = false;
        return;
      }
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '登录失败，无法上传：' + (e as Error).message });
      this.picking = false;
      return;
    }
    try {
      const ph = new photoAccessHelper.PhotoViewPicker();
      const res = await ph.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE,
        maxSelectNumber: 1,
      });
      const uri: string | undefined = res.photoUris?.[0];
      if (!uri) {
        this.picking = false;
        return;
      }
      // 前端 ≤50MB 拦截（后端 token 接口二次兜底）
      const size: number = await getMediaFileSize(uri);
      if (size > getMaxVideoSize()) {
        safeShowToast(this.getUIContext(), { message: '视频大小不能超过 50MB' });
        this.picking = false;
        return;
      }
      this.uploading = true;
      this.errorTip = '';
      try {
        // 1) 首帧封面
        const coverBytes: ArrayBuffer = await captureVideoCoverBytes(uri);
        const coverSig = await getUploadSignature('image/jpeg', 'posts');
        await this.putBinary(resolveUploadPutUrl(coverSig), coverBytes, coverSig.contentType);
        // 2) 视频本体
        const videoBytes: ArrayBuffer = await readFileBytes(uri);
        const videoSig = await getUploadSignature('video/mp4', 'video', size);
        await this.putBinary(resolveUploadPutUrl(videoSig), videoBytes, videoSig.contentType);
        // 3) 落状态（本地预览优先用本地 uri）
        this.localUri = uri;
        this.videoUrl = videoSig.viewUrl;
        this.videoCover = coverSig.viewUrl;
      } catch (e) {
        this.errorTip = '视频上传失败：' + (e as Error).message;
        safeShowToast(this.getUIContext(), { message: this.errorTip });
      } finally {
        this.uploading = false;
      }
    } catch (e) {
      // 用户取消选择会抛错，忽略
    } finally {
      this.picking = false;
    }
  }

  private reset(): void {
    this.videoUrl = '';
    this.videoCover = '';
    this.localUri = '';
    this.errorTip = '';
  }

  build() {
    Column({ space: 8 }) {
      if (this.videoUrl.length > 0) {
        Stack() {
          VideoPlayer({ src: this.localUri || this.videoUrl, poster: this.videoCover, videoHeight: 200 })
          if (this.uploading) {
            LoadingProgress()
              .width(32)
              .height(32)
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
            .onClick(() => this.reset())
        }
        .width('100%')
        .borderRadius(8)
        .backgroundColor('#0000000a')
      } else {
        Column() {
          Text('+')
            .fontSize(28).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'))
          Text('视频')
            .fontSize(12).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('40%')
        .aspectRatio(2)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.control_bg'))
        .border({ width: 1, color: $r('app.color.divider'), style: BorderStyle.Dashed })
        .borderRadius(8)
        .onClick(() => this.pick())
      }
      if (this.errorTip.length > 0) {
        Text(this.errorTip)
          .fontSize(12)
          .fontColor($r('app.color.text_error'))
      }
    }
    .width('100%')
  }
}
