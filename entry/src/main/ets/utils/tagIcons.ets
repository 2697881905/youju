// 标签名 → 线条图标资源 映射（Apple 风格极简线条 Logo）
// 每个标签独立图标；未匹配时回退到 tag_all（四角星）。
// 用 Map<string, Resource> + 字面量 $r()，既规避 ArkTS 索引访问禁令，
// 又能在编译期校验 23 个资源确实存在。
// 圈子名与 backend/prisma/seed.ts、CircleTab.ets 的 CIRCLE_META 三处保持一致。

const TAG_ICON_MAP: Map<string, Resource> = new Map<string, Resource>([
  // ===== 买之前问问 =====
  ['手机平板', $r('app.media.tag_phone_digital')],
  ['家电大件', $r('app.media.tag_appliance_review')],
  ['二手闲置', $r('app.media.tag_daily')],
  ['运动装备', $r('app.media.tag_sports_gear')],
  ['退货维权', $r('app.media.tag_exhibition')],
  ['薅羊毛', $r('app.media.tag_make_money')],
  // ===== 自己动手 =====
  ['装修避坑', $r('app.media.tag_home_repair')],
  ['做饭实录', $r('app.media.tag_cooking')],
  ['电脑装机', $r('app.media.tag_pc_build')],
  ['修修补补', $r('app.media.tag_digital_repair')],
  ['车的事', $r('app.media.tag_car_trade')],
  // ===== 上班搞钱 =====
  ['简历面试', $r('app.media.tag_interview')],
  ['跳槽谈薪', $r('app.media.tag_workplace')],
  ['记账攒钱', $r('app.media.tag_finance')],
  ['副业变现', $r('app.media.tag_make_money')],
  // ===== 过日子 =====
  ['租房经验', $r('app.media.tag_family')],
  ['养猫养狗', $r('app.media.tag_pet')],
  ['看病就医', $r('app.media.tag_health')],
  ['带娃日常', $r('app.media.tag_hobby')],
  ['相亲恋爱', $r('app.media.tag_relationship')],
  // ===== 下班以后 =====
  ['探店实测', $r('app.media.tag_foodie')],
  ['旅行避坑', $r('app.media.tag_travel')],
  ['追剧刷片', $r('app.media.tag_movie')],
]);

const TAG_ICON_ALL: Resource = $r('app.media.tag_all');

// 标签 Logo 使用稳定的彩色调色板，避免所有入口都退化为同一套黑白线稿。
// 颜色按主题分组而不是随机生成，保证同一标签在不同页面始终一致。
export function resolveTagColor(name: string): ResourceColor {
  switch (name) {
    case '手机平板':
    case '电脑装机':
    case '修修补补':
      return '#0A84FF';
    case '家电大件':
    case '装修避坑':
    case '做饭实录':
    case '租房经验':
      return '#34C759';
    case '运动装备':
    case '看病就医':
      return '#30D158';
    case '二手闲置':
    case '车的事':
    case '探店实测':
    case '旅行避坑':
      return '#FF9F0A';
    case '退货维权':
      return '#64D2FF';
    case '薅羊毛':
    case '简历面试':
    case '跳槽谈薪':
    case '记账攒钱':
    case '副业变现':
      return '#5E5CE6';
    case '养猫养狗':
    case '追剧刷片':
      return '#BF5AF2';
    case '带娃日常':
    case '相亲恋爱':
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
