/**
 * 将当前 COS/CDN 的历史 URL 转为 cos://<key>。
 * 默认只输出统计；必须显式传 --apply 才会写数据库。执行前先完成数据库备份。
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const apply = process.argv.includes('--apply');
const bucket = process.env.COS_BUCKET ?? '';
const cdnBase = process.env.COS_CDN_BASE ?? '';
const folders = /^(avatars|backgrounds|posts|video)\/[A-Za-z0-9_./-]+$/;

function allowedHosts(): Set<string> {
  const hosts = new Set<string>();
  if (bucket) {
    hosts.add(bucket + '.cos.' + (process.env.COS_REGION ?? '') + '.myqcloud.com');
  }
  if (cdnBase) {
    try {
      hosts.add(new URL(cdnBase).host);
    } catch {
      throw new Error('COS_CDN_BASE 不是有效 URL');
    }
  }
  return hosts;
}

function toMediaRef(value: string, hosts: Set<string>): string {
  if (value.startsWith('cos://')) {
    return value;
  }
  try {
    const url = new URL(value);
    if (!hosts.has(url.host)) {
      return value;
    }
    const key = decodeURIComponent(url.pathname).replace(/^\/+/, '');
    return folders.test(key) && !key.includes('..') ? 'cos://' + key : value;
  } catch {
    return value;
  }
}

function convertArray(value: unknown, hosts: Set<string>): { value: unknown; changed: boolean } {
  if (!Array.isArray(value)) {
    return { value, changed: false };
  }
  let changed = false;
  const next = value.map((item) => {
    if (typeof item !== 'string') {
      return item;
    }
    const converted = toMediaRef(item, hosts);
    changed = changed || converted !== item;
    return converted;
  });
  return { value: next, changed };
}

async function main(): Promise<void> {
  if (!bucket && !cdnBase) {
    throw new Error('请配置 COS_BUCKET 或 COS_CDN_BASE 后再运行迁移');
  }
  const hosts = allowedHosts();
  let changedUsers = 0;
  let changedPosts = 0;

  const users = await prisma.user.findMany({ select: { id: true, avatar: true, profileBackground: true } });
  for (const user of users) {
    const avatar = user.avatar ? toMediaRef(user.avatar, hosts) : user.avatar;
    const profileBackground = user.profileBackground ? toMediaRef(user.profileBackground, hosts) : user.profileBackground;
    if (avatar === user.avatar && profileBackground === user.profileBackground) {
      continue;
    }
    changedUsers++;
    if (apply) {
      await prisma.user.update({ where: { id: user.id }, data: { avatar, profileBackground } });
    }
  }

  const posts = await prisma.post.findMany({
    select: { id: true, coverImage: true, videoUrl: true, videoCover: true, images: true },
  });
  for (const post of posts) {
    const coverImage = post.coverImage ? toMediaRef(post.coverImage, hosts) : post.coverImage;
    const videoUrl = post.videoUrl ? toMediaRef(post.videoUrl, hosts) : post.videoUrl;
    const videoCover = post.videoCover ? toMediaRef(post.videoCover, hosts) : post.videoCover;
    const images = convertArray(post.images, hosts);
    if (coverImage === post.coverImage && videoUrl === post.videoUrl && videoCover === post.videoCover && !images.changed) {
      continue;
    }
    changedPosts++;
    if (apply) {
      await prisma.post.update({ where: { id: post.id }, data: { coverImage, videoUrl, videoCover, images: images.value as any } });
    }
  }

  console.log((apply ? '已迁移' : 'Dry run') + ': User=' + changedUsers + ', Post=' + changedPosts);
  if (!apply) {
    console.log('核对样本和数据库备份后，使用 --apply 执行写入。');
  }
}

main().catch((error) => {
  console.error('媒体引用迁移失败:', error);
  process.exitCode = 1;
}).finally(async () => {
  await prisma.$disconnect();
});
