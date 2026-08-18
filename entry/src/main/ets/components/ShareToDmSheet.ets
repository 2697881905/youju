// 分享到私信：联系人选择弹窗（底部 bottom sheet）
// - 拉取「我关注的贴主」列表（FollowUser），仅展示已关注的人
// - 顶部搜索框按昵称过滤，快速定位目标贴主
// - 点击贴主即把当前帖子以私信形式发送给对方；发送中禁用防连点，已分享标记防重复
// - 成功/失败均有 toast 反馈；对方不存在/已注销/权限不足等由后端中文报错透传
import { FollowUser, DmSharePayload } from '../models/types';
import { listFollowing, sendPostShare } from '../services/api';
import { getUserId } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { AvatarView } from '../components/AvatarView';
import { EmptyState } from '../design/components/EmptyState';
import { resolveActionIcon } from '../utils/actionIcons';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@CustomDialog
export struct ShareToDmSheet {
  controller: CustomDialogController;
  // 由分享发起页在打开时传入：读取当前帖子摘要负载（打开后才取最新值）
  getPayload: () => DmSharePayload | null = (): DmSharePayload | null => null;
  // 单个分享成功后的回调（可选）
  onShared: (receiverId: number, nickname: string) => void = (): void => {};

  @State contacts: FollowUser[] = [];
  @State keyword: string = '';
  @State loading: boolean = false;
  @State error: string = '';
  @State sending: boolean = false;
  @State sendingTo: number = 0;
  @State sharedIds: number[] = [];

  aboutToAppear(): void {
    this.loadContacts();
  }

  // 按昵称过滤（不区分大小写；空关键词返回全部）
  private filtered(): FollowUser[] {
    const kw: string = this.keyword.trim().toLowerCase();
    if (kw.length === 0) {
      return this.contacts;
    }
    const out: FollowUser[] = [];
    for (const c of this.contacts) {
      const name: string = (c.nickname ?? '').toLowerCase();
      if (name.indexOf(kw) >= 0) {
        out.push(c);
      }
    }
    return out;
  }

  // 拉取关注列表（仅已关注贴主）；失败进入错误态可重试
  private async loadContacts(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const myId: number = getUserId();
      const res = await listFollowing(myId, 1, 200);
      this.contacts = res.list;
    } catch (e) {
      this.error = (e as Error).message || '加载失败';
    } finally {
      this.loading = false;
    }
  }

  // 把当前帖子分享给指定贴主；处理加载态、重复分享、异常兜底
  private async shareTo(c: FollowUser): Promise<void> {
    const id: number = c.id ?? 0;
    if (id === 0 || this.sending || this.sharedIds.indexOf(id) >= 0) {
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
      // 标记已分享（防重复发送同一贴主）
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
  contactRow(c: FollowUser) {
    Row({ space: 12 }) {
      AvatarView({ avatar: c.avatar ?? '', name: c.nickname ?? '', avatarSize: 40, ringWidth: 0 })
      Column({ space: 3 }) {
        Text(c.nickname ?? '用户')
          .fontSize(15).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
        if (c.bio !== null && c.bio !== undefined && c.bio.length > 0) {
          Text(c.bio)
            .fontSize(12).fontFamily(TypeTokens.fontFamily)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 右侧状态：已分享标记 / 发送中进度
      if (this.sharedIds.indexOf(c.id ?? 0) >= 0) {
        Text('已分享')
          .fontSize(12).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.brand)
      } else if (this.sendingTo === (c.id ?? 0)) {
        LoadingProgress().width(18).height(18)
      }
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .onClick(() => {
      this.shareTo(c);
    })
  }

  build() {
    Column() {
      // 顶栏：标题 + 完成
      Row() {
        Text('分享给关注的人')
          .fontSize(17).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.title.weight)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text('完成')
          .fontSize(15).fontFamily(TypeTokens.fontFamily)
          .fontColor(ColorTokens.brand)
          .padding({ left: 12, right: 4 })
          .onClick(() => {
            this.controller.close();
          })
      }
      .width('100%')
      .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, top: SpaceTokens.md, bottom: SpaceTokens.sm })

      // 搜索框（昵称过滤）
      TextInput({ text: this.keyword, placeholder: '搜索昵称' })
        .fontFamily(TypeTokens.fontFamily)
        .placeholderColor($r('app.color.text_secondary'))
        .height(40)
        .backgroundColor(ColorTokens.sunken)
        .borderRadius(RadiusTokens.md)
        .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
        .onChange((v: string) => {
          this.keyword = v;
        })
        .margin({ left: SpaceTokens.lg, right: SpaceTokens.lg, bottom: SpaceTokens.sm })

      // 列表区
      if (this.loading && this.contacts.length === 0) {
        Column() {
          LoadingProgress().width(28).height(28)
          Text('加载中…')
            .fontSize(13).fontFamily(TypeTokens.fontFamily)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 10 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.error !== '' && this.contacts.length === 0) {
        Column({ space: 12 }) {
          Text(this.error)
            .fontSize(14).fontFamily(TypeTokens.fontFamily)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
          Text('点击重试')
            .fontSize(14).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.brand)
            .onClick(() => {
              this.loadContacts();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.contacts.length === 0) {
        EmptyState({
          icon: resolveActionIcon('send'),
          title: '还没有关注的人',
          message: '去关注感兴趣的贴主后，就能把帖子分享给 TA',
        })
      } else if (this.filtered().length === 0) {
        EmptyState({
          title: '未找到匹配的人',
          message: '换个关键词试试',
        })
      } else {
        List({ space: 0 }) {
          ForEach(
            this.filtered(),
            (c: FollowUser) => {
              ListItem() {
                this.contactRow(c);
              }
              .borderWidth({ bottom: 0.5 })
              .borderColor($r('app.color.divider'))
            },
            (c: FollowUser) => String(c.id ?? 0),
          )
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg })
      }
    }
    .width('100%')
    .height('72%')
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}
