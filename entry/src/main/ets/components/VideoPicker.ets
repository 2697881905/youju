// 视频选择器 + 腾讯云 COS 直传：
// PhotoViewPicker 拉相册(视频) → 首帧抓封面(jpeg) → 封面走图片上传链路 → 视频本体直传 video folder。
// 与 ImagePicker 二选一（发布页 publishMode 控制），一条帖子仅一段视频。
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { getUploadSignature, resolveUploadPutUrl, toStoredMediaRef } from '../services/api';
import { getMediaFileSize, readFileBytes, captureVideoCover, packVideoCoverBytes, getMaxVideoSize, getVideoAspectRatio, getVisiblePixelMapAspectRatio, FALLBACK_VIDEO_ASPECT_RATIO } from '../utils/video';
import { ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { VideoPlayer } from './VideoPlayer';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct VideoPicker {
  @Link videoUrl: string; // 远端视频 URL（发布用）
  @Link videoCover: string; // 远端封面 URL（发布用）
  @Link videoAspectRatio: number; // 宽/高，驱动发布预览与详情展示
  @State localUri: string = ''; // 本地预览源（发布前用本地播放）
  @State localCover: image.PixelMap | undefined = undefined; // 上传中的本地首帧，避免预览黑屏
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
      let capturedCover: image.PixelMap | undefined = undefined;
      try {
        let aspectRatio: number = FALLBACK_VIDEO_ASPECT_RATIO;
        try {
          aspectRatio = await getVideoAspectRatio(uri);
        } catch (_metadataError) {
          // 元数据读取失败时使用稳定的竖版兜底，不阻断上传。
        }
        // 1) 首帧封面（失败不阻断视频上传，封面留空，展示层用黑底+角标兜底）
        let coverMediaRef: string = '';
        try {
          capturedCover = await captureVideoCover(uri);
          // 以首帧实际可见画面计算容器宽高，排除内嵌在视频画布里的上下黑边。
          aspectRatio = await getVisiblePixelMapAspectRatio(capturedCover);
          const coverBytes: ArrayBuffer = await packVideoCoverBytes(capturedCover);
          const coverSig = await getUploadSignature('image/jpeg', 'posts');
          await this.putBinary(resolveUploadPutUrl(coverSig), coverBytes, coverSig.contentType);
          coverMediaRef = toStoredMediaRef(coverSig);
        } catch (_coverErr) {
          // 封面抓取/上传失败，继续上传视频本体
        }
        // 2) 视频本体
        const videoBytes: ArrayBuffer = await readFileBytes(uri);
        const videoSig = await getUploadSignature('video/mp4', 'video', size);
        await this.putBinary(resolveUploadPutUrl(videoSig), videoBytes, videoSig.contentType);
        // 3) 落状态（本地预览优先用本地 uri）
        this.localUri = uri;
        this.videoUrl = toStoredMediaRef(videoSig);
        this.videoCover = coverMediaRef;
        this.videoAspectRatio = aspectRatio;
        this.localCover = capturedCover;
        capturedCover = undefined;
      } catch (e) {
        this.errorTip = '视频上传失败：' + (e as Error).message;
        safeShowToast(this.getUIContext(), { message: this.errorTip });
      } finally {
        if (capturedCover !== undefined) {
          await capturedCover.release();
        }
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
    this.videoAspectRatio = FALLBACK_VIDEO_ASPECT_RATIO;
    this.localUri = '';
    if (this.localCover !== undefined) {
      this.localCover.release();
      this.localCover = undefined;
    }
    this.errorTip = '';
  }

  build() {
    Column({ space: SpaceTokens.sm }) {
      if (this.videoUrl.length > 0) {
        Stack() {
          VideoPlayer({ src: this.localUri || this.videoUrl, poster: this.localCover ?? this.videoCover })
          if (this.uploading) {
            LoadingProgress()
              .width(32)
              .height(32)
              .color(Color.White)
          }
          // 删除键：28vp 可视圆底 + 44vp 命中包装（与图片删除键同一形态）。
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
          .position({ top: 4, right: 4 })
          .onClick(() => this.reset())
        }
        .width('100%')
        .aspectRatio(this.videoAspectRatio)
        .borderRadius(RadiusTokens.nested)
        .clip(true)
        .backgroundColor(Color.Black)
      } else {
        // 空态紧凑入口（方案 A）：96vp 一行，取代满宽 3:4 大框（旧空态独占首屏约 47%）。
        // 选中后才展开满宽真实比例预览，写作区因此回到首屏。
        Pressable({
          fillWidth: true,
          visualHeight: 96,
          touchTargetHeight: 96,
          fullResponseRegion: true,
          action: (): void => { this.pick(); },
        }) {
          Row({ space: SpaceTokens.md }) {
            Row() {
              Image($r('app.media.publish_video_outline'))
                .width(26)
                .height(26)
                .objectFit(ImageFit.Contain)
                .fillColor(ColorTokens.tertiary)
            }
            .width(56)
            .height(56)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(ColorTokens.panel)
            .borderRadius(RadiusTokens.sm)

            Column({ space: SpaceTokens.xs }) {
              Text('添加视频')
                .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.headline.weight)
                .lineHeight(TypeTokens.callout.lineHeight)
                .fontColor(ColorTokens.primary)
              Text('单段视频 ≤ 50MB')
                .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.caption.weight)
                .lineHeight(TypeTokens.caption.lineHeight)
                .fontColor(ColorTokens.tertiary)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Image($r('app.media.chevron_right'))
              .width(IconTokens.compact)
              .height(IconTokens.compact)
              .fillColor(ColorTokens.tertiary)
          }
          .width('100%')
          .height(96)
          .padding({ left: SpaceTokens.item, right: SpaceTokens.item })
          .backgroundColor(ColorTokens.subtle)
          .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Dashed })
          .borderRadius(RadiusTokens.nested)
          .alignItems(VerticalAlign.Center)
        }
      }
      if (this.errorTip.length > 0) {
        Text(this.errorTip)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.danger)
      }
    }
    .width('100%')
  }
}
