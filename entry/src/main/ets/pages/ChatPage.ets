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
import { CARD_RADIUS } from '../utils/cardTokens';
import { AvatarView } from '../components/AvatarView';
import { KeyboardAvoidMode } from '@kit.ArkUI';
import { resolveActionIcon } from '../utils/actionIcons';
import { BackButton } from '../design/components/BackButton';
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
  @State error: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  private listScroller: ListScroller = new ListScroller();
  private originalKeyboardMode: KeyboardAvoidMode | null = null;

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

  @Builder
  messageRow(m: DmMessage) {
    Row({ space: 8 }) {
      // 对方头像（左侧），用 AvatarView 保证头像内容完全落在品牌色圆环框内
      if (!this.isMine(m.senderId)) {
        AvatarView({ avatar: this.peerAvatar, name: this.peerName, avatarSize: 36, ringWidth: 2 })
      }

      Column({ space: 4 }) {
        Text(m.content)
          .fontSize(15).fontFamily($r('app.string.font_family'))
          .fontColor(this.isMine(m.senderId) ? Color.White : $r('app.color.text_primary'))
          .backgroundColor(this.isMine(m.senderId) ? $r('app.color.brand_primary') : $r('app.color.card_bg'))
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius(CARD_RADIUS)
          .constraintSize({ maxWidth: 260 })
          .textAlign(TextAlign.Start)
        Text(this.formatChatTime(m.createdAt))
          .fontSize(10).fontFamily($r('app.string.font_family'))
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(this.isMine(m.senderId) ? HorizontalAlign.End : HorizontalAlign.Start)
      .layoutWeight(1)

      // 自己的头像（右侧），与对方对称
      if (this.isMine(m.senderId)) {
        AvatarView({ avatar: this.myAvatar, name: this.myName, avatarSize: 36, ringWidth: 2 })
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
          AvatarView({ avatar: this.peerAvatar, name: this.peerName, avatarSize: 32, ringWidth: 2 })
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

      // 输入栏
      Row({ space: 8 }) {
        TextInput({ text: this.inputText, placeholder: '发条消息…' })
          .fontFamily($r('app.string.font_family'))
          .layoutWeight(1)
          .height(40)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(8)
          .border({ width: 0.5, color: $r('app.color.divider'), style: BorderStyle.Solid })
          .padding({ left: 12, right: 12 })
          .onChange((v: string) => {
            this.inputText = v;
          })
          .onSubmit(() => {
            this.onSend();
          });
        Row() {
          Image(resolveActionIcon('send'))
            .width(20)
            .height(20)
            .fillColor(this.inputText.trim().length > 0 ? Color.White : $r('app.color.text_tertiary'))
        }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .borderRadius(8)
          .backgroundColor(this.inputText.trim().length > 0 ? $r('app.color.brand_primary') : $r('app.color.control_bg'))
          .enabled(!this.sending && this.inputText.trim().length > 0)
          .accessibilityText('发送')
          .onClick(() => {
            this.onSend();
          });
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      .backgroundColor($r('app.color.bg_primary'))
      .borderWidth({ top: 0.5 })
      .borderColor($r('app.color.divider'));
    }
    .width('100%')
    .padding({ top: this.statusBarHeight })
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition());
  }
}
