// 视频上传工具：首帧封面抓取（@kit.MediaKit AVImageGenerator）、文件大小与二进制读取。
// 封面走现有图片上传链路（getUploadSignature('image/jpeg','posts') + putBinary），
// 视频本身走 getUploadSignature('video/mp4','video', size) + putBinary。
import { image } from '@kit.ImageKit';
import { media } from '@kit.MediaKit';
import { fileIo } from '@kit.CoreFileKit';

const MAX_VIDEO_SIZE: number = 50 * 1024 * 1024; // 50MB 前端硬上限（与后端 token 校验一致）
export const FALLBACK_VIDEO_ASPECT_RATIO: number = 0.75;
const MIN_VIDEO_ASPECT_RATIO: number = 0.45;
const MAX_VIDEO_ASPECT_RATIO: number = 2.2;

export function getMaxVideoSize(): number {
  return MAX_VIDEO_SIZE;
}

export function normalizeVideoAspectRatio(ratio: number): number {
  if (!isFinite(ratio) || ratio <= 0) {
    return FALLBACK_VIDEO_ASPECT_RATIO;
  }
  if (ratio < MIN_VIDEO_ASPECT_RATIO) {
    return MIN_VIDEO_ASPECT_RATIO;
  }
  if (ratio > MAX_VIDEO_ASPECT_RATIO) {
    return MAX_VIDEO_ASPECT_RATIO;
  }
  return ratio;
}

// AVImageGenerator 返回的是实际交给播放器解码的帧尺寸，优先用它布局可规避
// 部分素材的旋转元数据与解码帧尺寸不一致导致的上下黑边。
export function getPixelMapAspectRatio(pixel: image.PixelMap): number {
  const info: image.ImageInfo = pixel.getImageInfoSync();
  return normalizeVideoAspectRatio(info.size.width / info.size.height);
}

// 有些视频把 3:4 或横版画面嵌在 9:16/16:9 黑色画布中。播放器看到的是整张
// 画布，单用元数据或帧尺寸都会把黑边算进容器高度。这里从首帧找上下连续黑边，
// 用真正可见内容的高度参与布局；采样失败时保持原始帧比例。
export async function getVisiblePixelMapAspectRatio(pixel: image.PixelMap): Promise<number> {
  const info: image.ImageInfo = pixel.getImageInfoSync();
  const width: number = info.size.width;
  const height: number = info.size.height;
  if (width <= 0 || height <= 0) {
    return FALLBACK_VIDEO_ASPECT_RATIO;
  }

  const rowBytes: number = pixel.getBytesNumberPerRow();
  // getPixelBytesNumber() 返回整张图的总字节数，不是单个像素的字节数。
  const pixelBytes: number = Math.floor(rowBytes / width);
  if (rowBytes <= 0 || pixelBytes < 3) {
    return getPixelMapAspectRatio(pixel);
  }

  const pixels: ArrayBuffer = new ArrayBuffer(rowBytes * height);
  await pixel.readPixelsToBuffer(pixels);
  const bytes: Uint8Array = new Uint8Array(pixels);
  const samples: number = Math.min(32, width);
  const isBlackRow = (row: number): boolean => {
    let blackSamples: number = 0;
    for (let sample: number = 0; sample < samples; sample += 1) {
      const x: number = Math.floor((sample + 0.5) * width / samples);
      const offset: number = row * rowBytes + Math.min(x, width - 1) * pixelBytes;
      // RGBA/ARGB 的 alpha 可能位于首位或末位；黑色像素至少有三个低值分量。
      let darkComponents: number = 0;
      for (let component: number = 0; component < pixelBytes; component += 1) {
        if (bytes[offset + component] < 18) {
          darkComponents += 1;
        }
      }
      if (darkComponents >= 3) {
        blackSamples += 1;
      }
    }
    return blackSamples / samples >= 0.9;
  };

  let top: number = 0;
  while (top < Math.floor(height * 0.3) && isBlackRow(top)) {
    top += 1;
  }
  let bottom: number = height - 1;
  while (bottom > Math.floor(height * 0.7) && isBlackRow(bottom)) {
    bottom -= 1;
  }
  const cropHeight: number = bottom - top + 1;
  // 仅在上下各存在可观黑边时裁切，避免把夜景或黑场误判成画布边缘。
  if (top < Math.floor(height * 0.04) || height - 1 - bottom < Math.floor(height * 0.04) || cropHeight <= 0) {
    return getPixelMapAspectRatio(pixel);
  }
  return normalizeVideoAspectRatio(width / cropHeight);
}

// 从媒体元数据读取展示比例。带 90/270 度旋转标记的视频需交换宽高。
export async function getVideoAspectRatio(uri: string): Promise<number> {
  const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  let extractor: media.AVMetadataExtractor | undefined = undefined;
  try {
    const stat: fileIo.Stat = fileIo.statSync(file.fd);
    extractor = await media.createAVMetadataExtractor();
    extractor.fdSrc = { fd: file.fd, offset: 0, length: stat.size };
    const metadata: media.AVMetadata = await extractor.fetchMetadata();
    let width: number = Number(metadata.videoWidth ?? 0);
    let height: number = Number(metadata.videoHeight ?? 0);
    const orientation: number = Math.abs(Number(metadata.videoOrientation ?? 0)) % 360;
    if (orientation === 90 || orientation === 270) {
      const originalWidth: number = width;
      width = height;
      height = originalWidth;
    }
    return normalizeVideoAspectRatio(width / height);
  } finally {
    if (extractor !== undefined) {
      await extractor.release();
    }
    fileIo.closeSync(file);
  }
}

// 取文件大小（字节），不读取内容；用于 ≤50MB 前端拦截。
export async function getMediaFileSize(uri: string): Promise<number> {
  const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  try {
    const stat: fileIo.Stat = fileIo.statSync(file.fd);
    return stat.size;
  } finally {
    fileIo.closeSync(file);
  }
}

// 读取文件完整二进制（视频直传用），调用方应先校验大小。
export async function readFileBytes(uri: string): Promise<ArrayBuffer> {
  const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  try {
    const stat: fileIo.Stat = fileIo.statSync(file.fd);
    const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
    await fileIo.read(file.fd, buffer, { offset: 0, length: stat.size });
    return buffer;
  } finally {
    fileIo.closeSync(file);
  }
}

// 视频不是图片，需用 AVImageGenerator 从文件描述符抓取首帧 PixelMap。
// 调用方可以直接把 PixelMap 用作本地预览，避免等待远端封面上传完成。
export async function captureVideoCover(uri: string): Promise<image.PixelMap> {
  const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  let generator: media.AVImageGenerator | undefined = undefined;
  try {
    const stat: fileIo.Stat = fileIo.statSync(file.fd);
    generator = await media.createAVImageGenerator();
    generator.fdSrc = { fd: file.fd, offset: 0, length: stat.size };
    const params: media.PixelMapParams = { width: 0, height: 0 };
    const pixel: image.PixelMap = await generator.fetchFrameByTime(
      0,
      media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC,
      params
    );
    return pixel;
  } finally {
    if (generator !== undefined) {
      generator.release();
    }
    fileIo.closeSync(file);
  }
}

export async function packVideoCoverBytes(pixel: image.PixelMap): Promise<ArrayBuffer> {
  const packer: image.ImagePacker = image.createImagePacker();
  try {
    return await packer.packToData(pixel, { format: 'image/jpeg', quality: 80 });
  } finally {
    await packer.release();
  }
}

// 兼容已有调用：抓取首帧并压缩为 jpeg（质量 80%）二进制，用于上传。
export async function captureVideoCoverBytes(uri: string): Promise<ArrayBuffer> {
  const pixel: image.PixelMap = await captureVideoCover(uri);
  try {
    return await packVideoCoverBytes(pixel);
  } finally {
    await pixel.release();
  }
}
