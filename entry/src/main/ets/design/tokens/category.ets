// 圈子分类色板：把原来 24 个 iOS 高饱和色收敛成 5 个低饱和分类色 + 同城暖金。
// 只用于图标/小面积色块；主文字、背景、按钮仍走 ColorTokens。
// 深色模式用同一色相提亮，保证线条图标在墨底上可读。

export const CIRCLE_CATEGORY_CONSUMER: string = '消费选购';
export const CIRCLE_CATEGORY_DIY: string = '动手改造';
export const CIRCLE_CATEGORY_CAREER: string = '职场与收入';
export const CIRCLE_CATEGORY_LIFE: string = '生活与家庭';
export const CIRCLE_CATEGORY_INTEREST: string = '兴趣休闲';
export const CIRCLE_CATEGORY_CITY: string = '同城';

// 按名字归组：没有分类字段的旧调用（首页/发布页）也能拿到稳定色相。
export function tagCategory(name: string): string {
  switch (name) {
    case '手机数码':
    case '家电选购':
    case '二手闲置':
    case '运动装备':
    case '消费维权':
      return CIRCLE_CATEGORY_CONSUMER;
    case '装修避坑':
    case '家常菜谱':
    case '电脑装机':
    case '用车经验':
      return CIRCLE_CATEGORY_DIY;
    case '求职面试':
    case '职场成长':
    case '记账储蓄':
    case '副业探索':
      return CIRCLE_CATEGORY_CAREER;
    case '恋爱心得':
    case '婚姻与家庭':
    case '育儿经验':
    case '养猫养狗':
    case '健康习惯':
    case '租房买房':
      return CIRCLE_CATEGORY_LIFE;
    case '音乐分享':
    case '影视剧集':
    case '旅行出行':
    case '美食探店':
      return CIRCLE_CATEGORY_INTEREST;
    default:
      return '';
  }
}

export function categoryHue(category: string, dark: boolean): string {
  if (category === CIRCLE_CATEGORY_CITY) {
    return dark ? '#D9A441' : '#A06400';
  }
  switch (category) {
    case CIRCLE_CATEGORY_CONSUMER:
      return dark ? '#8FB0C9' : '#4F6B85';
    case CIRCLE_CATEGORY_DIY:
      return dark ? '#9DB88B' : '#5F7A52';
    case CIRCLE_CATEGORY_CAREER:
      return dark ? '#9EA8CC' : '#5B6488';
    case CIRCLE_CATEGORY_LIFE:
      return dark ? '#D0A090' : '#9B6A5A';
    case CIRCLE_CATEGORY_INTEREST:
      return dark ? '#BFA6D2' : '#8A6F9E';
    default:
      return dark ? '#A8A094' : '#6B6358';
  }
}
