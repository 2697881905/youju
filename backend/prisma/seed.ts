import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// 23 个圈子种子（与前端 CircleTab.ets 的 CIRCLE_META、utils/tagIcons.ets 三处保持一致）。
// 分类：消费选购 / 动手改造 / 职场与收入 / 生活与家庭 / 兴趣休闲。
// 设计约束：不设医疗诊疗、投资荐股等专业门槛高、容错率低的领域（合规与内容质量风险）。
const tags = [
  // ===== 消费选购 =====
  { name: '手机数码', emoji: '📱', category: '消费选购' },
  { name: '家电选购', emoji: '🧊', category: '消费选购' },
  { name: '二手闲置', emoji: '♻️', category: '消费选购' },
  { name: '运动装备', emoji: '👟', category: '消费选购' },
  { name: '消费维权', emoji: '🧾', category: '消费选购' },
  // ===== 动手改造 =====
  { name: '装修避坑', emoji: '🛠️', category: '动手改造' },
  { name: '家常菜谱', emoji: '🍳', category: '动手改造' },
  { name: '电脑装机', emoji: '🖥️', category: '动手改造' },
  { name: '用车经验', emoji: '🚗', category: '动手改造' },
  // ===== 职场与收入 =====
  { name: '求职面试', emoji: '📄', category: '职场与收入' },
  { name: '职场成长', emoji: '💼', category: '职场与收入' },
  { name: '记账储蓄', emoji: '🧮', category: '职场与收入' },
  { name: '副业探索', emoji: '💰', category: '职场与收入' },
  // ===== 生活与家庭 =====
  { name: '恋爱心得', emoji: '❤️', category: '生活与家庭' },
  { name: '婚姻与家庭', emoji: '💍', category: '生活与家庭' },
  { name: '育儿经验', emoji: '🍼', category: '生活与家庭' },
  { name: '养猫养狗', emoji: '🐱', category: '生活与家庭' },
  { name: '健康习惯', emoji: '💪', category: '生活与家庭' },
  { name: '租房买房', emoji: '🏠', category: '生活与家庭' },
  // ===== 兴趣休闲 =====
  { name: '音乐分享', emoji: '🎵', category: '兴趣休闲' },
  { name: '影视剧集', emoji: '🎬', category: '兴趣休闲' },
  { name: '旅行出行', emoji: '🧳', category: '兴趣休闲' },
  { name: '美食探店', emoji: '🍜', category: '兴趣休闲' },
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
