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
  ['美食分享', $r('app.media.tag_cooking')],
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
  ['情感经营', $r('app.media.tag_relationship')],
  ['家庭相处', $r('app.media.tag_family')],
  ['健康生活', $r('app.media.tag_health')],
  ['兴趣爱好', $r('app.media.tag_hobby')],
  // ===== 分享 =====
  ['音乐分享', $r('app.media.tag_music')],
  ['日常分享', $r('app.media.tag_daily')],
  ['影视推荐', $r('app.media.tag_movie')],
  ['书籍阅读', $r('app.media.tag_reading')],
  ['宠物日常', $r('app.media.tag_pet')],
  ['播客分享', $r('app.media.tag_podcast')],
  ['展览活动', $r('app.media.tag_exhibition')],
  ['摄影记录', $r('app.media.tag_photography')],
]);

const TAG_ICON_ALL: Resource = $r('app.media.tag_all');

// 标签 Logo 使用稳定的彩色调色板，避免所有入口都退化为同一套黑白线稿。
// 颜色按主题分组而不是随机生成，保证同一标签在不同页面始终一致。
export function resolveTagColor(name: string): ResourceColor {
  switch (name) {
    case '数码选购':
    case '手机数码':
    case '数码维修':
    case '电脑装机':
      return '#0A84FF';
    case '汽车买卖':
    case '汽车养护':
      return '#FF9500';
    case '家电评测':
    case '家居维修':
    case '美食分享':
      return '#34C759';
    case '外设推荐':
    case '游戏攻略':
    case '影视推荐':
      return '#AF52DE';
    case '男装搭配':
    case '情感经营':
    case '人际处世':
    case '家庭相处':
      return '#FF2D55';
    case '运动装备':
    case '健身动作':
    case '露营户外':
      return '#30D158';
    case '酒水品鉴':
    case '探店打卡':
    case '旅行攻略':
      return '#FF9F0A';
    case '职场沟通':
    case '面试经验':
    case '搞钱心得':
    case '理财规划':
      return '#5E5CE6';
    case '学习效率':
    case '自我提升':
    case '书籍阅读':
      return '#64D2FF';
    case '摄影技巧':
    case '摄影记录':
    case '宠物日常':
      return '#BF5AF2';
    case '健康生活':
      return '#30D158';
    case '兴趣爱好':
      return '#AF52DE';
    case '播客分享':
      return '#5E5CE6';
    case '展览活动':
      return '#FF9500';
    case '音乐分享':
      return '#FF2D55';
    case '日常分享':
      return '#FF9F0A';
    default:
      return '#0A84FF';
  }
}

// 按标签名解析线条图标资源；未命中回退 tag_all
export function resolveTagIcon(name: string): Resource {
  const found: Resource | undefined = TAG_ICON_MAP.get(name);
  if (found !== undefined) {
    return found;
  }
  return TAG_ICON_ALL;
}
