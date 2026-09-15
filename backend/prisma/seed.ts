import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// 23 个圈子种子（与前端 CircleTab.ets 的 CIRCLE_META、utils/tagIcons.ets 三处保持一致）。
// 分类口语化：买之前问问 / 自己动手 / 上班搞钱 / 过日子 / 下班以后。
const tags = [
  // ===== 买之前问问 =====
  { name: '手机平板', emoji: '📱', category: '买之前问问' },
  { name: '家电大件', emoji: '🧊', category: '买之前问问' },
  { name: '二手闲置', emoji: '♻️', category: '买之前问问' },
  { name: '运动装备', emoji: '👟', category: '买之前问问' },
  { name: '退货维权', emoji: '🧾', category: '买之前问问' },
  { name: '薅羊毛', emoji: '🐑', category: '买之前问问' },
  // ===== 自己动手 =====
  { name: '装修避坑', emoji: '🚚', category: '自己动手' },
  { name: '做饭实录', emoji: '🍳', category: '自己动手' },
  { name: '电脑装机', emoji: '🖥️', category: '自己动手' },
  { name: '修修补补', emoji: '🪚', category: '自己动手' },
  { name: '车的事', emoji: '🚗', category: '自己动手' },
  // ===== 上班搞钱 =====
  { name: '简历面试', emoji: '📄', category: '上班搞钱' },
  { name: '跳槽谈薪', emoji: '💼', category: '上班搞钱' },
  { name: '记账攒钱', emoji: '🧮', category: '上班搞钱' },
  { name: '副业变现', emoji: '💰', category: '上班搞钱' },
  // ===== 过日子 =====
  { name: '租房经验', emoji: '🏠', category: '过日子' },
  { name: '养猫养狗', emoji: '🐱', category: '过日子' },
  { name: '看病就医', emoji: '🏥', category: '过日子' },
  { name: '带娃日常', emoji: '🍼', category: '过日子' },
  { name: '相亲恋爱', emoji: '❤️', category: '过日子' },
  // ===== 下班以后 =====
  { name: '探店实测', emoji: '🍜', category: '下班以后' },
  { name: '旅行避坑', emoji: '🧳', category: '下班以后' },
  { name: '追剧刷片', emoji: '🎬', category: '下班以后' },
];

// 清理不在清单内的旧标签。Tag 被 Post.tags（字符串数组）与 UserFollowTag.tagName
// 以字符串弱关联、无外键约束；仅当两者都为空时才执行删除，避免破坏已有内容。
async function removeStaleTags(): Promise<void> {
  const valid = new Set(tags.map((t) => t.name));
  const all = await prisma.tag.findMany({ select: { name: true } });
  const stale = all.filter((t) => !valid.has(t.name)).map((t) => t.name);
  if (stale.length === 0) {
    return;
  }
  const postCount = await prisma.post.count();
  const followCount = await prisma.userFollowTag.count();
  if (postCount > 0 || followCount > 0) {
    console.warn(`[seed] 已有 ${postCount} 帖 / ${followCount} 个标签关注，跳过删除 ${stale.length} 个旧标签（请人工确认关联后再清）。`);
    return;
  }
  await prisma.tag.deleteMany({ where: { name: { in: stale } } });
  console.log(`[seed] 已移除 ${stale.length} 个旧标签：${stale.join('、')}`);
}

async function main() {
  await removeStaleTags();
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
