// 私信聊天页（文字 + 图片/视频）：
// - 从进程内导航意图读取对端信息（规避 router.getParams 不可靠）
// - 进入即拉历史并标记已读（清私信红点）
// - 发送文字消息（服务端按接收方 dmPolicy + 拉黑做权限校验，越权回中文报错）
// - 输入栏最左「+」弹出媒体菜单（发送图片/发送视频）：相册选择 → COS 上传 → 以 image/video 消息发送
// - 发送/已读后自增 dmRefreshSignal，驱动消息页会话列表与红点刷新
import { DmMessage, User, DmSharePayload } from '../models/types';
import { getMessages, sendMessage, markMessagesRead, uploadChatMedia, resolveDisplayImageUrl } from '../services/api';
import { getToken, getUserId, getCurrentUser, ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { compressImage, CompressedImage } from '../utils/image';
import { AvatarView } from '../components/AvatarView';
import { VideoPlayer } from '../components/VideoPlayer';
import { KeyboardAvoidMode } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { BackButton } from '../design/components/BackButton';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { TypeTokens } from '../design/tokens/type';
import { openUserProfile, takeChatIntent, openPostDetail } from '../utils/nav';

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
  @State sendingMedia: boolean = false;
  @State inputText: string = '';
  @State showEmojiPanel: boolean = false;
  @State showMediaMenu: boolean = false;
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
    this.showMediaMenu = false;
    const text: string = this.inputText.trim();
    if (text.length === 0 || this.sending || this.peerId === 0) {
      return;
    }
    this.sending = true;
    try {
      const msg: DmMessage = await sendMessage(this.peerId, text, 'text');
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

  // 发送前先确认登录（上传接口需 Bearer token）
  private async ensureLoggedIn(): Promise<boolean> {
    try {
      const u: User | null = await ensureLogin();
      return u !== null;
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '登录失败，无法发送：' + ((e as Error).message ?? '未知错误') });
      return false;
    }
  }

  // 发送图片：相册单选 → 压缩 → COS 上传 → 以 image 消息发送
  private async sendImage(): Promise<void> {
    this.showMediaMenu = false;
    if (this.sendingMedia || this.peerId === 0) {
      return;
    }
    if (!(await this.ensureLoggedIn())) {
      return;
    }
    this.sendingMedia = true;
    try {
      const ph = new photoAccessHelper.PhotoViewPicker();
      const res = await ph.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
      });
      const uris: string[] = res.photoUris ?? [];
      if (uris.length === 0) {
        return; // 用户取消选择，静默收起
      }
      const compressed: CompressedImage = await compressImage(uris[0]);
      const url: string = await uploadChatMedia('image/jpeg', 'posts', compressed.bytes);
      const msg: DmMessage = await sendMessage(this.peerId, url, 'image');
      this.messages = this.messages.concat([msg]);
      this.bumpRefreshSignal();
      this.scrollToBottom();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '图片发送失败：' + ((e as Error).message ?? '未知错误') });
    } finally {
      this.sendingMedia = false;
    }
  }

  // 发送视频：相册单选 → 读文件 → COS 上传 → 以 video 消息发送
  private async sendVideo(): Promise<void> {
    this.showMediaMenu = false;
    if (this.sendingMedia || this.peerId === 0) {
      return;
    }
    if (!(await this.ensureLoggedIn())) {
      return;
    }
    this.sendingMedia = true;
    try {
      const ph = new photoAccessHelper.PhotoViewPicker();
      const res = await ph.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE,
        maxSelectNumber: 1,
      });
      const uris: string[] = res.photoUris ?? [];
      if (uris.length === 0) {
        return; // 用户取消选择，静默收起
      }
      const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
      try {
        const stat = fileIo.statSync(file.fd);
        const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buffer);
        const url: string = await uploadChatMedia('video/mp4', 'video', buffer);
        const msg: DmMessage = await sendMessage(this.peerId, url, 'video');
        this.messages = this.messages.concat([msg]);
        this.bumpRefreshSignal();
        this.scrollToBottom();
      } finally {
        fileIo.closeSync(file);
      }
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '视频发送失败：' + ((e as Error).message ?? '未知错误') });
    } finally {
      this.sendingMedia = false;
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

  // 「+」媒体菜单：发送图片 / 发送视频（样式与表情面板一致）
  @Builder
  mediaMenu() {
    Column({ space: SpaceTokens.xs }) {
      Row({ space: SpaceTokens.sm }) {
        Text('🖼️')
          .fontSize(18)
        Text('发送图片')
          .fontSize(15).fontFamily($r('app.string.font_family'))
          .fontColor(ColorTokens.primary)
        Blank()
      }
      .width('100%')
      .height(LayoutTokens.minTouchTarget)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      .alignItems(VerticalAlign.Center)
      .accessibilityText('发送图片')
      .onClick(() => {
        this.sendImage();
      });

      Row({ space: SpaceTokens.sm }) {
        Text('🎬')
          .fontSize(18)
        Text('发送视频')
          .fontSize(15).fontFamily($r('app.string.font_family'))
          .fontColor(ColorTokens.primary)
        Blank()
      }
      .width('100%')
      .height(LayoutTokens.minTouchTarget)
      .padding({ left: SpaceTokens.md, right: SpaceTokens.md })
      .alignItems(VerticalAlign.Center)
      .accessibilityText('发送视频')
      .onClick(() => {
        this.sendVideo();
      });
    }
    .width('100%')
    .padding({ top: SpaceTokens.xs, bottom: SpaceTokens.xs })
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
        if (m.type === 'image') {
          Image(resolveDisplayImageUrl(m.content))
            .width(200)
            .constraintSize({ maxHeight: 300 })
            .objectFit(ImageFit.Auto)
            .backgroundColor(ColorTokens.sunken)
            .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
            .borderRadius(RadiusTokens.md)
            .clip(true)
            .shadow({ radius: 10, color: ColorTokens.barShadow, offsetY: 3 })
        } else if (m.type === 'video') {
          Stack({ alignContent: Alignment.Center }) {
            VideoPlayer({ src: m.content, poster: m.content })
              .width(200)
              .aspectRatio(1.2)
            Text('▶')
              .fontSize(28)
              .fontColor(Color.White)
              .backgroundColor('#66000000')
              .width(44)
              .height(44)
              .textAlign(TextAlign.Center)
              .borderRadius(22)
          }
          .width(200)
          .borderRadius(RadiusTokens.md)
          .clip(true)
          .shadow({ radius: 10, color: ColorTokens.barShadow, offsetY: 3 })
        } else if (m.type === 'share') {
          this.shareBubble(m)
        } else {
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
        }
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

  // 解析分享负载（content 为 JSON，解析失败返回 null → 下方降级为纯文本）
  private parseShare(m: DmMessage): DmSharePayload | null {
    try {
      const obj: Object = JSON.parse(m.content);
      const o = obj as Record<string, Object>;
      if (typeof o['postId'] === 'number' && typeof o['title'] === 'string') {
        return {
          postId: o['postId'] as number,
          title: o['title'] as string,
          summary: typeof o['summary'] === 'string' ? (o['summary'] as string) : '',
          coverImage: typeof o['coverImage'] === 'string' ? (o['coverImage'] as string) : '',
          authorName: typeof o['authorName'] === 'string' ? (o['authorName'] as string) : '',
          authorId: typeof o['authorId'] === 'number' ? (o['authorId'] as number) : 0,
        };
      }
    } catch (e) {
      // 解析失败：下方降级为纯文本
    }
    return null;
  }

  private shareHasCover(m: DmMessage): boolean {
    const p = this.parseShare(m);
    return p !== null && p.coverImage.length > 0;
  }

  private shareCover(m: DmMessage): string {
    const p = this.parseShare(m);
    return p !== null ? p.coverImage : '';
  }

  private shareTitle(m: DmMessage): string {
    const p = this.parseShare(m);
    return p !== null ? p.title : '分享的帖子';
  }

  private shareSummary(m: DmMessage): string {
    const p = this.parseShare(m);
    return p !== null ? p.summary : '';
  }

  private sharePostId(m: DmMessage): number {
    const p = this.parseShare(m);
    return p !== null ? p.postId : 0;
  }

  // 分享气泡：封面 + 标题 + 摘要 + 查看原帖入口（@Builder 体内不声明 const，改用私有方法取值）
  @Builder
  shareBubble(m: DmMessage) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        if (this.shareHasCover(m)) {
          Image(resolveDisplayImageUrl(this.shareCover(m)))
            .width(64)
            .height(64)
            .objectFit(ImageFit.Cover)
            .borderRadius(RadiusTokens.sm)
            .clip(true)
        }
        Column({ space: 4 }) {
          Text(this.shareTitle(m))
            .fontSize(14).fontFamily($r('app.string.font_family'))
            .fontWeight(TypeTokens.callout.weight)
            .fontColor(ColorTokens.primary)
            .maxLines(2)
          if (this.shareSummary(m).length > 0) {
            Text(this.shareSummary(m))
              .fontSize(12).fontFamily($r('app.string.font_family'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(2)
          }
          Row({ space: 4 }) {
            Text('查看原帖')
              .fontSize(11).fontFamily($r('app.string.font_family'))
              .fontColor(ColorTokens.brand)
            Text('›')
              .fontSize(11).fontFamily($r('app.string.font_family'))
              .fontColor(ColorTokens.brand)
          }
          .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width(240)
    .padding(10)
    .backgroundColor(ColorTokens.barSurface)
    .backdropBlur(LayoutTokens.glassBlur)
    .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
    .borderRadius(RadiusTokens.md)
    .shadow({ radius: 10, color: ColorTokens.barShadow, offsetY: 3 })
    .onClick(() => {
      this.openSharedPost(this.sharePostId(m));
    })
  }

  // 点击分享卡片 → 跳转原帖详情
  private openSharedPost(postId: number): void {
    if (postId > 0) {
      openPostDetail(String(postId));
      this.getUIContext().getRouter().pushUrl({ url: 'pages/DetailPage' });
    }
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

      // 消息区（外包 Stack：媒体菜单展开时盖透明遮罩，点击消息区任意处收起菜单）
      Stack() {
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

        if (this.showMediaMenu) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.showMediaMenu = false;
            });
        }
      }
      .layoutWeight(1)
      .width('100%')

      // 输入栏：不设置整行背景，只保留输入框、表情和发送按钮各自的悬浮玻璃层。
      Column({ space: SpaceTokens.sm }) {
        if (this.showEmojiPanel) {
          this.emojiPanel();
        }
        if (this.showMediaMenu) {
          this.mediaMenu();
        }

        Row({ space: 8 }) {
          Row() {
            Text('+')
              .fontSize(24)
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
            .accessibilityText('添加图片或视频')
            .onClick(() => {
              this.showEmojiPanel = false;
              this.showMediaMenu = !this.showMediaMenu;
            });
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
              this.showMediaMenu = false;
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
            .enabled(!this.sending && !this.sendingMedia && this.inputText.trim().length > 0)
            .opacity(this.sending || this.sendingMedia || this.inputText.trim().length === 0 ? 0.45 : 1)
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
