// 设置页 → 线条图标资源映射（Apple 风格极简线条 Logo）
// 与 tagIcons.ets / actionIcons.ets 同源：Map<string, Resource> + 字面量 $r()，
// 规避 ArkTS 索引访问禁令，编译期校验资源存在。

const SETTINGS_ICONS: Map<string, Resource> = new Map<string, Resource>([
  // 导航 / 复用主界面线条图标
  ['back', $r('app.media.nav_back')],
  ['gear', $r('app.media.set_gear')],
  ['phone', $r('app.media.device_phone')],
  ['lock', $r('app.media.status_lock')],
  ['book', $r('app.media.book_doc')],
  ['chevronRight', $r('app.media.chevron_right')],
  // 设置项专属
  ['edit', $r('app.media.set_edit')],
  ['block', $r('app.media.set_block')],
  ['export', $r('app.media.set_export')],
  ['bell', $r('app.media.set_bell')],
  ['system', $r('app.media.set_system')],
  ['dark', $r('app.media.set_dark')],
  ['trash', $r('app.media.set_trash')],
  ['policy', $r('app.media.set_policy')],
  ['logout', $r('app.media.set_logout')],
  ['shield', $r('app.media.set_shield')],
]);

// 按名称解析设置页图标资源；未命中回退 chevronRight（箭头），避免空白
export function resolveSettingsIcon(name: string): Resource {
  const found: Resource | undefined = SETTINGS_ICONS.get(name);
  if (found !== undefined) {
    return found;
  }
  return $r('app.media.chevron_right');
}

// 设置项 Logo 使用语义化颜色；导航返回和箭头仍保持文字层级色。
export function resolveSettingsIconColor(name: string): ResourceColor {
  switch (name) {
    case 'gear':
    case 'phone':
    case 'book':
      return '#0A84FF';
    case 'lock':
    case 'policy':
      return '#5E5CE6';
    case 'bell':
    case 'export':
      return '#FF9500';
    case 'system':
      return '#34C759';
    case 'dark':
      return '#AF52DE';
    case 'block':
      return '#FF2D55';
    case 'shield':
      return '#64D2FF';
    case 'edit':
      return '#30D158';
    case 'trash':
    case 'logout':
      return $r('app.color.semantic_red');
    case 'back':
      return $r('app.color.text_primary');
    default:
      return $r('app.color.text_tertiary');
  }
}
