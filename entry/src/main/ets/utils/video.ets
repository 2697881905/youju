// 视频上传工具：首帧封面抓取（@kit.MediaKit AVImageGenerator）、文件大小与二进制读取。
// 封面走现有图片上传链路（getUploadSignature('image/jpeg','posts') + putBinary），
// 视频本身走 getUploadSignature('video/mp4','video', size) + putBinary。
import { image } from '@kit.ImageKit';
import { media } from '@kit.MediaKit';
import { fileIo } from '@kit.CoreFileKit';

const MAX_VIDEO_SIZE: number = 50 * 1024 * 1024; // 50MB 前端硬上限（与后端 token 校验一致）

export function getMaxVideoSize(): number {
  return MAX_VIDEO_SIZE;
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

// 抓取视频首帧并压缩为 jpeg（质量 80%）二进制，用于视频封面。
// 视频不是图片，image.ImageSource 无法解码视频（报 realpath error / CreateImageSourceExec error），
// 故改用 @kit.MediaKit 的 AVImageGenerator 从文件描述符抓取首帧 PixelMap 再打包为 jpeg。
// 若平台对该 uri 不支持首帧解码，调用方应 catch 并降级为空封面继续上传视频本体。
export async function captureVideoCoverBytes(uri: string): Promise<ArrayBuffer> {
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
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      const bytes: ArrayBuffer = await packer.packToData(pixel, {
        format: 'image/jpeg',
        quality: 80,
      });
      return bytes;
    } finally {
      await packer.release();
    }
  } finally {
    if (generator !== undefined) {
      generator.release();
    }
    fileIo.closeSync(file);
  }
}
