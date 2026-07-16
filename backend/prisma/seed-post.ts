// 种子：创建一条真实测评报告帖子 + 作者 + 评论，用于联调详情页渲染
// 运行：node_modules/.bin/tsx prisma/seed-post.ts
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const SEED_TITLE = 'iPhone 17 Pro 深度使用30天报告';

async function main() {
  // 1. 作者
  const user = await prisma.user.upsert({
    where: { openId: 'dev-seed-openid' },
    update: {},
    create: {
      openId: 'dev-seed-openid',
      nickname: '科技老张',
      avatar: 'https://i.pravatar.cc/150?img=12',
      gender: 1,
    },
  });

  // 2. 避免重复：已存在则跳过
  const existed = await prisma.post.findFirst({ where: { title: SEED_TITLE } });
  if (existed) {
    console.log(`已存在种子帖 id=${existed.id}，跳过创建。`);
    return;
  }

  // 3. 帖子（测评报告，已发布）
  const post = await prisma.post.create({
    data: {
      userId: user.id,
      title: SEED_TITLE,
      content:
        '用了整整 30 天，从续航、影像、系统流畅度到重量手感都踩了一遍。\n' +
        '结论：重度手机用户值得上，但价格确实劝退一部分人。下面把优缺点和适合人群讲清楚。',
      coverImage: 'https://picsum.photos/seed/bb-review-cover/800/800',
      images: [
        'https://picsum.photos/seed/bb-review-1/800/800',
        'https://picsum.photos/seed/bb-review-2/800/800',
        'https://picsum.photos/seed/bb-review-3/800/800',
        'https://picsum.photos/seed/bb-review-4/800/800',
      ],
      genre: 'review',
      tags: ['数码选购', '手机数码'],
      structuredData: {
        pros: '续航强、系统流畅、影像天花板',
        cons: '重量偏重、价格高',
        rating: 4.5,
        targetAudience: '重度手机用户 / 摄影党',
      },
      upCount: 236,
      bookmarkCount: 89,
      commentCount: 0,
      status: 1,
    },
  });

  // 4. 评论（一条普通、一条事实补充）
  await prisma.comment.create({
    data: {
      postId: post.id,
      userId: user.id,
      content: '续航这块我实测一天一充没问题，重度使用也扛得住。',
      isFact: 0,
      upCount: 12,
    },
  });
  await prisma.comment.create({
    data: {
      postId: post.id,
      userId: user.id,
      content: '补充一个缺点：充电头要单独买，包装里只有线。',
      isFact: 1,
      upCount: 31,
    },
  });

  // 同步评论数
  const commentCount = await prisma.comment.count({ where: { postId: post.id } });
  await prisma.post.update({ where: { id: post.id }, data: { commentCount } });

  console.log(`种子帖创建成功 id=${post.id}，作者 id=${user.id}，评论数=${commentCount}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
