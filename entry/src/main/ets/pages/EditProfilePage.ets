// 编辑资料页：修改头像/昵称/简介/性别，复用 updateMe，成功后回写本地并返回。
// 头像通过 PhotoViewPicker 选图 → 压缩 → COS 直传 → updateMe 回写 URL。

import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { getCurrentUser, setSession, ensureLogin, getToken } from '../utils/auth';
import { updateMe, getUploadSignature, getUserProfile, BASE_URL } from '../services/api';
import { compressAvatar, CompressedImage } from '../utils/image';
import { safeShowToast } from '../utils/toast';
import { User, UserProfile } from '../models/types';
import { buildPageTransition } from '../utils/styles';
import { AvatarView } from '../components/AvatarView';

@Entry
@Component
export struct EditProfilePage {
  @State nickname: string = '';
  @State bio: string = '';
  @State selectedGender: string = '1'; // '1'=男 '2'=女 '0'=保密
  @State avatar: string = ''; // 当前头像 URL 或 base64 data URI（COS 不可用时降级）
  @State avatarPreview: image.PixelMap | null = null; // 选图后的本地即时预览（不依赖网络/COS）
  @State uploadingAvatar: boolean = false;
  @State saving: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    const u: User | null = getCurrentUser();
    if (u) {
      this.nickname = u.nickname ?? '';
      this.bio = u.bio ?? '';
      this.selectedGender = u.gender ? String(u.gender) : '0';
      this.avatar = u.avatar ?? '';
    }
    // 旧安装包本地从未存过 bio/gender，打开时从后端补全，避免再次手动重填
    this.syncFromServer();
  }

  // 从后端拉取最新资料补全 bio/gender（网络失败则保留本地缓存，不阻断编辑）
  private async syncFromServer(): Promise<void> {
    const u: User | null = getCurrentUser();
    const id: number = u?.id ?? 0;
    if (id === 0) {
      return;
    }
    try {
      const p: UserProfile = await getUserProfile(id);
      this.bio = p.bio ?? this.bio;
      this.selectedGender = p.gender ? String(p.gender) : '0';
      // 同步回本地 session，避免下次再走网络
      const cur: User | null = getCurrentUser();
      if (cur) {
        const next: User = {
          id: cur.id,
          nickname: cur.nickname,
          avatar: cur.avatar,
          bio: this.bio,
          gender: p.gender ?? undefined,
          isAdmin: cur.isAdmin,
        };
        setSession(getToken(), next);
      }
    } catch (e) {
      // 网络失败：保留本地缓存值，不阻断编辑
    }
  }

  // 选择并上传头像
  private async onPickAvatar(): Promise<void> {
    if (this.uploadingAvatar) return;
    this.uploadingAvatar = true;
    const u: User | null = await ensureLogin();
    if (!u) {
      this.uploadingAvatar = false;
      return;
    }
    // 1) 打开相册（用户取消选择会抛错，静默忽略即可）
    let uris: string[] = [];
    try {
      const ph = new photoAccessHelper.PhotoViewPicker();
      const res = await ph.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
      });
      uris = res.photoUris ?? [];
    } catch (e) {
      // 用户取消：不提示、不上传
      this.uploadingAvatar = false;
      return;
    }
    if (uris.length === 0) {
      this.uploadingAvatar = false;
      return;
    }
    // 2) 压缩并立即本地预览（选完图立刻在头像框显示，不依赖网络/COS）
    let compressed: CompressedImage;
    try {
      compressed = await compressAvatar(uris[0]);
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '图片处理失败：' + (e as Error).message });
      this.uploadingAvatar = false;
      return;
    }
    this.avatarPreview = compressed.preview;
    // 3) 上传到 COS；COS 不可用时降级为 base64 data URI，保证头像能保存到后端并在主页渲染
    let savedUrl: string = '';
    try {
      const sig = await getUploadSignature('image/jpeg');
      // 本地文件上传模式：直传目标改走 127.0.0.1（经 hdc rport，与 API 同一稳定路径），
      // 避免直连 LAN IP（DHCP 变化/模拟器 http 栈不稳定）导致 30s 超时后才降级 base64。
      // viewUrl 保留 LAN IP，供 Image 组件展示（Image 不走 rport，必须走 LAN IP 才能加载）。
      const uploadUrl: string = sig.url.includes('myqcloud.com')
        ? sig.url
        : BASE_URL + sig.url.replace(/^https?:\/\/[^/]+/, '');
      await this.putBinary(uploadUrl, compressed.bytes, sig.contentType);
      savedUrl = sig.viewUrl; // 用 GET 预签名可读链接，私有桶也能加载
    } catch (e) {
      // COS 未配置/上传失败：本地兜底（仅开发/无对象存储环境；生产应配置真实 COS）
      savedUrl = 'data:image/jpeg;base64,' + this.bytesToBase64(compressed.bytes);
    }
    // 4) 保存头像到后端（无论走 COS 还是本地 base64 都持久化）
    try {
      const updated: User = await updateMe({ avatar: savedUrl });
      const cur: User | null = getCurrentUser();
      const merged: User = {
        id: updated.id ?? cur?.id,
        nickname: updated.nickname ?? cur?.nickname,
        avatar: updated.avatar ?? savedUrl,
        gender: updated.gender ?? cur?.gender,
        bio: updated.bio ?? cur?.bio,
        isAdmin: updated.isAdmin ?? cur?.isAdmin,
      };
      const token: string = (AppStorage.get<string>('authToken') ?? '') as string;
      setSession(token, merged);
      this.avatar = savedUrl; // 编辑页当前也同步（预览优先用 avatarPreview）
      safeShowToast(this.getUIContext(), { message: savedUrl.startsWith('data:') ? '头像已更新（本地模式）' : '头像已更新' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '头像保存失败：' + (e as Error).message });
    }
    this.uploadingAvatar = false;
  }

  // ArrayBuffer → base64 字符串（COS 不可用时作为头像兜底存储）
  private bytesToBase64(bytes: ArrayBuffer): string {
    const helper = new util.Base64Helper();
    return helper.encodeToStringSync(new Uint8Array(bytes));
  }

  // 直传二进制到预签名 URL（复制自 ImagePicker）
  private putBinary(url: string, data: ArrayBuffer, contentType: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const req = http.createHttp();
      const header: Record<string, string> = { 'Content-Type': contentType };
      req.request(url, {
        method: http.RequestMethod.PUT,
        header: header,
        extraData: data,
        connectTimeout: 10000,
        readTimeout: 20000,
      }, (err: Error | null, resp: http.HttpResponse) => {
        req.destroy();
        if (err) { reject(err); return; }
        if (resp.responseCode >= 200 && resp.responseCode < 300) { resolve(); }
        else { reject(new Error('上传失败 HTTP ' + resp.responseCode)); }
      });
    });
  }

  // 前端校验：昵称 1-20 字、简介 ≤100 字
  private valid(): boolean {
    const n = this.nickname.trim();
    if (n.length < 1 || n.length > 20) {
      return false;
    }
    if (this.bio.length > 100) {
      return false;
    }
    return true;
  }

  // 保存：调 updateMe → 回写本地登录态 → toast → 返回
  async onSave(): Promise<void> {
    if (this.saving) {
      return;
    }
    if (!this.valid()) {
      safeShowToast(this.getUIContext(), { message: '昵称 1-20 字、简介不超过 100 字' });
      return;
    }
    this.saving = true;
    try {
      const updated: User = await updateMe({
        nickname: this.nickname.trim(),
        bio: this.bio,
        gender: this.selectedGender === '0' ? undefined : parseInt(this.selectedGender),
      });
      // 合并回写本地（token 不变，仅刷新昵称/简介等字段）
      const cur: User | null = getCurrentUser();
      const merged: User = {
        id: updated.id ?? cur?.id,
        nickname: updated.nickname ?? this.nickname.trim(),
        avatar: updated.avatar ?? cur?.avatar ?? this.avatar,
        gender: updated.gender ?? cur?.gender,
        bio: updated.bio ?? this.bio,
        isAdmin: updated.isAdmin ?? cur?.isAdmin,
      };
      const token: string = (AppStorage.get<string>('authToken') ?? '') as string;
      setSession(token, merged);
      safeShowToast(this.getUIContext(), { message: '已保存' });
      this.getUIContext().getRouter().back();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.saving = false;
    }
  }

  build() {
    Column() {
      // 顶栏：返回 + 标题 + 保存
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor($r('app.color.text_primary'))
          .width(48)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.getUIContext().getRouter().back(); });
        Text('编辑资料')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Text(this.saving ? '保存中' : '保存')
          .fontSize(15)
          .fontColor(this.saving ? $r('app.color.text_secondary') : $r('app.color.brand_primary'))
          .width(56)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.onSave(); });
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 });

      Scroll() {
        Column({ space: 20 }) {
          // 头像区域
          Column({ space: 10 }) {
            Text('头像')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start);

            Column() {
              if (this.uploadingAvatar) {
                LoadingProgress()
                  .width(36)
                  .height(36)
                  .color($r('app.color.text_secondary'));
              } else if (this.avatarPreview) {
                // 选图后的本地即时预览（PixelMap 直接渲染，无需等网络）
                Image(this.avatarPreview)
                  .width(110)
                  .height(110)
                  .borderRadius(55)
                  .objectFit(ImageFit.Cover)
                  .border({ width: 2, color: $r('app.color.brand_primary') });
              } else {
                AvatarView({
                  avatar: this.avatar,
                  name: this.nickname,
                  avatarSize: 110,
                  ringWidth: 2
                })
              }
              Text('点击更换头像')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 });
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => { this.onPickAvatar(); });
          }
          .width('100%');

          // 昵称
          Column({ space: 8 }) {
            Text('昵称')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start);
            TextInput({ placeholder: '请输入昵称', text: this.nickname })
              .width('100%')
              .height(44)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(10)
              .onChange((v: string) => { this.nickname = v; });
            Text(this.nickname.trim().length + '/20')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.End);
          }
          .width('100%');

          // 个人简介
          Column({ space: 8 }) {
            Text('个人简介')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start);
            TextArea({ placeholder: '介绍一下自己吧（选填）', text: this.bio })
              .width('100%')
              .height(100)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(10)
              .onChange((v: string) => { this.bio = v; });
            Text(this.bio.length + '/100')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.End);
          }
          .width('100%');

          // 性别选择
          Column({ space: 8 }) {
            Text('性别')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .alignSelf(ItemAlign.Start);
            Row({ space: 24 }) {
              Row() {
                Radio({ value: '1', group: 'genderGroup' })
                  .checked(this.selectedGender === '1')
                  .onChange((isChecked: boolean) => { if (isChecked) this.selectedGender = '1'; });
                Text('男').fontSize(15).fontColor($r('app.color.text_primary')).margin({ left: 4 });
              }
              Row() {
                Radio({ value: '2', group: 'genderGroup' })
                  .checked(this.selectedGender === '2')
                  .onChange((isChecked: boolean) => { if (isChecked) this.selectedGender = '2'; });
                Text('女').fontSize(15).fontColor($r('app.color.text_primary')).margin({ left: 4 });
              }
              Row() {
                Radio({ value: '0', group: 'genderGroup' })
                  .checked(this.selectedGender === '0')
                  .onChange((isChecked: boolean) => { if (isChecked) this.selectedGender = '0'; });
                Text('保密').fontSize(15).fontColor($r('app.color.text_primary')).margin({ left: 4 });
              }
            }
            .padding({ top: 4 });
          }
          .width('100%');
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 32 });
      }
      .layoutWeight(1)
      .width('100%');
    }
    .width('100%')
    .padding({ top: this.statusBarHeight })
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
  }
