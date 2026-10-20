// 冷启动内容库的圈子目录。
//
// 23 个圈子在仓库里已有四处硬编码（prisma/seed.ts、CircleTab.ets 的 CIRCLE_META、
// utils/tagIcons.ets、tagService.ts 的分类白名单）。造数脚本再抄一份只会多一处漂移，
// 所以这里只声明「造数需要的三样东西」——slug（文件名/帖子 id 前缀）、圈子中文名、
// 目标条数——其余（emoji、分类）按 name 从 seed.ts 的同一份清单里对齐，测试里再做一致性校验。
//
// 条数是产品决策，不是估算：热圈多冷圈少，总量 331。

export interface CircleCatalogEntry {
  slug: string;
  name: string;
  category: string;
  targetPosts: number;
}

export const CIRCLE_CATALOG: CircleCatalogEntry[] = [
  { slug: 'shuma', name: '手机数码', category: '消费选购', targetPosts: 18 },
  { slug: 'jiadian', name: '家电选购', category: '消费选购', targetPosts: 15 },
  { slug: 'ershou', name: '二手闲置', category: '消费选购', targetPosts: 14 },
  { slug: 'yundong', name: '运动装备', category: '消费选购', targetPosts: 13 },
  { slug: 'weiquan', name: '消费维权', category: '消费选购', targetPosts: 13 },
  { slug: 'zhuangxiu', name: '装修避坑', category: '动手改造', targetPosts: 18 },
  { slug: 'caipu', name: '家常菜谱', category: '动手改造', targetPosts: 16 },
  { slug: 'zhuangji', name: '电脑装机', category: '动手改造', targetPosts: 14 },
  { slug: 'yongche', name: '用车经验', category: '动手改造', targetPosts: 14 },
  { slug: 'qiuzhi', name: '求职面试', category: '职场与收入', targetPosts: 18 },
  { slug: 'zhichang', name: '职场成长', category: '职场与收入', targetPosts: 16 },
  { slug: 'jizhang', name: '记账储蓄', category: '职场与收入', targetPosts: 13 },
  { slug: 'fuye', name: '副业探索', category: '职场与收入', targetPosts: 13 },
  { slug: 'lianai', name: '恋爱心得', category: '生活与家庭', targetPosts: 16 },
  { slug: 'hunyin', name: '婚姻与家庭', category: '生活与家庭', targetPosts: 13 },
  { slug: 'yuer', name: '育儿经验', category: '生活与家庭', targetPosts: 13 },
  { slug: 'chongwu', name: '养猫养狗', category: '生活与家庭', targetPosts: 15 },
  { slug: 'jiankang', name: '健康习惯', category: '生活与家庭', targetPosts: 12 },
  { slug: 'zufang', name: '租房买房', category: '生活与家庭', targetPosts: 15 },
  { slug: 'yinyue', name: '音乐分享', category: '兴趣休闲', targetPosts: 12 },
  { slug: 'yingshi', name: '影视剧集', category: '兴趣休闲', targetPosts: 13 },
  { slug: 'lvxing', name: '旅行出行', category: '兴趣休闲', targetPosts: 13 },
  { slug: 'meishi', name: '美食探店', category: '兴趣休闲', targetPosts: 14 },
];

export const CIRCLE_NAMES: string[] = CIRCLE_CATALOG.map((c) => c.name);

export const CIRCLE_BY_NAME: Map<string, CircleCatalogEntry> = new Map(
  CIRCLE_CATALOG.map((c) => [c.name, c]),
);

export const CIRCLE_BY_SLUG: Map<string, CircleCatalogEntry> = new Map(
  CIRCLE_CATALOG.map((c) => [c.slug, c]),
);

export const TOTAL_TARGET_POSTS: number = CIRCLE_CATALOG.reduce((sum, c) => sum + c.targetPosts, 0);

// 圈子到结构化文档主题的映射。只影响详情页信息流的第一屏观感，不参与排序。
const THEME_BY_CATEGORY: Record<string, 'editorial' | 'warm' | 'cool'> = {
  消费选购: 'editorial',
  动手改造: 'cool',
  职场与收入: 'cool',
  生活与家庭: 'warm',
  兴趣休闲: 'editorial',
};

export function themeForCircle(circleName: string): 'editorial' | 'warm' | 'cool' {
  const entry = CIRCLE_BY_NAME.get(circleName);
  if (!entry) return 'editorial';
  return THEME_BY_CATEGORY[entry.category] ?? 'editorial';
}
