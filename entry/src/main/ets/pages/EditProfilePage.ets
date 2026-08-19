// 编辑资料页：修改头像/昵称/简介/性别，复用 updateMe，成功后回写本地并返回。
// 头像通过 PhotoViewPicker 选图 → 压缩 → COS 直传 → updateMe 回写 URL。

import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { getCurrentUser, setSession, ensureLogin, getToken } from '../utils/auth';
import { updateMe, getUploadSignature, getUserProfile, resolveUploadPutUrl, toStoredMediaRef } from '../services/api';
import { compressAvatar, CompressedImage } from '../utils/image';
import { safeShowToast } from '../utils/toast';
import { User, UserProfile } from '../models/types';
import { buildPageTransition } from '../utils/styles';
import { BackButton } from '../design/components/BackButton';
import { SegmentedControl, SegmentedItem } from '../design/components/SegmentedControl';
import { ColorTokens } from '../design/tokens/color';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';
import { EditableProfilePreview } from '../components/EditableProfilePreview';

const GENDER_OPTIONS: SegmentedItem[] = [
  { key: 'male', label: '男' },
  { key: 'female', label: '女' },
  { key: 'private', label: '保密' },
];

@Entry
@Component
export struct EditProfilePage {
  @State nickname: string = '';
  @State bio: string = '';
  @State selectedGender: string = '1'; // '1'=男 '2'=女 '0'=保密
  @State genderIndex: number = 2;
  @State avatar: string = ''; // 当前头像 URL 或 base64 data URI（COS 不可用时降级）
  @State avatarPreview: image.PixelMap | null = null; // 选图后的本地即时预览（不依赖网络/COS）
  @State avatarPending: boolean = false;
  @State uploadingAvatar: boolean = false;
  @State profileBackground: string = '';
  @State profileBackgroundPreview: image.PixelMap | null = null;
  @State profileBackgroundPending: boolean = false;
  @State uploadingProfileBackground: boolean = false;
  @State saving: boolean = false;
  @State saveSucceeded: boolean = false;
  @State backgroundStatus: string = '';
  @State contentPresented: boolean = false;
  @State profileId: number = 0;
  @State followingCount: number = 0;
  @State followerCount: number = 0;
  @State totalLikes: number = 0;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;
  @StorageLink('reduceMotion') reduceMotion: boolean = false;
  @StorageLink('systemReduceMotion') systemReduceMotion: boolean = false;
  private entranceTimer: number = 0;
  private saveReturnTimer: number = 0;
  private originalNickname: string = '';
  private originalBio: string = '';
  private originalGender: string = '0';
  private pendingAvatarImage: CompressedImage | null = null;
  private pendingProfileBackgroundImage: CompressedImage | null = null;

  aboutToAppear(): void {
    const u: User | null = getCurrentUser();
    if (u) {
      this.nickname = u.nickname ?? '';
      this.bio = u.bio ?? '';
      this.selectedGender = u.gender ? String(u.gender) : '0';
      this.genderIndex = this.selectedGender === '1' ? 0 : (this.selectedGender === '2' ? 1 : 2);
      this.avatar = u.avatar ?? '';
      this.profileBackground = u.profileBackground ?? '';
      this.profileId = u.id ?? 0;
    }
    this.captureTextBaseline();
    // 旧安装包本地从未存过 bio/gender，打开时从后端补全，避免再次手动重填
    this.syncFromServer();
    this.contentPresented = false;
    if (this.shouldReduceMotion()) {
      this.contentPresented = true;
    } else {
      this.entranceTimer = setTimeout((): void => {
        this.getUIContext().animateTo({ duration: MotionTokens.container, curve: MotionCurves.emphasized }, () => {
          this.contentPresented = true;
        });
        this.entranceTimer = 0;
      }, MotionTokens.instant) as number;
    }
  }

  aboutToDisappear(): void {
    if (this.entranceTimer !== 0) {
      clearTimeout(this.entranceTimer);
      this.entranceTimer = 0;
    }
    if (this.saveReturnTimer !== 0) {
      clearTimeout(this.saveReturnTimer);
      this.saveReturnTimer = 0;
    }
  }

  private shouldReduceMotion(): boolean {
    return this.reduceMotion || this.systemReduceMotion;
  }

  private failureMessage(error: Error): string {
    if (error.message.length > 0) {
      return error.message;
    }
    return '请稍后重试';
  }

  private captureTextBaseline(): void {
    this.originalNickname = this.nickname;
    this.originalBio = this.bio;
    this.originalGender = this.selectedGender;
  }

  private hasUnsavedChanges(): boolean {
    return this.nickname !== this.originalNickname || this.bio !== this.originalBio || this.selectedGender !== this.originalGender ||
      this.avatarPending || this.profileBackgroundPending;
  }

  private onBack(): void {
    if (!this.hasUnsavedChanges()) {
      this.getUIContext().getRouter().back();
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '放弃未保存的修改？',
      message: '资料和待保存的头像、背景图都不会保留。',
      primaryButton: { value: '继续编辑', action: (): void => {} },
      secondaryButton: { value: '放弃修改', action: (): void => { this.getUIContext().getRouter().back(); } },
    });
  }

  private selectGender(index: number): void {
    this.genderIndex = index;
    this.selectedGender = index === 0 ? '1' : (index === 1 ? '2' : '0');
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
      this.genderIndex = this.selectedGender === '1' ? 0 : (this.selectedGender === '2' ? 1 : 2);
      this.profileBackground = p.profileBackground ?? this.profileBackground;
      this.profileId = p.id;
      this.followingCount = p.followingCount;
      this.followerCount = p.followerCount;
      this.totalLikes = p.totalLikes;
      // 同步回本地 session，避免下次再走网络
      const cur: User | null = getCurrentUser();
      if (cur) {
        const next: User = {
          id: cur.id,
          nickname: cur.nickname,
          avatar: cur.avatar,
          profileBackground: this.profileBackground,
          bio: this.bio,
          gender: p.gender ?? undefined,
          isAdmin: cur.isAdmin,
        };
        setSession(getToken(), next);
      }
      this.captureTextBaseline();
    } catch (e) {
      // 网络失败：保留本地缓存值，不阻断编辑
    }
  }

  // 选择头像只更新本地预览，真正上传留给右上角的保存操作。
  private async onPickAvatar(): Promise<void> {
    if (this.uploadingAvatar || this.saving) return;
    const u: User | null = await ensureLogin();
    if (!u) {
      return;
    }
    let uris: string[] = [];
    try {
      const ph = new photoAccessHelper.PhotoViewPicker();
      const res = await ph.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
      });
      uris = res.photoUris ?? [];
    } catch (e) {
      return;
    }
    if (uris.length === 0) {
      return;
    }
    try {
      this.pendingAvatarImage = await compressAvatar(uris[0]);
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '图片处理失败：' + (e as Error).message });
      return;
    }
    this.avatarPreview = this.pendingAvatarImage.preview;
    this.avatarPending = true;
  }

  // 背景图同样只暂存预览，防止用户在保存前就覆盖已发布的资料。
  private async onPickProfileBackground(): Promise<void> {
    if (this.uploadingProfileBackground || this.saving) return;
    const u: User | null = await ensureLogin();
    if (!u) {
      return;
    }
    let uris: string[] = [];
    try {
      const ph = new photoAccessHelper.PhotoViewPicker();
      const res = await ph.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
      });
      uris = res.photoUris ?? [];
    } catch (e) {
      return;
    }
    if (uris.length === 0) {
      return;
    }
    try {
      this.pendingProfileBackgroundImage = await compressAvatar(uris[0], 1440);
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '图片处理失败：' + (e as Error).message });
      return;
    }
    this.profileBackgroundPreview = this.pendingProfileBackgroundImage.preview;
    this.profileBackgroundPending = true;
    this.backgroundStatus = '待保存';
  }

  private async uploadImage(compressed: CompressedImage, folder: 'avatars' | 'backgrounds'): Promise<string> {
    const signature = await getUploadSignature('image/jpeg', folder);
    await this.putBinary(resolveUploadPutUrl(signature), compressed.bytes, signature.contentType);
    return toStoredMediaRef(signature);
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

  // 保存时统一上传暂存的头像/背景图，再用一次 updateMe 提交所有资料。
  async onSave(): Promise<void> {
    if (this.saving) {
      return;
    }
    if (!this.valid()) {
      safeShowToast(this.getUIContext(), { message: '昵称 1-20 字、简介不超过 100 字' });
      return;
    }
    this.saving = true;
    this.saveSucceeded = false;
    try {
      let nextAvatar: string = this.avatar;
      let nextProfileBackground: string = this.profileBackground;
      if (this.pendingAvatarImage !== null) {
        this.uploadingAvatar = true;
        nextAvatar = await this.uploadImage(this.pendingAvatarImage, 'avatars');
      }
      if (this.pendingProfileBackgroundImage !== null) {
        this.uploadingProfileBackground = true;
        nextProfileBackground = await this.uploadImage(this.pendingProfileBackgroundImage, 'backgrounds');
      }
      const updated: User = await updateMe({
        nickname: this.nickname.trim(),
        bio: this.bio,
        // 保密必须显式发送 null；undefined 会被后端当作“不要更新”。
        gender: this.selectedGender === '0' ? null : parseInt(this.selectedGender),
        avatar: this.avatarPending ? nextAvatar : undefined,
        profileBackground: this.profileBackgroundPending ? nextProfileBackground : undefined,
      });
      // 合并回写本地（token 不变，仅刷新昵称/简介等字段）
      const cur: User | null = getCurrentUser();
      const merged: User = {
        id: updated.id ?? cur?.id,
        nickname: updated.nickname ?? this.nickname.trim(),
        avatar: updated.avatar ?? nextAvatar,
        profileBackground: updated.profileBackground ?? nextProfileBackground,
        gender: this.selectedGender === '0' ? undefined : (updated.gender ?? cur?.gender),
        bio: updated.bio ?? this.bio,
        isAdmin: updated.isAdmin ?? cur?.isAdmin,
      };
      const token: string = (AppStorage.get<string>('authToken') ?? '') as string;
      setSession(token, merged);
      this.nickname = merged.nickname ?? this.nickname.trim();
      this.bio = merged.bio ?? this.bio;
      this.avatar = merged.avatar ?? nextAvatar;
      this.profileBackground = merged.profileBackground ?? nextProfileBackground;
      this.avatarPreview = null;
      this.profileBackgroundPreview = null;
      this.pendingAvatarImage = null;
      this.pendingProfileBackgroundImage = null;
      this.avatarPending = false;
      this.profileBackgroundPending = false;
      this.backgroundStatus = '';
      this.captureTextBaseline();
      this.saveSucceeded = true;
      // 让按钮自身完成一次可见确认后再返回，避免保存成功只剩瞬时 Toast。
      this.saveReturnTimer = setTimeout((): void => {
        this.getUIContext().getRouter().back();
        this.saveReturnTimer = 0;
      }, this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.container) as number;
    } catch (e) {
      this.backgroundStatus = this.profileBackgroundPending ? '保存失败' : this.backgroundStatus;
      safeShowToast(this.getUIContext(), { message: '保存失败：' + this.failureMessage(e) });
    } finally {
      this.uploadingAvatar = false;
      this.uploadingProfileBackground = false;
      this.saving = false;
    }
  }

  build() {
    Column() {
      // 固定玻璃工具栏：保存仅在文本资料发生未保存变更时强调。
      Row() {
        BackButton({ action: (): void => { this.onBack(); } })
        Text('编辑资料')
          .fontSize(17).fontFamily($r('app.string.font_family'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Text(this.saving ? '保存中' : (this.saveSucceeded ? '已保存' : '保存'))
          .fontSize(15).fontFamily($r('app.string.font_family'))
          .fontColor(this.saving ? ColorTokens.secondary : (this.saveSucceeded ? ColorTokens.success : (this.hasUnsavedChanges() ? ColorTokens.brand : ColorTokens.tertiary)))
          .width(56)
          .textAlign(TextAlign.Center)
          .scale({ x: this.saveSucceeded && !this.shouldReduceMotion() ? MotionTokens.successScale : 1, y: this.saveSucceeded && !this.shouldReduceMotion() ? MotionTokens.successScale : 1 })
          .animation({ duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.emphasis, curve: MotionCurves.springSoft })
          .opacity(this.saving || this.saveSucceeded || this.hasUnsavedChanges() ? 1 : 0.45)
          .onClick(() => { if (this.hasUnsavedChanges()) { this.onSave(); } });
      }
      .width('100%')
      .padding({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
      .backgroundColor(ColorTokens.barSurface)
      .backdropBlur(LayoutTokens.glassBlur)
      .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
      .borderRadius(RadiusTokens.floatingBar)
      .margin({ left: SpaceTokens.sm, right: SpaceTokens.sm, top: SpaceTokens.xs });

      Scroll() {
        Column({ space: 20 }) {
          // 资料预览也是图片编辑面：背景和头像都在最终主页位置直接修改。
          Column({ space: SpaceTokens.sm }) {
            EditableProfilePreview({
              avatar: this.avatar,
              avatarPreview: $avatarPreview,
              nickname: this.nickname,
              bio: this.bio,
              selectedGender: this.selectedGender,
              profileId: this.profileId,
              followingCount: this.followingCount,
              followerCount: this.followerCount,
              totalLikes: this.totalLikes,
              profileBackground: this.profileBackground,
              profileBackgroundPreview: $profileBackgroundPreview,
              backgroundStatus: this.backgroundStatus,
              uploadingBackground: this.uploadingProfileBackground,
              onPickBackground: (): void => { this.onPickProfileBackground(); },
              onPickAvatar: (): void => { this.onPickAvatar(); },
            })
            .scale({ x: this.uploadingProfileBackground && !this.shouldReduceMotion() ? MotionTokens.enterScale : 1, y: this.uploadingProfileBackground && !this.shouldReduceMotion() ? MotionTokens.enterScale : 1 })
            .animation({ duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.control, curve: MotionCurves.standard });
          }
          .width('100%');

          // 昵称
          Column({ space: SpaceTokens.sm }) {
            Text('昵称')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.callout.weight).fontColor(ColorTokens.primary)
              .alignSelf(ItemAlign.Start);
            TextInput({ placeholder: '请输入昵称', text: this.nickname })
              .fontFamily(TypeTokens.fontFamily).fontColor(ColorTokens.primary)
              .width('100%')
              .height(LayoutTokens.minTouchTarget)
              .backgroundColor(ColorTokens.elevated).backdropBlur(LayoutTokens.glassBlur)
              .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
              .borderRadius(RadiusTokens.lg)
              .onChange((v: string) => { this.nickname = v; });
            Text(this.nickname.trim().length + '/20')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.tertiary)
              .alignSelf(ItemAlign.End);
          }
          .width('100%');

          // 个人简介
          Column({ space: SpaceTokens.sm }) {
            Text('个人简介')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.callout.weight).fontColor(ColorTokens.primary)
              .alignSelf(ItemAlign.Start);
            TextArea({ placeholder: '介绍一下自己吧（选填）', text: this.bio })
              .fontFamily(TypeTokens.fontFamily).fontColor(ColorTokens.primary)
              .width('100%')
              .height(104)
              .backgroundColor(ColorTokens.elevated).backdropBlur(LayoutTokens.glassBlur)
              .border({ width: LayoutTokens.glassBorderWidth, color: ColorTokens.barBorder, style: BorderStyle.Solid })
              .borderRadius(RadiusTokens.lg)
              .onChange((v: string) => { this.bio = v; });
            Text(this.bio.length + '/100')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontColor(ColorTokens.tertiary)
              .alignSelf(ItemAlign.End);
          }
          .width('100%');

          // 性别选择
          Column({ space: SpaceTokens.sm }) {
            Text('性别')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.callout.weight).fontColor(ColorTokens.primary)
              .alignSelf(ItemAlign.Start);
            SegmentedControl({
              items: GENDER_OPTIONS,
              selectedIndex: $genderIndex,
              glass: true,
              onSelect: (index: number): void => { this.selectGender(index); },
            })
          }
          .width('100%');
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({ left: 16, right: 16, top: 16, bottom: 32 });
      }
      .layoutWeight(1)
      .width('100%')
      .opacity(this.shouldReduceMotion() || this.contentPresented ? 1 : 0)
      .translate({ y: this.shouldReduceMotion() || this.contentPresented ? 0 : 16 })
      .animation({ duration: this.shouldReduceMotion() ? MotionTokens.instant : MotionTokens.container, curve: MotionCurves.emphasized });
    }
    .width('100%')
    .padding({ top: this.statusBarHeight })
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
  }
