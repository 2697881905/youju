/**
 * 诊断脚本 v2（只读，不改动数据）：
 * 1) 分类 Post.coverImage / Post.images / User.avatar 全部 URL：cos / external / lan / relative
 * 2) 打印前若干条真实 URL 样本（让你和我都能看到具体形态）
 * 3) 对公网 URL(cos/external) 做本机 HTTP 可达性测试：
 *    - 本机通 → URL 本身有效；云手机若仍不显示 = 云手机出网/ArkUI Image 问题
 *    - 本机不通 → 预签名/凭据/源文件问题
 *    - lan/relative 本机测通无意义（云手机网络隔离），只标「需迁移」
 *
 * 用法（backend 目录）：
 *   npx tsx scripts/diag-images.ts
 */
import { PrismaClient } from '@prisma/client';
import * as path from 'path';
import * as fs from 'fs';

const prisma = new PrismaClient();

const LAN_PATTERNS = [
  /192\.168\.\d+\.\d+/,
  /10\.\d+\.\d+\.\d+/,
  /172\.(1[6-9]|2\d|3[01])\.\d+\.\d+/,
  /localhost/,
  /127\.0\.0\.1/,
];

type Cat = 'cos' | 'external' | 'lan' | 'relative' | 'empty';

function classify(url: string): Cat {
  if (!url) return 'empty';
  if (url.includes('myqcloud.com')) return 'cos';
  if (url.startsWith('/uploads/') || url.startsWith('uploads/')) return 'relative';
  if (LAN_PATTERNS.some((p) => p.test(url))) return 'lan';
  if (/^https?:\/\//.test(url)) return 'external';
  return 'relative';
}

function localPathFor(url: string): string | null {
  try {
    const u = new URL(url, 'http://localhost');
    const p = decodeURIComponent(u.pathname);
    if (p.startsWith('/uploads/')) return path.join(process.cwd(), p);
    return null;
  } catch {
    return null;
  }
}

async function reachable(url: string): Promise<string> {
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 6000);
    const r = await fetch(url, { method: 'HEAD', signal: ctrl.signal });
    clearTimeout(t);
    return `HTTP ${r.status}`;
  } catch (e: any) {
    return `ERR ${e?.name ?? e?.message ?? 'unknown'}`;
  }
}

interface NeedItem {
  type: string;
  id: string;
  field: string;
  url: string;
  localPath: string | null;
  fileExists: boolean | null;
}

async function main() {
  const stats: Record<Cat, number> = { cos: 0, external: 0, lan: 0, relative: 0, empty: 0 };
  const needs: NeedItem[] = [];

  console.log('===== 帖子图片样本（前8条，含本机可达性）=====');
  const posts = await prisma.post.findMany({ select: { id: true, coverImage: true, images: true }, take: 200 });
  for (const post of posts.slice(0, 8)) {
    const urls: { f: string; u: string }[] = [];
    if (post.coverImage) urls.push({ f: 'coverImage', u: post.coverImage });
    if (Array.isArray(post.images)) {
      for (const img of post.images as unknown as string[]) {
        if (typeof img === 'string' && img) urls.push({ f: 'images[]', u: img });
      }
    }
    for (const { f, u } of urls) {
      const c = classify(u);
      stats[c]++;
      const reach = c === 'lan' || c === 'relative' ? '(需迁移,本机测无意义)' : await reachable(u);
      console.log(`Post#${post.id}.${f} [${c}] ${reach}`);
      console.log(`   ${u}`);
      if (c === 'lan' || c === 'relative') {
        const lp = localPathFor(u);
        needs.push({ type: 'Post', id: String(post.id), field: f, url: u, localPath: lp, fileExists: lp ? fs.existsSync(lp) : null });
      }
    }
  }

  console.log('');
  console.log('===== 用户头像样本（前8）=====');
  const users = await prisma.user.findMany({ select: { id: true, avatar: true }, take: 200 });
  for (const user of users.slice(0, 8)) {
    if (!user.avatar) continue;
    const c = classify(user.avatar);
    stats[c]++;
    const reach = c === 'lan' || c === 'relative' ? '(需迁移,本机测无意义)' : await reachable(user.avatar);
    console.log(`User#${user.id}.avatar [${c}] ${reach}`);
    console.log(`   ${user.avatar}`);
    if (c === 'lan' || c === 'relative') {
      const lp = localPathFor(user.avatar);
      needs.push({ type: 'User', id: String(user.id), field: 'avatar', url: user.avatar, localPath: lp, fileExists: lp ? fs.existsSync(lp) : null });
    }
  }

  console.log('');
  console.log('===== 全量分类统计 =====');
  console.log(`COS 公网链接 (OK):        ${stats.cos}`);
  console.log(`外链 (picsum等):         ${stats.external}`);
  console.log(`局域网 IP (需迁移):      ${stats.lan}`);
  console.log(`相对路径 /uploads(需迁移): ${stats.relative}`);
  console.log(`空值:                    ${stats.empty}`);

  console.log('');
  if (needs.length === 0) {
    console.log('✅ 没有需迁移到 COS 的本地/局域网图片。');
    console.log('   若云手机仍空白，问题在 external 外链被云手机网络拦截，或 COS 公网在云手机不可达（看上面样本可达性）。');
  } else {
    console.log(`===== 需迁移明细（共 ${needs.length} 条）=====`);
    for (const n of needs) {
      const fstat = n.fileExists === null ? '无本地路径' : n.fileExists ? '本地文件✅' : '本地文件❌缺失';
      console.log(`[${n.type}#${n.id}.${n.field}] ${n.url}`);
      console.log(`   本地源: ${n.localPath ?? '(无)'}  (${fstat})`);
    }
  }
}

main()
  .catch((e) => {
    console.error('诊断失败:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
