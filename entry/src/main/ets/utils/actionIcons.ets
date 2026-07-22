// 动作 / 状态 / 通知类型 → 线条图标资源 映射（Apple 风格极简线条 Logo）
// 与 tagIcons.ets 同源：用 Map<string, Resource> + 字面量 $r()，
// 既规避 ArkTS 索引访问禁令，又能在编译期校验资源确实存在。

import { NotificationType } from '../models/types';

const ACTION_ICONS: Map<string, Resource> = new Map<string, Resource>([
  // 动作
  ['like', $r('app.media.action_like')],
  ['comment', $r('app.media.action_comment')],
  ['bookmark', $r('app.media.action_bookmark')],
  ['share', $r('app.media.action_share')],
  ['follow', $r('app.media.action_follow')],
  // 通知类型
  ['system', $r('app.media.notification_system')],
  // 状态 / 空态
  ['lock', $r('app.media.status_lock')],
  ['warning', $r('app.media.status_warning')],
  ['guide', $r('app.media.empty_guide')],
  ['inbox', $r('app.media.empty_inbox')],
  ['search', $r('app.media.empty_search')],
  // 导航 / 控件
  ['back', $r('app.media.nav_back')],
  ['close', $r('app.media.close_x')],
  ['chevronDown', $r('app.media.chevron_down')],
  ['chevronUp', $r('app.media.chevron_up')],
  ['phone', $r('app.media.device_phone')],
  ['book', $r('app.media.book_doc')],
  ['check', $r('app.media.check_round')],
]);

// 按动作名解析线条图标资源；未命中回退 close（x）
export function resolveActionIcon(name: string): Resource {
  const found: Resource | undefined = ACTION_ICONS.get(name);
  if (found !== undefined) {
    return found;
  }
  return $r('app.media.close_x');
}

// 通知类型 → 图标资源（ArkTS V1 不支持 obj[key] 索引访问，用 switch 分发）
export function notifIconRes(type: NotificationType | undefined): Resource {
  const t: NotificationType = type ?? 'system';
  switch (t) {
    case 'comment':
      return $r('app.media.action_comment');
    case 'up':
      return $r('app.media.action_like');
    case 'bookmark':
      return $r('app.media.action_bookmark');
    case 'follow':
      return $r('app.media.action_follow');
    default:
      return $r('app.media.notification_system');
  }
}
