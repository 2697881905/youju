// 拉黑管理页：查看/取消拉黑列表（分页加载）
// 采用 design system 令牌（Color/Space/Type/Radius/Icon）+ 共享 Avatar/EmptyState/Pressable，与各二级页 UI 统一。

import { listBlocked, unblockUser } from '../services/api';
import { BlockUser, Pagination } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { openUserProfile } from '../utils/nav';
import { BackButton } from '../design/components/BackButton';
import { Avatar } from '../design/components/Avatar';
import { EmptyState } from '../design/components/EmptyState';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

// 危险操作按钮底色：ds_danger(#FF3B30) 的 ~10% 透明度，与 ds_brand_tint 同 alpha 约定
const DANGER_TINT: string = '#1AFF3B30';

@Entry
@Component
export struct BlocklistPage {
  @State users: BlockUser[] = [];
  @State loadFinished: boolean = false;
  @State loadError: string = '';
  @State loadingMore: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  private pagination: Pagination = { page: 1, limit: 20, total: 0 };

  aboutToAppear(): void {
    this.loadFirst();
  }

  private async loadFirst(): Promise<void> {
    this.loadError = '';
    this.loadFinished = false;
    try {
      const r = await listBlocked(1, 20);
      this.users = r.list;
      this.pagination = r.pagination;
    } catch (e) {
      this.loadError = (e as Error).message;
    }
    this.loadFinished = true;
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore) return;
    if (this.users.length >= this.pagination.total) return;
    this.loadingMore = true;
    try {
      const r = await listBlocked(this.pagination.page + 1, 20);
      for (let i = 0; i < r.list.length; i++) {
        this.users.push(r.list[i]);
      }
      this.pagination = r.pagination;
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
    this.loadingMore = false;
  }

  private onUnblock(user: BlockUser): void {
    this.getUIContext().showAlertDialog({
      title: '取消拉黑？',
      message: '取消后，' + user.nickname + ' 将可以正常与你互动。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: { value: '确认取消', fontColor: $r('app.color.semantic_red'), action: async (): Promise<void> => {
        try {
          await unblockUser(user.id);
          const idx = this.users.indexOf(user);
          if (idx >= 0) {
            this.users.splice(idx, 1);
          }
          safeShowToast(this.getUIContext(), { message: '已取消拉黑' });
        } catch (e) {
          safeShowToast(this.getUIContext(), { message: (e as Error).message });
        }
      } },
    });
  }

  private goProfile(user: BlockUser): void {
    openUserProfile(user.id);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage', params: { userId: String(user.id) } });
  }

  // 拉黑时间格式化：仅取日期部分（YYYY-MM-DD）
  private blockDate(iso: string): string {
    const s: string = iso ?? '';
    return s.length >= 10 ? s.slice(0, 10) : s;
  }

  build() {
    Column() {
      // 顶栏：BackButton + 居中标题（与其它二级页一致）
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Blank()
        Text('拉黑管理')
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .fontColor(ColorTokens.primary)
        Blank()
        Text('')
          .width(LayoutTokens.minTouchTarget)
          .height(LayoutTokens.minTouchTarget)
      }
      .width('100%')
      .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, top: SpaceTokens.md, bottom: SpaceTokens.sm })
      .alignItems(VerticalAlign.Center)

      if (!this.loadFinished) {
        Column({ space: SpaceTokens.item }) {
          LoadingProgress().width(IconTokens.empty).height(IconTokens.empty).color(ColorTokens.secondary)
          Text('正在加载拉黑列表')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.callout.weight)
            .fontColor(ColorTokens.secondary)
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.loadError || this.users.length === 0) {
        Column() {
          EmptyState({
            icon: $r('app.media.empty_inbox'),
            title: this.loadError ? '加载失败' : '暂无拉黑用户',
            message: this.loadError ? this.loadError : '你还没有拉黑任何用户',
            actionLabel: this.loadError ? '重试' : '',
            onAction: (): void => { this.loadFirst(); },
          })
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List({ space: SpaceTokens.none }) {
          ForEach(this.users, (user: BlockUser) => {
            ListItem() {
              Pressable({
                fillWidth: true,
                visualHeight: 64,
                touchTargetHeight: LayoutTokens.minTouchTarget,
                action: (): void => { this.goProfile(user); },
              }) {
                Row({ space: SpaceTokens.md }) {
                  Avatar({ avatar: user.avatar ?? '', name: user.nickname, avatarSize: 44 })
                  Column({ space: SpaceTokens.inlineTight }) {
                    Text(user.nickname)
                      .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
                      .fontWeight(TypeTokens.body.weight)
                      .lineHeight(TypeTokens.body.lineHeight)
                      .fontColor(ColorTokens.primary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text('拉黑于 ' + this.blockDate(user.blockedAt))
                      .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                      .fontWeight(TypeTokens.caption.weight)
                      .lineHeight(TypeTokens.caption.lineHeight)
                      .fontColor(ColorTokens.secondary)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  // 取消拉黑（危险操作，danger 药丸按钮）
                  Pressable({
                    visualHeight: 30,
                    touchTargetHeight: LayoutTokens.minTouchTarget,
                    action: (): void => { this.onUnblock(user); },
                  }) {
                    Text('取消拉黑')
                      .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                      .fontWeight(TypeTokens.callout.weight)
                      .lineHeight(TypeTokens.caption.lineHeight)
                      .fontColor(ColorTokens.danger)
                      .height(30)
                      .padding({ left: SpaceTokens.base, right: SpaceTokens.base })
                      .textAlign(TextAlign.Center)
                      .backgroundColor(DANGER_TINT)
                      .borderRadius(RadiusTokens.pill)
                  }
                }
                .width('100%')
                .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
              }
            }
          }, (user: BlockUser) => user.id.toString());

          // 列表底部：加载更多 / 已加载全部
          ListItem() {
            Row() {
              if (this.users.length < this.pagination.total) {
                Text(this.loadingMore ? '加载中…' : '加载更多')
                  .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                  .fontWeight(TypeTokens.caption.weight)
                  .fontColor(ColorTokens.secondary)
                  .onClick((): void => { this.loadMore(); });
              } else {
                Text('已加载全部')
                  .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
                  .fontWeight(TypeTokens.caption.weight)
                  .fontColor(ColorTokens.tertiary);
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: SpaceTokens.base, bottom: SpaceTokens.base });
          }
        }
        .layoutWeight(1).width('100%')
      }
    }
    .width('100%').padding({ top: this.statusBarHeight }).height('100%')
    .backgroundColor(ColorTokens.canvas)
    .transition(buildPageTransition())
  }
}
