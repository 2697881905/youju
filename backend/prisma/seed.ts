import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// 30 个话题标签种子数据（与产品文档 3.1 一致）
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
  { name: '做饭教程', emoji: '🍳', category: '动手实操' },
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
  { name: '影视推荐', emoji: '🎬', category: '生活方式' },
  { name: '书籍阅读', emoji: '📖', category: '生活方式' },
  { name: '宠物日常', emoji: '🐕', category: '生活方式' },
  { name: '情感经营', emoji: '❤️', category: '生活方式' },
];

async function main() {
  for (const t of tags) {
    await prisma.tag.upsert({
      where: { name: t.name },
      update: {},
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
