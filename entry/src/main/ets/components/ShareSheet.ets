// 分享面板（底部拉起式菜单栏）：
// - 「分享给关注的人」：横向头像行（前 MAX_AVATARS 个 + 「更多」），点头像 → 确认弹窗 →
//   直接发送私信；已分享头像叠加遮罩+对勾防重复，面板保持打开可连续分享多人
// - 「更多」：打开完整联系人面板 ShareToDmSheet（带搜索）
// - 外部分享（卡片/链接/标题/系统分享）受 EXTERNAL_SHARE_ENABLED 控制
// 动态数据通过页面传入的回调闭包读取，避免 CustomDialogController builder 参数在构造期定值的坑。
import { DM_SHARE_ENABLED, EXTERNAL_SHARE_ENABLED } from '../utils/share';
import { Pressable } from '../design/motion/Pressable';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { FollowUser, DmSharePayload } from '../models/types';
import { listFollowing, sendPostShare } from '../services/api';
import { getUserId, getToken } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { resolveActionIcon } from '../utils/actionIcons';
import { AvatarView } from './AvatarView';

// 头像行最多直接展示的关注人数，其余通过「更多」入口进入完整面板
const MAX_AVATARS: number = 9;
const AVATAR_SIZE: number = 40;
const CHIP_WIDTH: number = 56;
const CHIP_HEIGHT: number = 60;

@CustomDialog
export struct ShareSheet {
  controller: CustomDialogController;
  onCopyLink: () => void = (): void => {};
  onCopyTitle: () => void = (): void => {};
  onSystemShare: () => void = (): void => {};
  onShareCard: () => void = (): void => {};
  // 打开完整联系人面板（更多）
  onShareToDm: () => void = (): void => {};
  // 发送时读取当前帖子摘要负载（打开后才取最新值）
  getPayload: () => DmSharePayload | null = (): DmSharePayload | null => null;
  // 单个分享成功后的回调
  onShared: (receiverId: number, nickname: string) => void = (): void => {};

  @State contacts: FollowUser[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State sending: boolean = false;
  @State sendingTo: number = 0;
  @State sharedIds: number[] = [];

  aboutToAppear(): void {
    this.loadContacts();
  }

  // 拉取关注列表（未登录不请求，头像区展示登录提示）；失败进入错误态可重试
  private isLoggedIn(): boolean {
    return getToken() !== '' && getUserId() > 0;
  }

  private async loadContacts(): Promise<void> {
    if (!this.isLoggedIn()) {
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      const res = await listFollowing(getUserId(), 1, 200);
      this.contacts = res.list;
    } catch (e) {
      this.error = (e as Error).message || '加载失败';
    } finally {
      this.loading = false;
    }
  }

  private topContacts(): FollowUser[] {
    return this.contacts.slice(0, MAX_AVATARS);
  }

  private isShared(c: FollowUser): boolean {
    return this.sharedIds.indexOf(c.id ?? 0) >= 0;
  }

  // 点头像：登录校验 → 确认弹窗（分享给{昵称}？）
  private confirmSend(c: FollowUser): void {
    if (!this.isLoggedIn()) {
      safeShowToast(this.getUIContext(), { message: '请先登录后再分享' });
      return;
    }
    const id: number = c.id ?? 0;
    if (id === 0 || this.sending || this.isShared(c)) {
      return;
    }
    const nickname: string = c.nickname ?? '对方';
    this.getUIContext().showAlertDialog({
      title: '分享给' + nickname + '？',
      message: '将以私信形式把该帖子发送给 TA',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '确认分享',
        action: (): void => {
          this.sendTo(c);
        },
      },
    });
  }

  // 确认后直接发送；处理发送中防连点、重复分享、异常兜底
  private async sendTo(c: FollowUser): Promise<void> {
    const id: number = c.id ?? 0;
    if (id === 0 || this.sending || this.isShared(c)) {
      return;
    }
    const payload: DmSharePayload | null = this.getPayload();
    if (!payload) {
      safeShowToast(this.getUIContext(), { message: '帖子数据缺失，无法分享' });
      return;
    }
    this.sending = true;
    this.sendingTo = id;
    try {
      await sendPostShare(id, payload);
      // 标记已分享（防重复发送同一人）
      this.sharedIds = this.sharedIds.concat([id]);
      safeShowToast(this.getUIContext(), { message: '已分享给 ' + (c.nickname ?? '对方') });
      this.onShared(id, c.nickname ?? '');
    } catch (e) {
      // 后端透传：用户不存在/已注销/对方仅接受粉丝或互关的私信等
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.sending = false;
      this.sendingTo = 0;
    }
  }

  @Builder
  divider() {
    Divider()
      .color(ColorTokens.separator)
      .strokeWidth(LayoutTokens.hairlineWidth)
  }

  // 横向分享按钮：圆形浅底图标 + 下方文字（微信/卡牌/链接/标题等）
  @Builder
  shareActionButton(label: string, iconName: string, action: () => void) {
    Pressable({
      visualHeight: 64,
      touchTargetHeight: 64,
      action: (): void => {
        action();
      },
    }) {
      Column({ space: SpaceTokens.xs }) {
        Column() {
          Image(resolveActionIcon(iconName))
            .width(24).height(24)
            .fillColor(ColorTokens.primary)
        }
        .width(48).height(48)
        .backgroundColor(ColorTokens.sunken)
        .borderRadius(RadiusTokens.pill)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        Text(label)
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.secondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 72 })
      }
      .width(72)
      .alignItems(HorizontalAlign.Center)
    }
  }

  // 头像 chip：头像 + 昵称；发送中显示 loading，已分享叠加遮罩+对勾
  @Builder
  avatarChip(c: FollowUser) {
    Pressable({
      visualHeight: CHIP_HEIGHT,
      touchTargetHeight: CHIP_HEIGHT,
      action: (): void => {
        this.confirmSend(c);
      },
    }) {
      Column({ space: SpaceTokens.xs }) {
        Stack() {
          AvatarView({ avatar: c.avatar ?? '', name: c.nickname ?? '', avatarSize: AVATAR_SIZE, ringWidth: 0 })
          if (this.sendingTo === (c.id ?? 0)) {
            Column() {
              LoadingProgress().width(18).height(18)
            }
            .width(AVATAR_SIZE).height(AVATAR_SIZE)
            .borderRadius(AVATAR_SIZE / 2)
            .backgroundColor(ColorTokens.elevated)
            .opacity(0.7)
            .justifyContent(FlexAlign.Center)
          } else if (this.isShared(c)) {
            Column() {
              Image(resolveActionIcon('check'))
                .width(20).height(20)
            }
            .width(AVATAR_SIZE).height(AVATAR_SIZE)
            .borderRadius(AVATAR_SIZE / 2)
            .backgroundColor(ColorTokens.elevated)
            .opacity(0.88)
            .justifyContent(FlexAlign.Center)
          }
        }
        Text(c.nickname ?? '用户')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(this.isShared(c) ? ColorTokens.brand : ColorTokens.tertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: CHIP_WIDTH })
      }
      .width(CHIP_WIDTH)
      .alignItems(HorizontalAlign.Center)
    }
  }

  // 「更多」chip：打开完整联系人面板（带搜索）
  @Builder
  moreChip() {
    Pressable({
      visualHeight: CHIP_HEIGHT,
      touchTargetHeight: CHIP_HEIGHT,
      action: (): void => {
        this.onShareToDm();
      },
    }) {
      Column({ space: SpaceTokens.xs }) {
        Text('···')
          .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.secondary)
          .textAlign(TextAlign.Center)
          .width(AVATAR_SIZE).height(AVATAR_SIZE)
          .backgroundColor(ColorTokens.sunken)
          .borderRadius(AVATAR_SIZE / 2)
        Text('更多')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .maxLines(1)
      }
      .width(CHIP_WIDTH)
      .alignItems(HorizontalAlign.Center)
    }
  }

  // 站内私信分享区：横向头像行（未登录/加载中/失败/空态各有提示）
  @Builder
  dmSection() {
    Column({ space: SpaceTokens.md }) {
      Text('分享给关注的人')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontWeight(TypeTokens.headline.weight)
        .fontColor(ColorTokens.secondary)
        .width('100%')
        .textAlign(TextAlign.Start)

      if (!this.isLoggedIn()) {
        Text('登录后可分享给关注的人')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .width('100%')
          .textAlign(TextAlign.Start)
      } else if (this.loading && this.contacts.length === 0) {
        LoadingProgress().width(24).height(24)
      } else if (this.error !== '' && this.contacts.length === 0) {
        Text('加载失败 · 点击重试')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.brand)
          .height(LayoutTokens.segmentedHeight)
          .textAlign(TextAlign.Start)
          .onClick(() => {
            this.loadContacts();
          })
      } else if (this.contacts.length === 0) {
        Text('还没有关注的人')
          .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.tertiary)
          .width('100%')
          .textAlign(TextAlign.Start)
      } else {
        Scroll() {
          Row({ space: SpaceTokens.sm }) {
            ForEach(
              this.topContacts(),
              (c: FollowUser) => {
                this.avatarChip(c)
              },
              // key 携带已分享/发送中状态，保证状态变化时对应 chip 刷新
              (c: FollowUser) => 'chip-' + String(c.id ?? 0) +
                (this.isShared(c) ? '-shared' : '') +
                (this.sendingTo === (c.id ?? 0) ? '-sending' : ''),
            )
            this.moreChip()
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      // 主菜单卡片：抓手 + 标题 + 选项
      Column() {
        Row()
          .width(36)
          .height(4)
          .backgroundColor(ColorTokens.separator)
          .borderRadius(RadiusTokens.pill)
          .margin({ top: SpaceTokens.md, bottom: SpaceTokens.sm })

        Text('分享到')
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .fontColor(ColorTokens.secondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: SpaceTokens.sm, bottom: SpaceTokens.md })

        // 站内「分享给关注的人」始终可用，优先展示
        if (DM_SHARE_ENABLED) {
          this.dmSection()
        }
        // 外部分享：横向图标+文字按钮排（受落地页就绪状态控制）
        if (EXTERNAL_SHARE_ENABLED) {
          this.divider()
          Row({ space: SpaceTokens.sm }) {
            this.shareActionButton('微信 / 更多', 'shareWechat', this.onSystemShare)
            this.shareActionButton('分享卡片', 'shareCard', this.onShareCard)
            this.shareActionButton('复制链接', 'shareLink', this.onCopyLink)
            this.shareActionButton('复制标题', 'book', this.onCopyTitle)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .padding({ top: SpaceTokens.md, bottom: SpaceTokens.md })
        }
      }
      .width('100%')
      .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, bottom: SpaceTokens.sm })
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.lg)
      .clip(true)

      // 取消按钮：独立卡片，居中，点击即收起
      Column() {
        Pressable({
          fillWidth: true,
          visualHeight: LayoutTokens.minTouchTarget,
          touchTargetHeight: LayoutTokens.minTouchTarget,
          action: (): void => {
            this.controller.close();
          },
        }) {
          Text('取消')
            .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.secondary)
            .width('100%')
            .height(LayoutTokens.minTouchTarget)
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.lg)
      .margin({ top: SpaceTokens.sm })
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, bottom: SpaceTokens.lg })
  }
}
