// 标签名 → 线条图标资源 映射（极简线条 Logo）
// 每个标签独立图标；未匹配时按分类回退，再回退 tag_all（四角星）。
// 用 Map<string, Resource> + 字面量 $r()，既规避 ArkTS 索引访问禁令，
// 又能在编译期校验 23 个资源确实存在。
import {
  CIRCLE_CATEGORY_CAREER,
  CIRCLE_CATEGORY_CITY,
  CIRCLE_CATEGORY_CONSUMER,
  CIRCLE_CATEGORY_DIY,
  CIRCLE_CATEGORY_INTEREST,
  CIRCLE_CATEGORY_LIFE,
  categoryHue,
  tagCategory,
} from '../design/tokens/category';

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

// 新圈/未收录圈按分类回退：至少让人看出“这是哪一类”，而不是所有新圈共用一颗 ✦。
const CATEGORY_ICON_MAP: Map<string, Resource> = new Map<string, Resource>([
  [CIRCLE_CATEGORY_CONSUMER, $r('app.media.tag_phone_digital')],
  [CIRCLE_CATEGORY_DIY, $r('app.media.tag_home_repair')],
  [CIRCLE_CATEGORY_CAREER, $r('app.media.tag_workplace')],
  [CIRCLE_CATEGORY_LIFE, $r('app.media.tag_family')],
  [CIRCLE_CATEGORY_INTEREST, $r('app.media.tag_hobby')],
  [CIRCLE_CATEGORY_CITY, $r('app.media.tag_all')],
]);

// 标签 Logo 颜色 = 所属分类的低饱和色相；深色模式自动提亮。
// category 为空时按名字归组，兼容首页/发布页等旧调用。
export function resolveTagColor(name: string, category?: string, dark: boolean = false): ResourceColor {
  const resolvedCategory: string = category !== undefined && category.length > 0 ? category : tagCategory(name);
  return categoryHue(resolvedCategory, dark);
}

// 按标签名解析线条图标资源；未命中先按分类回退，再回退 tag_all。
export function resolveTagIcon(name: string, category?: string): Resource {
  const found: Resource | undefined = TAG_ICON_MAP.get(name);
  if (found !== undefined) {
    return found;
  }
  if (category !== undefined) {
    const fallback: Resource | undefined = CATEGORY_ICON_MAP.get(category);
    if (fallback !== undefined) {
      return fallback;
    }
  }
  return TAG_ICON_ALL;
}
