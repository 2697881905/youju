/**
 * 临时验证脚本（可回退）：
 * 把 DB 中图片 URL 的 host 从 LAN(192.168.1.100) 改为 127.0.0.1（云手机隧道可达的本机地址）。
 * 不动文件、不改路径，仅替换 host，用于验证「ArkUI Image 组件能否连 127.0.0.1:3000」。
 * 验证通过后，再写正式迁移（seed picsum 换本机图 + 后端切 local+127.0.0.1）。
 *
 * 用法（backend 目录）：
 *   npx tsx scripts/fix-images-localhost.ts
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const OLD_HOST = '192.168.1.100';
const NEW_HOST = '127.0.0.1';

async function main() {
  let changed = 0;

  const users = await prisma.user.findMany({ select: { id: true, avatar: true } });
  for (const u of users) {
    if (u.avatar && u.avatar.includes(OLD_HOST)) {
      const nv = u.avatar.replace(OLD_HOST, NEW_HOST);
      await prisma.user.update({ where: { id: u.id }, data: { avatar: nv } });
      console.log(`User#${u.id} avatar -> ${nv}`);
      changed++;
    }
  }

  const posts = await prisma.post.findMany({ select: { id: true, coverImage: true, images: true } });
  for (const p of posts) {
    let needUpdate = false;
    let cover = p.coverImage;
    if (cover && cover.includes(OLD_HOST)) {
      cover = cover.replace(OLD_HOST, NEW_HOST);
      needUpdate = true;
    }
    const imgs = p.images as unknown as string[] | null;
    if (Array.isArray(imgs)) {
      let arrChanged = false;
      const newImgs = imgs.map((s) => {
        if (typeof s === 'string' && s.includes(OLD_HOST)) {
          arrChanged = true;
          return s.replace(OLD_HOST, NEW_HOST);
        }
        return s;
      });
      if (arrChanged) {
        (imgs as string[]) && (p.images = newImgs as any);
        needUpdate = true;
      }
    }
    if (needUpdate) {
      await prisma.post.update({
        where: { id: p.id },
        data: { coverImage: cover, images: (imgs as any) ?? undefined },
      });
      console.log(`Post#${p.id} host -> 127.0.0.1`);
      changed++;
    }
  }

  console.log(`\n共修改 ${changed} 条（仅替换 host 192.168.1.100 -> 127.0.0.1，源文件不变）。`);
  console.log('请在云手机重进个人页/重启 App，看头像是否显示，以此验证 Image 能否连 127.0.0.1:3000。');
  console.log('若显示 -> 全面应用本机方案；若仍白 -> Image 组件不走本机隧道，需另寻路径。');
}

main()
  .catch((e) => {
    console.error('执行失败:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
