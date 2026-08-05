// 视频上传工具：首帧封面抓取（AVPlayer）、文件大小与二进制读取。
// 封面走现有图片上传链路（getUploadSignature('image/jpeg','posts') + putBinary），
// 视频本身走 getUploadSignature('video/mp4','video', size) + putBinary。
import { media } from '@kit.MediaKit';
import { image } from '@kit.ImageKit';
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
    const view: Uint8Array = new Uint8Array(buffer);
    await fileIo.read(file.fd, view);
    return buffer;
  } finally {
    fileIo.closeSync(file);
  }
}

// 抓取视频首帧并压缩为 jpeg（质量 80%）二进制，用于视频封面。
// 内部用 AVPlayer 置为播放态后 snapshot，抓完即释放资源，不泄漏。
export async function captureVideoCoverBytes(uri: string): Promise<ArrayBuffer> {
  const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  const player: media.AVPlayer = await media.createAVPlayer();
  let pixel: image.PixelMap | undefined = undefined;
  try {
    pixel = await new Promise<image.PixelMap>((resolve, reject) => {
      let settled: boolean = false;
      player.on('stateChange', (state: string) => {
        if (settled) {
          return;
        }
        if (state === 'prepared') {
          player.play();
        } else if (state === 'playing') {
          player.snapshot((err: Error | null, px: image.PixelMap) => {
            if (settled) {
              return;
            }
            if (err) {
              settled = true;
              reject(err);
              return;
            }
            settled = true;
            resolve(px);
          });
        } else if (state === 'error') {
          if (!settled) {
            settled = true;
            reject(new Error('视频解码失败，无法提取封面'));
          }
        }
      });
      player.fd = file.fd;
      player.prepare();
    });
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
    if (pixel !== undefined) {
      pixel.release();
    }
    player.release();
    fileIo.closeSync(file);
  }
}
