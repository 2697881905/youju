// 私信聊天页（MVP 仅文字）：
// - 从进程内导航意图读取对端信息（规避 router.getParams 不可靠）
// - 进入即拉历史并标记已读（清私信红点）
// - 发送文字消息（服务端按接收方 dmPolicy + 拉黑做权限校验，越权回中文报错）
// - 发送/已读后自增 dmRefreshSignal，驱动消息页会话列表与红点刷新
import { DmMessage } from '../models/types';
import { getMessages, sendMessage, markMessagesRead } from '../services/api';
import { getToken, getUserId, getCurrentUser } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { AvatarView } from '../components/AvatarView';
import { KeyboardAvoidMode } from '@kit.ArkUI';
import { BackButton } from '../design/components/BackButton';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { openUserProfile, takeChatIntent } from '../utils/nav';

@Entry
@Component
export struct ChatPage {
  @State peerId: number = 0;
  @State peerName: string = '';
  @State peerAvatar: string = '';
  @State myAvatar: string = '';
  @State myName: string = '';
  @State messages: DmMessage[] = [];
  @State loading: boolean = true;
  @State sending: boolean = false;
  @State inputText: string = '';
  @State showEmojiPanel: boolean = false;
  @State error: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  private listScroller: ListScroller = new ListScroller();
  private originalKeyboardMode: KeyboardAvoidMode | null = null;
  private readonly emojiOptions: string[] = ['😀', '😄', '😂', '🥰', '😍', '👍', '🎉', '✨'];

  aboutToAppear(): void {
    const intent = takeChatIntent();
    this.peerId = intent?.peerId ?? 0;
    this.peerName = intent?.peerName ?? '';
    this.peerAvatar = intent?.peerAvatar ?? '';
    const me = getCurrentUser();
    if (me) {
      this.myAvatar = me.avatar ?? '';
      this.myName = me.nickname ?? '';
    }
    this.captureKeyboardAvoidMode();
    if (getToken() !== '' && this.peerId > 0) {
      this.loadMessages();
    }
  }

  // 记录进入前的键盘避让模式，切到 RESIZE（内容区缩放而非整体上移），离页还原，
  // 避免点击输入框弹起键盘时整屏内容被顶上去。
  private captureKeyboardAvoidMode(): void {
    try {
      const ui = this.getUIContext();
      this.originalKeyboardMode = ui.getKeyboardAvoidMode();
      ui.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    } catch (e) {
      // UIContext 未就绪时忽略，不影响消息收发
    }
  }

  aboutToDisappear(): void {
    if (this.originalKeyboardMode !== null) {
      try {
        this.getUIContext().setKeyboardAvoidMode(this.originalKeyboardMode);
      } catch (e) {
        // 忽略
      }
    }
  }

  // 拉历史 + 标记已读（清未读），并触发消息页红点刷新
  async loadMessages(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const res = await getMessages(this.peerId, 1);
      this.messages = res.list;
      await markMessagesRead(this.peerId);
      this.bumpRefreshSignal();
      this.scrollToBottom();
    } catch (e) {
      this.error = (e as Error).message || '加载失败';
    } finally {
      this.loading = false;
    }
  }

  // 自增 dmRefreshSignal，消息页 @Watch 监听后刷新会话列表与未读
  private bumpRefreshSignal(): void {
    const cur: number = (AppStorage.get<number>('dmRefreshSignal') ?? 0) as number;
    AppStorage.setOrCreate('dmRefreshSignal', cur + 1);
  }

  // 发送文字私信
  async onSend(): Promise<void> {
    const text: string = this.inputText.trim();
    if (text.length === 0 || this.sending || this.peerId === 0) {
      return;
    }
    this.sending = true;
    try {
      const msg: DmMessage = await sendMessage(this.peerId, text);
      // 重赋值数组（避免直接 push 触发不了 @State 刷新）
      this.messages = this.messages.concat([msg]);
      this.inputText = '';
      this.bumpRefreshSignal();
      this.scrollToBottom();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.sending = false;
    }
  }

  // 内容就绪后滚到底部（setTimeout 等待一帧布局，规避初始未渲染即滚动失效）
  private scrollToBottom(): void {
    if (this.messages.length === 0) {
      return;
    }
    const index: number = this.messages.length - 1;
    try {
      this.listScroller.scrollToIndex(index, false);
    } catch (e) {
      // 布局未就绪时忽略，用户可手动滚动
    }
    setTimeout(() => {
      try {
        this.listScroller.scrollToIndex(index, false);
      } catch (_) { /* ignore */ }
    }, 80);
  }

  // 聊天内时间：今天显示 HH:MM，更早显示 MM-DD HH:MM
  private formatChatTime(iso?: string): string {
    if (!iso) {
      return '';
    }
    const t: number = new Date(iso).getTime();
    if (isNaN(t)) {
      return '';
    }
    const d: Date = new Date(t);
    const now: Date = new Date();
    const pad = (n: number): string => (n < 10 ? '0' + n : '' + n);
    const hm: string = pad(d.getHours()) + ':' + pad(d.getMinutes());
    const sameDay: boolean =
      d.getFullYear() === now.getFullYear() &&
      d.getMonth() === now.getMonth() &&
      d.getDate() === now.getDate();
    if (sameDay) {
      return hm;
    }
    return pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + hm;
  }

  // 是否为当前用户发出的消息（@Builder 体内禁止声明 const，故抽为方法）
  private isMine(senderId: number): boolean {
    return senderId === getUserId();
  }

  // 点击顶栏头像/昵称 → 跳转对端主页（与评论/帖子头像跳转一致）
  private goPeer(): void {
    if (this.peerId > 0) {
      openUserProfile(this.peerId);
      this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
    }
  }

  private appendEmoji(emoji: string): void {
    this.inputText = this.inputText + emoji;
    this.showEmojiPanel = false;
  }

  @Builder
  emojiPanel() {
    Row({ space: SpaceTokens.sm }) {
      ForEach(
        this.emojiOptions,
        (emoji: string) => {
          Text(emoji)
            .fontSize(22)
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .borderRadius(RadiusTokens.sm)
            .onClick(() => {
              this.appendEmoji(emoji);
            });
        },
        (emoji: string) => emoji,
      )
    }
    .width('100%')
    .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.xs })
    .justifyContent(FlexAlign.Start)
    .backgroundColor(ColorTokens.barSurface)
    .backdropBlur(LayoutTokens.glassBlur)
    .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
    .borderRadius(RadiusTokens.md)
    .shadow({ radius: 10, color: ColorTokens.barShadow, offsetY: 3 });
  }

  @Builder
  messageRow(m: DmMessage) {
    Row({ space: 8 }) {
      // 对方头像（左侧），聊天页保持纯头像，不叠加品牌色头像框。
      if (!this.isMine(m.senderId)) {
        AvatarView({ avatar: this.peerAvatar, name: this.peerName, avatarSize: 36, ringWidth: 0 })
      }

      Column({ space: 4 }) {
        Text(m.content)
          .fontSize(15).fontFamily($r('app.string.font_family'))
          .fontColor(ColorTokens.primary)
          .backgroundColor(this.isMine(m.senderId) ? ColorTokens.barSelectionSurface : ColorTokens.barSurface)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
          .backdropBlur(LayoutTokens.glassBlur)
          .borderRadius(RadiusTokens.md)
          .shadow({ radius: 10, color: ColorTokens.barShadow, offsetY: 3 })
          .constraintSize({ maxWidth: 280, minHeight: 40 })
          .textAlign(TextAlign.Start)
        Text(this.formatChatTime(m.createdAt))
          .fontSize(10).fontFamily($r('app.string.font_family'))
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(this.isMine(m.senderId) ? HorizontalAlign.End : HorizontalAlign.Start)
      .layoutWeight(1)

      // 自己的头像（右侧），与对方保持同样的无边框样式。
      if (this.isMine(m.senderId)) {
        AvatarView({ avatar: this.myAvatar, name: this.myName, avatarSize: 36, ringWidth: 0 })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Row({ space: 8 }) {
          AvatarView({ avatar: this.peerAvatar, name: this.peerName, avatarSize: 32, ringWidth: 0 })
          Text(this.peerName !== '' ? this.peerName : '用户')
            .fontSize(17).fontFamily($r('app.string.font_family'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'));
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.goPeer();
        });
        Text('').width(44);
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 8, bottom: 8 })
      .borderWidth({ bottom: 0.5 })
      .borderColor($r('app.color.divider'));

      // 消息区
      if (this.loading && this.messages.length === 0) {
        Column() {
          LoadingProgress().width(28).height(28);
          Text('加载中…').fontSize(13).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary')).margin({ top: 10 });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else if (this.error !== '' && this.messages.length === 0) {
        Column({ space: 12 }) {
          Text(this.error).fontSize(14).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center);
          Text('点击重试').fontSize(14).fontFamily($r('app.string.font_family')).fontColor($r('app.color.brand_primary')).onClick(() => {
            this.loadMessages();
          });
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center);
      } else {
        List({ space: 8, scroller: this.listScroller }) {
          ForEach(
            this.messages,
            (m: DmMessage) => {
              ListItem() {
                this.messageRow(m);
              }
            },
            (m: DmMessage) => String(m.id),
          )
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 });
      }

      // 输入栏：不设置整行背景，只保留输入框、表情和发送按钮各自的悬浮玻璃层。
      Column({ space: SpaceTokens.sm }) {
        if (this.showEmojiPanel) {
          this.emojiPanel();
        }

        Row({ space: 8 }) {
          TextInput({ text: this.inputText, placeholder: '发条消息…' })
            .fontFamily($r('app.string.font_family'))
            .layoutWeight(1)
            .height(LayoutTokens.minTouchTarget)
            .backgroundColor(ColorTokens.barSurface)
            .backdropBlur(LayoutTokens.glassBlur)
            .borderRadius(RadiusTokens.md)
            .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
            .shadow({ radius: 10, color: ColorTokens.barShadow, offsetY: 3 })
            .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
            .onChange((v: string) => {
              this.inputText = v;
            })
            .onSubmit(() => {
              this.onSend();
            });
          Row() {
            Text('☺')
              .fontSize(22)
              .fontColor(ColorTokens.primary)
          }
            .width(40)
            .height(LayoutTokens.minTouchTarget)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(ColorTokens.barSurface)
            .backdropBlur(LayoutTokens.glassBlur)
            .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.md)
            .shadow({ radius: 10, color: ColorTokens.barShadow, offsetY: 3 })
            .accessibilityText('表情')
            .onClick(() => {
              this.showEmojiPanel = !this.showEmojiPanel;
            });
          Row() {
            Text('发送')
              .fontSize(15)
              .fontFamily($r('app.string.font_family'))
              .fontWeight(600)
              .fontColor(ColorTokens.primary)
          }
            .width(60)
            .height(LayoutTokens.minTouchTarget)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(ColorTokens.barSurface)
            .backdropBlur(LayoutTokens.glassBlur)
            .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.md)
            .shadow({ radius: 10, color: ColorTokens.barShadow, offsetY: 3 })
            .enabled(!this.sending && this.inputText.trim().length > 0)
            .opacity(this.sending || this.inputText.trim().length === 0 ? 0.45 : 1)
            .accessibilityText('发送')
            .onClick(() => {
              this.onSend();
            });
        }
      }
      .width('100%')
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md, top: SpaceTokens.sm, bottom: SpaceTokens.md })
      .margin({ top: SpaceTokens.xs });
    }
    .width('100%')
    .padding({ top: this.statusBarHeight })
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition());
  }
}
