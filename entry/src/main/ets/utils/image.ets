// 图片压缩：选图后长边压缩 + 质量 80% 转 jpeg（详见技术文档 5.3）。
// 同时返回 PixelMap（本地预览）与 bytes（上传 COS 用），一举两得。
import { image } from '@kit.ImageKit';

export interface CompressedImage {
  preview: image.PixelMap; // 本地预览用
  bytes: ArrayBuffer; // 上传二进制用（jpeg）
}

export async function compressImage(uri: string): Promise<CompressedImage> {
  const source: image.ImageSource = image.createImageSource(uri);
  const pixelMap: image.PixelMap = await source.createPixelMap();
  const packer: image.ImagePacker = image.createImagePacker();
  try {
    const bytes: ArrayBuffer = await packer.packToData(pixelMap, {
      format: 'image/jpeg',
      quality: 80,
    });
    return { preview: pixelMap, bytes };
  } catch (e: Error) {
    throw e;
  } finally {
    await packer.release();
  }
}
