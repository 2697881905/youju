import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// 23 个圈子种子（与前端 CircleTab.ets 的 CIRCLE_META、utils/tagIcons.ets 三处保持一致）。
// 分类：消费选购 / 动手改造 / 职场与收入 / 生活与家庭 / 兴趣休闲。
// 设计约束：不设医疗诊疗、投资荐股等专业门槛高、容错率低的领域（合规与内容质量风险）。
const tags = [
  // ===== 消费选购 =====
  { name: '手机数码', emoji: '📱', category: '消费选购', description: '真机用满三个月再写，不吹参数只讲日常' },
  { name: '家电选购', emoji: '🧊', category: '消费选购', description: '买过才知道的「早知道就不买」，一件件说清' },
  { name: '二手闲置', emoji: '♻️', category: '消费选购', description: '从挂出去到收钱的完整过程，坑和技巧都在这' },
  { name: '运动装备', emoji: '👟', category: '消费选购', description: '跑过骑过穿过之后，留下的和吃灰的都写' },
  { name: '消费维权', emoji: '🧾', category: '消费选购', description: '被坑了怎么办：退换、投诉、举证的实际流程' },
  // ===== 动手改造 =====
  { name: '装修避坑', emoji: '🛠️', category: '动手改造', description: '装完才发现的坑，写下来给下一个人省点钱' },
  { name: '家常菜谱', emoji: '🍳', category: '动手改造', description: '失败过几次才敢写，火候和用量都标清楚' },
  { name: '电脑装机', emoji: '🖥️', category: '动手改造', description: '配置单、踩雷件、装完跑分，一步一步记' },
  { name: '用车经验', emoji: '🚗', category: '动手改造', description: '开几年才知道的事，保养和故障都算' },
  // ===== 职场与收入 =====
  { name: '求职面试', emoji: '📄', category: '职场与收入', description: '面过哪些岗、被问了什么、事后怎么复盘' },
  { name: '职场成长', emoji: '💼', category: '职场与收入', description: '真实职场里的选择题，做对了也做错过' },
  { name: '记账储蓄', emoji: '🧮', category: '职场与收入', description: '记了多久、钱花在哪、哪笔最后悔' },
  { name: '副业探索', emoji: '💰', category: '职场与收入', description: '试过的方向、真实投入产出、值不值得继续' },
  // ===== 生活与家庭 =====
  { name: '恋爱心得', emoji: '❤️', category: '生活与家庭', description: '相处里真实发生的事，好的坏的不加滤镜' },
  { name: '婚姻与家庭', emoji: '💍', category: '生活与家庭', description: '长期关系里的琐碎与选择，没有标准答案' },
  { name: '育儿经验', emoji: '🍼', category: '生活与家庭', description: '带娃试出来的办法，有效和没效的都写' },
  { name: '养猫养狗', emoji: '🐱', category: '生活与家庭', description: '养之前该知道的，和养之后才知道的' },
  { name: '健康习惯', emoji: '💪', category: '生活与家庭', description: '坚持过、中断过、又重新开始的那些事' },
  { name: '租房买房', emoji: '🏠', category: '生活与家庭', description: '看房、签约、搬家、维权，每一步的实感' },
  // ===== 兴趣休闲 =====
  { name: '音乐分享', emoji: '🎵', category: '兴趣休闲', description: '最近反复在听的，和它们为什么值得一听' },
  { name: '影视剧集', emoji: '🎬', category: '兴趣休闲', description: '看完想聊两句的，不写简介只写感受' },
  { name: '旅行出行', emoji: '🧳', category: '兴趣休闲', description: '走过的地方、花过的钱、值不值这一趟' },
  { name: '美食探店', emoji: '🍜', category: '兴趣休闲', description: '为了一碗面坐一小时地铁，值不值' },
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
      // 预置圈的简介由种子维护；用户自建圈不在这里（不在 tags 清单内），不会被覆盖。
      update: { emoji: t.emoji, category: t.category, description: t.description },
      create: t,
    });
  }
  console.log(`Seeded ${tags.length} tags.`);

  // 同城维（星图子模式「降落地球」）：每座白名单城市预置一个官方同城广场圈，
  // 零冷启动——用户选完城市立刻有内容容器。幂等：存在即跳过，计数交还线上业务。
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { SUPPORTED_CITIES } = require('../src/utils/cities');
  let seededCities = 0;
  for (const c of SUPPORTED_CITIES) {
    const exists = await prisma.tag.findUnique({ where: { name: `${c.name}同城` } });
    if (exists) {
      continue;
    }
    await prisma.tag.create({
      data: {
        name: `${c.name}同城`,
        emoji: '🏙️',
        category: '同城',
        description: `${c.name}的真实经验，同在这座城的人一起聊`,
        cityCode: c.code,
      },
    });
    seededCities += 1;
  }
  console.log(`Seeded ${seededCities} city circles.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
