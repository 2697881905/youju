// ListItemGroup 卡片底板统一样式 —— UI 统一化工程基准（设置页分组三件套）。
// 圆角 CARD_RADIUS（= RadiusTokens.lg 20）+ card_bg 底色（浅 #F7F7F8 / 深 #1E1E1E）+ clip 裁剪。
// 官方 @Extend 仅限当前文件使用、不支持导出（UI 范式指南 2026-11），跨文件样式复用一律走
// AttributeModifier（官方「组件公共样式封装」推荐路径）。无状态样式，实例可安全跨组件复用。
import { CARD_RADIUS } from './cardTokens';

export class GroupCardStyle implements AttributeModifier<ListItemGroupAttribute> {
  applyNormalAttribute(instance: ListItemGroupAttribute): void {
    instance.borderRadius(CARD_RADIUS);
    instance.backgroundColor($r('app.color.card_bg'));
    instance.clip(true);
  }
}