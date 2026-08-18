import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// 38 个话题标签种子数据（与产品文档 3.1 一致）
const tags = [
  { name: '数码选购', emoji: '📱', category: '消费决策' },
  { name: '汽车买卖', emoji: '🚗', category: '消费决策' },
  { name: '家电评测', emoji: '🏠', category: '消费决策' },
  { name: '外设推荐', emoji: '⌨️', category: '消费决策' },
  { name: '男装搭配', emoji: '👔', category: '消费决策' },
  { name: '运动装备', emoji: '👟', category: '消费决策' },
  { name: '手机数码', emoji: '📲', category: '消费决策' },
  { name: '酒水品鉴', emoji: '🍷', category: '消费决策' },
  { name: '汽车养护', emoji: '🔧', category: '动手实操' },
  { name: '数码维修', emoji: '💻', category: '动手实操' },
  { name: '家居维修', emoji: '🛠️', category: '动手实操' },
  { name: '美食分享', emoji: '🍳', category: '动手实操' },
  { name: '健身动作', emoji: '💪', category: '动手实操' },
  { name: '电脑装机', emoji: '🖥️', category: '动手实操' },
  { name: '摄影技巧', emoji: '📷', category: '动手实操' },
  { name: '露营户外', emoji: '⛺', category: '动手实操' },
  { name: '职场沟通', emoji: '💼', category: '个人成长' },
  { name: '面试经验', emoji: '🎯', category: '个人成长' },
  { name: '搞钱心得', emoji: '💰', category: '个人成长' },
  { name: '理财规划', emoji: '📊', category: '个人成长' },
  { name: '学习效率', emoji: '📚', category: '个人成长' },
  { name: '人际处世', emoji: '🤝', category: '个人成长' },
  { name: '自我提升', emoji: '🚀', category: '个人成长' },
  { name: '旅行攻略', emoji: '✈️', category: '生活方式' },
  { name: '探店打卡', emoji: '🍜', category: '生活方式' },
  { name: '游戏攻略', emoji: '🎮', category: '生活方式' },
  { name: '家庭相处', emoji: '🏡', category: '生活方式' },
  { name: '健康生活', emoji: '🌿', category: '生活方式' },
  { name: '兴趣爱好', emoji: '🎨', category: '生活方式' },
  { name: '影视推荐', emoji: '🎬', category: '分享' },
  { name: '书籍阅读', emoji: '📖', category: '分享' },
  { name: '宠物日常', emoji: '🐕', category: '分享' },
  { name: '情感经营', emoji: '❤️', category: '生活方式' },
  { name: '音乐分享', emoji: '🎵', category: '分享' },
  { name: '日常分享', emoji: '☀️', category: '分享' },
  { name: '播客分享', emoji: '🎙️', category: '分享' },
  { name: '展览活动', emoji: '🖼️', category: '分享' },
  { name: '摄影记录', emoji: '📸', category: '分享' },
];

async function renameLegacyCookingTag(): Promise<void> {
  const legacyName: string = '做饭教程';
  const newName: string = '美食分享';
  const legacyTag = await prisma.tag.findUnique({ where: { name: legacyName } });
  if (!legacyTag) {
    return;
  }

  const posts = await prisma.post.findMany({ select: { id: true, tags: true } });
  await prisma.$transaction(async (tx) => {
    await tx.tag.update({
      where: { name: legacyName },
      data: { name: newName, emoji: '🍳', category: '动手实操' },
    });
    await tx.userFollowTag.updateMany({ where: { tagName: legacyName }, data: { tagName: newName } });
    for (const post of posts) {
      if (!Array.isArray(post.tags) || !post.tags.includes(legacyName)) {
        continue;
      }
      await tx.post.update({
        where: { id: post.id },
        data: { tags: post.tags.map((tag) => tag === legacyName ? newName : tag) },
      });
    }
  });
}

async function main() {
  await renameLegacyCookingTag();
  for (const t of tags) {
    await prisma.tag.upsert({
      where: { name: t.name },
      // 分类调整需要同步到已有标签；使用数和关注数由线上业务维护，不能在种子中覆盖。
      update: { emoji: t.emoji, category: t.category },
      create: t,
    });
  }
  console.log(`Seeded ${tags.length} tags.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
