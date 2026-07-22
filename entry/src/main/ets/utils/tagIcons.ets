// 标签名 → 线条图标资源 映射（Apple 风格极简线条 Logo）
// 每个标签独立图标；未匹配时回退到 tag_all（四角星）。
// 用 Map<string, Resource> + 字面量 $r()，既规避 ArkTS 索引访问禁令，
// 又能在编译期校验 36 个资源确实存在。

const TAG_ICON_MAP: Map<string, Resource> = new Map<string, Resource>([
  // ===== 消费决策 =====
  ['数码选购', $r('app.media.tag_digital_shopping')],
  ['汽车买卖', $r('app.media.tag_car_trade')],
  ['家电评测', $r('app.media.tag_appliance_review')],
  ['外设推荐', $r('app.media.tag_peripheral')],
  ['男装搭配', $r('app.media.tag_menswear')],
  ['运动装备', $r('app.media.tag_sports_gear')],
  ['手机数码', $r('app.media.tag_phone_digital')],
  ['酒水品鉴', $r('app.media.tag_wine')],
  // ===== 动手实操 =====
  ['汽车养护', $r('app.media.tag_car_care')],
  ['数码维修', $r('app.media.tag_digital_repair')],
  ['家居维修', $r('app.media.tag_home_repair')],
  ['做饭教程', $r('app.media.tag_cooking')],
  ['健身动作', $r('app.media.tag_fitness')],
  ['电脑装机', $r('app.media.tag_pc_build')],
  ['摄影技巧', $r('app.media.tag_photography')],
  ['露营户外', $r('app.media.tag_camping')],
  // ===== 个人成长 =====
  ['职场沟通', $r('app.media.tag_workplace')],
  ['面试经验', $r('app.media.tag_interview')],
  ['搞钱心得', $r('app.media.tag_make_money')],
  ['理财规划', $r('app.media.tag_finance')],
  ['学习效率', $r('app.media.tag_study')],
  ['人际处世', $r('app.media.tag_social')],
  ['自我提升', $r('app.media.tag_self_improve')],
  // ===== 生活方式 =====
  ['旅行攻略', $r('app.media.tag_travel')],
  ['探店打卡', $r('app.media.tag_foodie')],
  ['游戏攻略', $r('app.media.tag_gaming')],
  ['影视推荐', $r('app.media.tag_movie')],
  ['书籍阅读', $r('app.media.tag_reading')],
  ['宠物日常', $r('app.media.tag_pet')],
  ['情感经营', $r('app.media.tag_relationship')],
]);

const TAG_ICON_ALL: Resource = $r('app.media.tag_all');

// 按标签名解析线条图标资源；未命中回退 tag_all
export function resolveTagIcon(name: string): Resource {
  const found: Resource | undefined = TAG_ICON_MAP.get(name);
  if (found !== undefined) {
    return found;
  }
  return TAG_ICON_ALL;
}
