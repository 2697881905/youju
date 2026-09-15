// 标签名 → 线条图标资源 映射（Apple 风格极简线条 Logo）
// 每个标签独立图标；未匹配时回退到 tag_all（四角星）。
// 用 Map<string, Resource> + 字面量 $r()，既规避 ArkTS 索引访问禁令，
// 又能在编译期校验 23 个资源确实存在。
// 圈子名与 backend/prisma/seed.ts、CircleTab.ets 的 CIRCLE_META 三处保持一致。

const TAG_ICON_MAP: Map<string, Resource> = new Map<string, Resource>([
  // ===== 消费选购 =====
  ['手机数码', $r('app.media.tag_phone_digital')],
  ['家电选购', $r('app.media.tag_appliance_review')],
  ['二手闲置', $r('app.media.tag_daily')],
  ['运动装备', $r('app.media.tag_sports_gear')],
  ['消费维权', $r('app.media.tag_exhibition')],
  // ===== 动手改造 =====
  ['装修避坑', $r('app.media.tag_home_repair')],
  ['家常菜谱', $r('app.media.tag_cooking')],
  ['电脑装机', $r('app.media.tag_pc_build')],
  ['用车经验', $r('app.media.tag_car_trade')],
  // ===== 职场与收入 =====
  ['求职面试', $r('app.media.tag_interview')],
  ['职场成长', $r('app.media.tag_workplace')],
  ['记账储蓄', $r('app.media.tag_finance')],
  ['副业探索', $r('app.media.tag_make_money')],
  // ===== 生活与家庭 =====
  ['恋爱心得', $r('app.media.tag_relationship')],
  ['婚姻与家庭', $r('app.media.tag_family')],
  ['育儿经验', $r('app.media.tag_hobby')],
  ['养猫养狗', $r('app.media.tag_pet')],
  ['健康习惯', $r('app.media.tag_health')],
  ['租房买房', $r('app.media.tag_self_improve')],
  // ===== 兴趣休闲 =====
  ['音乐分享', $r('app.media.tag_music')],
  ['影视剧集', $r('app.media.tag_movie')],
  ['旅行出行', $r('app.media.tag_travel')],
  ['美食探店', $r('app.media.tag_foodie')],
]);

const TAG_ICON_ALL: Resource = $r('app.media.tag_all');

// 标签 Logo 使用稳定的彩色调色板，避免所有入口都退化为同一套黑白线稿。
// 颜色按主题分组而不是随机生成，保证同一标签在不同页面始终一致。
export function resolveTagColor(name: string): ResourceColor {
  switch (name) {
    case '手机数码':
    case '电脑装机':
      return '#0A84FF';
    case '家电选购':
    case '装修避坑':
    case '家常菜谱':
    case '租房买房':
      return '#34C759';
    case '运动装备':
    case '健康习惯':
      return '#30D158';
    case '二手闲置':
    case '用车经验':
    case '旅行出行':
    case '美食探店':
      return '#FF9F0A';
    case '消费维权':
      return '#64D2FF';
    case '求职面试':
    case '职场成长':
    case '记账储蓄':
    case '副业探索':
      return '#5E5CE6';
    case '养猫养狗':
    case '影视剧集':
      return '#BF5AF2';
    case '恋爱心得':
    case '婚姻与家庭':
    case '育儿经验':
    case '音乐分享':
      return '#FF2D55';
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
