// 私信聊天页（文字 + 图片/视频）：
// - 从进程内导航意图读取对端信息（规避 router.getParams 不可靠）
// - 进入即拉历史并标记已读（清私信红点）
// - 发送文字消息（服务端按接收方 dmPolicy + 拉黑做权限校验，越权回中文报错）
// - 输入栏最左「+」弹出媒体菜单（发送图片/发送视频）：相册选择 → COS 上传 → 以 image/video 消息发送
// - 长按消息弹出小菜单：文字=复制/删除；图片视频=保存/删除；自己发送且 5 分钟内可撤回
//   （删除仅自己不可见；撤回双方均不可见，展示「已撤回」占位）
// - 发送/已读后自增 dmRefreshSignal，驱动消息页会话列表与红点刷新
import { DmMessage, User, DmSharePayload } from '../models/types';
import { getMessages, sendMessage, markMessagesRead, uploadChatMedia, resolveDisplayImageUrl, deleteMessageForMe, recallMessage } from '../services/api';
import { getToken, getUserId, getCurrentUser, ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { copyToClipboard } from '../utils/share';
import { saveChatMediaToGallery } from '../utils/mediaSave';
import { compressImage, CompressedImage } from '../utils/image';
import { AvatarView } from '../components/AvatarView';
import { VideoPlayer } from '../components/VideoPlayer';
import { ImageViewer } from '../components/ImageViewer';
import { VideoViewer } from '../components/VideoViewer';
import { KeyboardAvoidMode } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { BackButton } from '../design/components/BackButton';
import { ColorTokens } from '../design/tokens/color';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { RadiusTokens } from '../design/tokens/radius';
import { TypeTokens } from '../design/tokens/type';
import { MotionCurves } from '../design/tokens/motion';
import { openUserProfile, takeChatIntent, openPostDetail } from '../utils/nav';

// 长按菜单哨兵消息：menuMsgId 无命中时返回（正常路径被外层 if 挡住，纯防御性兜底；
// type='' 使菜单只显示「删除」，senderId=0 使撤回项不出现）
const NO_MENU_MSG: DmMessage = {
  id: 0,
  senderId: 0,
  receiverId: 0,
  type: '',
  content: '',
  read: false,
  createdAt: '',
};

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
  @State viewingImage: string = ''; // 全屏看图（聊天图片点开预览）
  @State viewingVideo: string = ''; // 全屏看视频（聊天视频点开自动播放）
  @State showMediaMenu: boolean = false;
  @State error: string = '';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  private listScroller: Scroller = new Scroller();
  private originalKeyboardMode: KeyboardAvoidMode | null = null;
  private pollTimer: number = -1; // 轻量轮询定时器（对方撤回/新消息同步）
  private readonly emojiOptions: string[] = [
    '😀', '😄', '😂', '🥰', '😍', '🥺', '😏', '🤔',
    '😎', '🤣', '😊', '😢', '😡', '👍', '👎', '❤️',
    '🔥', '🎉', '✨', '👏',
  ];

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
    this.startPolling();
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
    this.stopPolling();
    if (this.originalKeyboardMode !== null) {
      try {
        this.getUIContext().setKeyboardAvoidMode(this.originalKeyboardMode);
      } catch (e) {
        // 忽略
      }
    }
    // 返回消息页时广播刷新：进入时已 markMessagesRead，此刻后台标记已彻底完成，
    // MessagePage 前台监听 dmRefreshSignal 重拉会话，本会话未读立即清零、红点即时消失
    // （避免后台 @Watch 未生效、需切 Tab 才刷新）。
    this.bumpRefreshSignal();
  }

  // ===== 轻量轮询：5 秒拉一次消息（MVP 无 WebSocket 推送）=====
  // 覆盖「双方同时停留在聊天页」场景：对方撤回 / 收到新消息 5 秒内同步；
  // 仅在内容有变化时才重赋值列表（避免无谓的 List 重建与滚动跳动）。
  private startPolling(): void {
    this.pollTimer = setInterval((): void => {
      this.pollMessages();
    }, 5000);
  }

  private stopPolling(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private async pollMessages(): Promise<void> {
    if (getToken() === '' || this.peerId <= 0 || this.loading) {
      return;
    }
    try {
      const res = await getMessages(this.peerId, 1);
      const fresh: string = JSON.stringify(res.list);
      const old: string = JSON.stringify(this.messages);
      if (fresh !== old) {
        this.messages = res.list;
        this.scrollToBottom();
        this.bumpRefreshSignal();
      }
    } catch (e) {
      // 轮询失败静默（瞬时网络抖动不打扰用户），下一轮自动重试
    }
  }

  // 返回手势/返回键：全屏查看器（图片/视频）打开时先关闭查看器，而非退出聊天页
  onBackPress(): boolean {
    if (this.viewingVideo.length > 0) {
      this.viewingVideo = '';
      return true;
    }
    if (this.viewingImage.length > 0) {
      this.viewingImage = '';
      return true;
    }
    return false;
  }

  // 页面重新显示时静默拉取最新消息（已有消息时不显示 Loading）：
  // 覆盖对方撤回/新消息/从后台切回等场景——停留期间无实时推送，返回页面即同步。
  onPageShow(): void {
    if (getToken() !== '' && this.peerId > 0) {
      this.loadMessages();
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
    // 压缩结果提到 try 外，finally 统一释放 preview PixelMap（聊天场景不用本地预览）
    let compressed: CompressedImage | null = null;
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
      console.info('[chat] image picked: ' + uris[0]);
      compressed = await compressImage(uris[0]);
      console.info('[chat] image compressed: ' + compressed.bytes.byteLength + 'B');
      const url: string = await uploadChatMedia('image/jpeg', 'posts', compressed.bytes);
      console.info('[chat] image uploaded: ' + url);
      const msg: DmMessage = await sendMessage(this.peerId, url, 'image');
      console.info('[chat] image message sent: id=' + msg.id);
      this.messages = this.messages.concat([msg]);
      this.bumpRefreshSignal();
      this.scrollToBottom();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '图片发送失败：' + ((e as Error).message ?? '未知错误') });
    } finally {
      if (compressed !== null) {
        compressed.preview.release();
      }
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
      console.info('[chat] video picked: ' + uris[0]);
      const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
      try {
        const stat = fileIo.statSync(file.fd);
        const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buffer);
        const url: string = await uploadChatMedia('video/mp4', 'video', buffer);
        console.info('[chat] video uploaded: ' + url);
        const msg: DmMessage = await sendMessage(this.peerId, url, 'video');
        console.info('[chat] video message sent: id=' + msg.id);
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
    try {
      this.listScroller.scrollEdge(Edge.Bottom);
    } catch (e) {
      // 布局未就绪时忽略，用户可手动滚动
    }
    setTimeout(() => {
      try {
        this.listScroller.scrollEdge(Edge.Bottom);
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

  // 点击自己的头像 → 个人主页（UserProfilePage 以本人 id 打开，isSelf 时隐藏关注/私信按钮）
  private goSelf(): void {
    const uid: number = getUserId();
    if (uid > 0) {
      openUserProfile(uid);
      this.getUIContext().getRouter().pushUrl({ url: 'pages/UserProfilePage' });
    }
  }

  private appendEmoji(emoji: string): void {
    this.inputText = this.inputText + emoji;
    this.showEmojiPanel = false;
  }

  @Builder
  emojiPanel() {
    Scroll() {
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
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs, bottom: SpaceTokens.xs })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
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

  // ===== 长按消息小菜单：复制 / 保存 / 删除 / 撤回 =====

  // 自己发送且在 5 分钟窗口内（后端二次校验，前端仅控制入口显隐）
  private canRecall(m: DmMessage): boolean {
    if (m.recalled || m.senderId !== getUserId()) {
      return false;
    }
    const sentAt: number = new Date(m.createdAt).getTime();
    if (isNaN(sentAt)) {
      return false;
    }
    return Date.now() - sentAt <= 5 * 60 * 1000;
  }

  private copyMsg(m: DmMessage): void {
    this.closeMenu();
    try {
      copyToClipboard(m.content);
      safeShowToast(this.getUIContext(), { message: '已复制' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '复制失败，请重试' });
    }
  }

  // 保存图片/视频到系统图库（系统弹窗确认；取消则静默）
  private async saveMediaMsg(m: DmMessage): Promise<void> {
    this.closeMenu();
    safeShowToast(this.getUIContext(), { message: '正在保存…' });
    try {
      const saved: boolean = await saveChatMediaToGallery(this.getUIContext(), m.content, m.type);
      if (saved) {
        safeShowToast(this.getUIContext(), { message: '已保存到图库' });
      }
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '保存失败：' + ((e as Error).message ?? '未知错误') });
    }
  }

  // 删除：仅自己不可见（对方不受影响），本地立即移除
  private async deleteMsg(m: DmMessage): Promise<void> {
    this.closeMenu();
    try {
      await deleteMessageForMe(m.id);
      this.messages = this.messages.filter((it: DmMessage): boolean => it.id !== m.id);
      this.bumpRefreshSignal();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  // 撤回：双方均不可见正文，本地替换为「已撤回」占位
  private async recallMsg(m: DmMessage): Promise<void> {
    this.closeMenu();
    try {
      const updated: DmMessage = await recallMessage(m.id);
      this.messages = this.messages.map((it: DmMessage): DmMessage => it.id === m.id ? updated : it);
      this.bumpRefreshSignal();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  // ===== 长按消息小菜单（自绘浮层，替代 bindContextMenu）=====
  // bindContextMenu(ResponseType.LongPress) 会被消息内容组件的 onClick（图片预览/视频播放）
  // 竞争掉导致长按无响应；改用标准 LongPressGesture（与子组件点击正确共存）+ 遮罩浮层菜单。
  @State menuMsgId: number = 0; // 当前弹菜单的消息 id（0=未弹出）
  @State menuX: number = 0; // 菜单卡片左上角 x（消息区 Stack 本地坐标，按按压点定位）
  @State menuY: number = 0; // 菜单卡片左上角 y
  // 消息区 Stack 的全局原点与尺寸（按压点全局坐标 → 本地坐标换算 & 边界钳制用）
  private msgAreaGlobalX: number = 0;
  private msgAreaGlobalY: number = 0;
  private msgAreaWidth: number = 0;
  private msgAreaHeight: number = 0;

  // 当前弹菜单的消息；menuMsgId 有效时必命中，未命中返回哨兵（type='' 只显示删除项，安全降级）
  private menuMsg(): DmMessage {
    for (const m of this.messages) {
      if (m.id === this.menuMsgId) {
        return m;
      }
    }
    return NO_MENU_MSG;
  }

  private closeMenu(): void {
    this.menuMsgId = 0;
  }

  // 长按定位：菜单卡片中心对准按压手指位置（跟手），并钳制在消息区边界内不溢出屏幕
  private openMenu(m: DmMessage, event: GestureEvent): void {
    // 兜底中心点（fingerList 理论上必有值，防御性处理）
    let gx: number = this.msgAreaGlobalX + this.msgAreaWidth / 2;
    let gy: number = this.msgAreaGlobalY + this.msgAreaHeight / 2;
    if (event.fingerList.length > 0) {
      gx = event.fingerList[0].globalX;
      gy = event.fingerList[0].globalY;
    }
    // 全局坐标 → 消息区 Stack 本地坐标
    const lx: number = gx - this.msgAreaGlobalX;
    const ly: number = gy - this.msgAreaGlobalY;
    // 按可见项数估算卡片高度（行高 42 + hairline 分隔线 + 上下 xs 内边距）
    let rows: number = 1; // 删除
    if (m.type === 'text' || m.type === 'image' || m.type === 'video') {
      rows += 1;
    }
    if (this.canRecall(m)) {
      rows += 1;
    }
    const cardW: number = 148;
    const cardH: number = rows * 42 + (rows - 1) * 0.5 + 8;
    // 卡片中心对准按压点后钳制在消息区边界内
    let x: number = lx - cardW / 2;
    let y: number = ly - cardH / 2;
    const maxX: number = Math.max(8, this.msgAreaWidth - cardW - 8);
    const maxY: number = Math.max(8, this.msgAreaHeight - cardH - 8);
    this.menuX = Math.max(8, Math.min(maxX, x));
    this.menuY = Math.max(8, Math.min(maxY, y));
    this.menuMsgId = m.id;
  }

  @Builder
  menuRow(label: string, m: DmMessage, action: (msg: DmMessage) => void) {
    Text(label)
      .fontSize(TypeTokens.body.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.headline.weight)
      .fontColor(ColorTokens.primary)
      .width('100%')
      .height(42)
      .textAlign(TextAlign.Center)
      .onClick(() => {
        this.closeMenu();
        action(m);
      })
  }

  @Builder
  menuDivider() {
    Divider()
      .color(ColorTokens.separator)
      .strokeWidth(LayoutTokens.hairlineWidth)
  }

  // 长按菜单浮层：全屏透明遮罩（点击关闭）+ 卡片按按压点定位（跟手）+ 轻量进场动效
  @Builder
  msgActionSheet() {
    Column() {
      Column() {
        if (this.menuMsg().type === 'text') {
          this.menuRow('复制', this.menuMsg(), (msg: DmMessage): void => { this.copyMsg(msg); })
          this.menuDivider()
        }
        if (this.menuMsg().type === 'image' || this.menuMsg().type === 'video') {
          this.menuRow('保存', this.menuMsg(), (msg: DmMessage): void => { this.saveMediaMsg(msg); })
          this.menuDivider()
        }
        this.menuRow('删除', this.menuMsg(), (msg: DmMessage): void => { this.deleteMsg(msg); })
        if (this.canRecall(this.menuMsg())) {
          this.menuDivider()
          this.menuRow('撤回', this.menuMsg(), (msg: DmMessage): void => { this.recallMsg(msg); })
        }
      }
      .width(148)
      .padding({ top: SpaceTokens.xs, bottom: SpaceTokens.xs })
      .backgroundColor(ColorTokens.elevated)
      .borderRadius(RadiusTokens.md)
      .clip(true)
      .shadow({ radius: 20, color: ColorTokens.barShadow, offsetY: 6 })
      // 按压点定位（openMenu 已把坐标钳制在消息区边界内，不溢出屏幕）
      .position({ x: this.menuX, y: this.menuY })
      // 进/出场：淡入 + 轻微缩放（0.94→1），只动 transform/opacity 保证性能
      .transition(
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
          .animation({ duration: 180, curve: MotionCurves.standard })
      )
    }
    .width('100%')
    .height('100%')
    // 透明遮罩：视觉上无灰色覆盖，但仍捕获点击以关闭菜单
    .backgroundColor(Color.Transparent)
    .onClick((): void => {
      this.closeMenu();
    })
  }

  @Builder
  messageRow(m: DmMessage) {
    // 已撤回：居中灰字占位（无头像/无时间/无长按菜单）
    if (m.recalled) {
      Text(this.isMine(m.senderId) ? '你撤回了一条消息' : '对方撤回了一条消息')
        .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
        .fontColor(ColorTokens.tertiary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: SpaceTokens.xs, bottom: SpaceTokens.xs })
    } else {
      Row({ space: 8 }) {
        // 对方头像（左侧），聊天页保持纯头像，不叠加品牌色头像框；点击跳对方主页。
        if (!this.isMine(m.senderId)) {
          AvatarView({ avatar: this.peerAvatar, name: this.peerName, avatarSize: 36, ringWidth: 0 })
            .onClick((): void => {
              this.goPeer();
            })
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
            .onClick(() => {
              // 点开全屏看图（与详情页一致：双击/捏合缩放、单击关闭）
              this.viewingImage = m.content;
            })
        } else if (m.type === 'video') {
          // 气泡内仅展示封面+播放入口；点击不内联播放，而是放大全屏并自动播放（底部带播放条）
          VideoPlayer({ src: m.content, poster: m.content, onOpen: (): void => { this.viewingVideo = m.content; } })
            .width(200)
            .aspectRatio(1.2)
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

      // 自己的头像（右侧），与对方保持同样的无边框样式；点击跳个人主页。
      if (this.isMine(m.senderId)) {
        AvatarView({ avatar: this.myAvatar, name: this.myName, avatarSize: 36, ringWidth: 0 })
          .onClick((): void => {
            this.goSelf();
          })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
    // 长按弹出小菜单：标准 LongPressGesture 与子组件 onClick（图片预览/视频播放）正确共存；
    // 长按识别成功后系统自动取消单击，不会误触发预览；菜单按按压点定位（跟手）
    .gesture(
      LongPressGesture({ repeat: false, duration: 400 })
        .onAction((event: GestureEvent): void => {
          this.openMenu(m, event);
        })
    )
    }
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
      // 全屏图片查看器：支持双击/捏合缩放、拖动平移、单击或按钮关闭
      if (this.viewingImage.length > 0) {
        ImageViewer({
          url: this.viewingImage,
          onClose: (): void => { this.viewingImage = ''; },
        })
      }

      // 全屏视频查看器：打开即自动播放，底部系统播放条（进度/暂停/时长）
      if (this.viewingVideo.length > 0) {
        VideoViewer({
          url: this.viewingVideo,
          onClose: (): void => { this.viewingVideo = ''; },
        })
      }

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
          // 用 Scroll+Column 而非 List：List 在内容不足一屏时默认垂直居中，
          // 消息会飘到屏幕中间；Scroll 内容天然从顶部开始排列（SDK 无 alignList 属性可配）。
          Scroll(this.listScroller) {
            Column({ space: 8 }) {
              ForEach(
                this.messages,
                (m: DmMessage) => {
                  this.messageRow(m);
                },
                (m: DmMessage) => `${m.id}-${m.recalled ? 1 : 0}`,
              )
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          }
          .scrollBar(BarState.Auto)
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.TopStart);
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

        // 长按消息弹出的操作菜单浮层（遮罩点击关闭）
        if (this.menuMsgId > 0) {
          this.msgActionSheet()
        }
      }
      .layoutWeight(1)
      .width('100%')
      // 采集消息区全局原点与尺寸：长按菜单按压点定位的坐标换算与边界钳制依赖它
      .onAreaChange((_old: Area, area: Area): void => {
        this.msgAreaGlobalX = area.globalPosition.x as number;
        this.msgAreaGlobalY = area.globalPosition.y as number;
        this.msgAreaWidth = area.width as number;
        this.msgAreaHeight = area.height as number;
      })

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
