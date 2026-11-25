// 图片压缩：选图后长边压缩 + 质量 80% 转 jpeg（详见技术文档 5.3）。
// 同时返回 PixelMap（本地预览）与 bytes（上传 COS 用），一举两得。
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';

export interface CompressedImage {
  preview: image.PixelMap; // 本地预览用
  bytes: ArrayBuffer; // 上传二进制用（jpeg）
}

// EXIF orientation → 需要顺时针旋转的角度（pixelMap.rotate 正值实测=顺时针，歪180实测实锤）。
// EXIF 6/5 需顺时针 90° 转正；8/7 需顺时针 270°；3 需 180°；镜像类（2/4）无法用纯旋转修正。
function exifToCwDeg(o: number): number {
  return o === 6 ? 90 : o === 3 ? 180 : o === 8 ? 270 : o === 5 ? 90 : o === 7 ? 270 : 0;
}

// 手写解析 JPEG 字节里的 EXIF APP1/TIFF 段，返回 Orientation（1-8，无则 0）。
// ImageSource 属性 API 三路全灭（fd 沙箱恒0 / photo://直开undefined / staged 源读数被 fd 回退覆盖），
// 字节层面解析绕过一切系统 API 限制。
function parseExifOrientation(data: ArrayBuffer): number {
  const u8 = new Uint8Array(data);
  if (u8.length < 12 || u8[0] !== 0xFF || u8[1] !== 0xD8) {
    return 0;
  }
  let off = 2;
  while (off + 4 <= u8.length) {
    if (u8[off] !== 0xFF) {
      break;
    }
    const marker = u8[off + 1];
    if (marker === 0xD8 || (marker >= 0xD0 && marker <= 0xD7)) {
      off += 2;
      continue;
    }
    if (marker === 0xDA) {
      break; // SOS：段数据结束
    }
    const segLen = (u8[off + 2] << 8) | u8[off + 3];
    if (marker === 0xE1 && u8[off + 4] === 0x45 && u8[off + 5] === 0x78 && u8[off + 6] === 0x69 && u8[off + 7] === 0x66) {
      // APP1 "Exif\0\0"：TIFF 头在 off+10
      const tiff = off + 10;
      if (tiff + 8 > u8.length) {
        return 0;
      }
      const big = u8[tiff] === 0x4D;
      const rd16 = (p: number): number => big ? (u8[p] << 8) | u8[p + 1] : u8[p] | (u8[p + 1] << 8);
      const rd32 = (p: number): number => big
        ? ((u8[p] << 24) | (u8[p + 1] << 16) | (u8[p + 2] << 8) | u8[p + 3]) >>> 0
        : ((u8[p + 3] << 24) | (u8[p + 2] << 16) | (u8[p + 1] << 8) | u8[p]) >>> 0;
      const ifd0 = tiff + rd32(tiff + 4);
      if (ifd0 + 2 > u8.length) {
        return 0;
      }
      const cnt = rd16(ifd0);
      for (let i = 0; i < cnt; i++) {
        const entry = ifd0 + 2 + i * 12;
        if (entry + 12 > u8.length) {
          return 0;
        }
        if (rd16(entry) === 0x0112) {
          return rd16(entry + 8); // Orientation SHORT
        }
      }
      return 0;
    }
    off += 2 + segLen;
  }
  return 0;
}

export async function compressImage(uri: string, maxEdge: number = 1920, cacheDir: string = '', exifOrientation?: number): Promise<CompressedImage> {
  // 相册返回的 photo:// URI 是沙箱受限 URI，必须经由文件描述符打开，
  // 直接用 image.createImageSource(uri) 在某些 SDK 会返回 undefined（导致 createPixelMap 报错）。
  const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  // EXIF 前置：photo:// fd 沙箱源 getImageProperty 实测恒 0（属性受限）、photo:// 直开又 undefined——
  // 先把原始 JPEG 落到应用 cache 沙箱，用普通文件路径源读 EXIF（非受限路径属性可读）。
  let stagedPath = '';
  if (cacheDir.length > 0) {
    try {
      stagedPath = cacheDir + '/img_stage_' + Date.now() + '.jpg';
      const size = fileIo.statSync(file.fd).size;
      const buf = new ArrayBuffer(size);
      fileIo.readSync(file.fd, buf);
      const out = fileIo.openSync(stagedPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(out.fd, buf);
      fileIo.closeSync(out);
    } catch (e) {
      stagedPath = '';
      console.info('IMG_STAGE fail: ' + (e as Error).message);
    }
  } else {
    console.info('IMG_STAGE skip: cacheDir empty');
  }
  let source: image.ImageSource;
  try {
    source = image.createImageSource(file.fd);
  } catch (e) {
    fileIo.closeSync(file);
    throw new Error((e as Error).message);
  }
  try {
    const pixelMap: image.PixelMap = await source.createPixelMap();
    // EXIF 烘焙：优先外部传入（photoAccessHelper 数据库读数——相册方向存在媒体库数据库而非文件
    // EXIF，2339.jpg 字节实锤无 EXIF 段但相册显示正）；未传时回退 staged 字节解析。
    // ⚠️ 两套体系并存：媒体库 ORIENTATION 是「需顺时针转正的角度值」（0/90/180/270，IMG_EXIF_DB 实测
    // 2339.jpg 返回 90）——不是 EXIF 1-8 枚举！此前所有轮次都在用枚举映射表处理角度值，全部空转。
    // pixelMap.rotate 正值=顺时针（歪180实测实锤）：媒体库角度即顺时针转正角，同值直转。
    let deg = 0;
    let rawOrientation = 0;
    if (exifOrientation !== undefined && exifOrientation >= 1) {
      rawOrientation = exifOrientation;
      deg = rawOrientation === 90 ? 90 : rawOrientation === 180 ? 180 : rawOrientation === 270 ? 270 : 0;
    } else if (stagedPath.length > 0) {
      try {
        const stageFd = fileIo.openSync(stagedPath, fileIo.OpenMode.READ_ONLY);
        try {
          const size = fileIo.statSync(stageFd.fd).size;
          const buf = new ArrayBuffer(size);
          fileIo.readSync(stageFd.fd, buf);
          rawOrientation = parseExifOrientation(buf);
          deg = exifToCwDeg(rawOrientation);
        } finally {
          fileIo.closeSync(stageFd);
        }
      } catch (e) {
        rawOrientation = 0;
        deg = 0;
      }
    }
    // pixelMap.rotate 正值=顺时针（歪180实测实锤）：staged 路径的 EXIF 顺时针角直接使用。
    if (deg > 0) {
      await pixelMap.rotate(deg);
    }
    console.info('IMG_EXIF raw=' + rawOrientation + ' deg=' + deg);
    // 长边超过 maxEdge 时等比缩小（与 compressAvatar 同模式），避免 4K 原图直传：
    // 上传体积过大不仅拖慢传输，大流量 PUT 后模拟器 rport 通道也更容易出现后续请求异常。
    const info = pixelMap.getImageInfoSync();
    const longEdge: number = Math.max(info.size.width, info.size.height);
    if (longEdge > maxEdge) {
      const ratio: number = maxEdge / longEdge;
      await pixelMap.scale(ratio, ratio);
    }
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
    if (stagedPath.length > 0) {
      try { fileIo.unlinkSync(stagedPath); } catch (e) { /* 清理失败忽略 */ }
    }
  }
}

// 头像专用压缩：限制最长边 maxEdge（默认 512px），避免本地 base64 兜底时体积过大，质量 80%。
// 其余逻辑与 compressImage 一致（file descriptor 打开 photo:// URI）。
export async function compressAvatar(uri: string, maxEdge: number = 512): Promise<CompressedImage> {
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
    // 同 compressImage：EXIF 烘焙，头像同理不旋转。
    try {
      // 宽松解析：部分设备属性值带后缀（如 "8 (left-bottom)"），=== 严格比较会失配导致不烘焙；
      // parseInt 提取首个数字，NaN 按 0 处理。
      const orientation: number = parseInt(await source.getImageProperty(image.PropertyKey.ORIENTATION), 10) || 0;
      // rotate 正值=逆时针（实测）；镜像类（2/4）无旋转角度可修，5/7 仅近似转角。
      const deg: number = orientation === 6 ? 270 : orientation === 3 ? 180
        : orientation === 8 ? 90 : orientation === 5 ? 270 : orientation === 7 ? 90 : 0;
      if (deg > 0) {
        await pixelMap.rotate(deg);
      }
      console.info('IMG_EXIF orientation=' + orientation + ' deg=' + deg);
    } catch (e) {
      // 无 EXIF 或读取失败：按未旋转处理
    }
    const info = pixelMap.getImageInfoSync();
    const longEdge: number = Math.max(info.size.width, info.size.height);
    if (longEdge > maxEdge) {
      const ratio: number = maxEdge / longEdge;
      await pixelMap.scale(ratio, ratio);
    }
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
