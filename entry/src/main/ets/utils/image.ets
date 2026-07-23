// 图片压缩：选图后长边压缩 + 质量 80% 转 jpeg（详见技术文档 5.3）。
// 同时返回 PixelMap（本地预览）与 bytes（上传 COS 用），一举两得。
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';

export interface CompressedImage {
  preview: image.PixelMap; // 本地预览用
  bytes: ArrayBuffer; // 上传二进制用（jpeg）
}

export async function compressImage(uri: string): Promise<CompressedImage> {
  // 相册返回的 photo:// URI 是沙箱受限 URI，必须经由文件描述符打开，
  // 直接用 image.createImageSource(uri) 在某些 SDK 会返回 undefined（导致 createPixelMap 报错）。
  const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  let source: image.ImageSource;
  try {
    source = image.createImageSource(file.fd);
  } catch (e) {
    fileIo.closeSync(file);
    throw new Error((e as Error).message);
  }
  try {
    const pixelMap: image.PixelMap = await source.createPixelMap();
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      const bytes: ArrayBuffer = await packer.packToData(pixelMap, {
        format: 'image/jpeg',
        quality: 80,
      });
      return { preview: pixelMap, bytes };
    } finally {
      await packer.release();
    }
  } finally {
    source.release();
    fileIo.closeSync(file);
  }
}
