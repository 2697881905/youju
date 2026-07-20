// 编辑资料页：修改头像/昵称/简介/性别，复用 updateMe，成功后回写本地并返回。
// 头像通过 PhotoViewPicker 选图 → 压缩 → COS 直传 → updateMe 回写 URL。
import { router } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { getCurrentUser, setSession, ensureLogin } from '../utils/auth';
import { updateMe, getUploadSignature } from '../services/api';
import { compressImage, CompressedImage } from '../utils/image';
import { safeShowToast } from '../utils/toast';
import { User } from '../models/types';

@Entry
@Component
export struct EditProfilePage {
  @State nickname: string = '';
  @State bio: string = '';
  @State selectedGender: string = '1'; // '1'=男 '2'=女 '0'=保密
  @State avatar: string = ''; // 当前头像 URL
  @State uploadingAvatar: boolean = false;
  @State saving: boolean = false;

  aboutToAppear(): void {
    const u: User | null = getCurrentUser();
    if (u) {
      this.nickname = u.nickname ?? '';
      this.bio = u.bio ?? '';
      this.selectedGender = u.gender ? String(u.gender) : '0';
      this.avatar = u.avatar ?? '';
    }
  }

  // 选择并上传头像
  private async onPickAvatar(): Promise<void> {
    if (this.uploadingAvatar) return;
    this.uploadingAvatar = true;
    try {
      await ensureLogin();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '请先登录' });
      this.uploadingAvatar = false;
      return;
    }
    try {
      const ph = new photoAccessHelper.PhotoViewPicker();
      const res = await ph.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
      });
      const uris: string[] = res.photoUris ?? [];
      if (uris.length === 0) {
        this.uploadingAvatar = false;
        return;
      }
      const compressed: CompressedImage = await compressImage(uris[0]);
      const sig = await getUploadSignature('image/jpeg');
      await this.putBinary(sig.url, compressed.bytes, sig.contentType);
      this.avatar = sig.cdnUrl;
      // 立即保存头像到后端
      try {
        const updated: User = await updateMe({ avatar: sig.cdnUrl });
        const cur: User | null = getCurrentUser();
        const merged: User = {
          id: updated.id ?? cur?.id,
          nickname: updated.nickname ?? cur?.nickname,
          avatar: updated.avatar ?? sig.cdnUrl,
          gender: updated.gender ?? cur?.gender,
          bio: updated.bio ?? cur?.bio,
          isAdmin: updated.isAdmin ?? cur?.isAdmin,
        };
        const token: string = (AppStorage.get<string>('authToken') ?? '') as string;
        setSession(token, merged);
        safeShowToast(this.getUIContext(), { message: '头像已更新' });
      } catch (e) {
        safeShowToast(this.getUIContext(), { message: '头像已上传，但保存失败：' + (e as Error).message });
      }
    } catch (e) {
      // 用户取消选择会抛错，忽略
    }
    this.uploadingAvatar = false;
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
        connectTimeout: 30000,
        readTimeout: 30000,
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
      router.back();
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
          .onClick(() => { router.back(); });
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
              } else if (this.avatar.length > 0) {
                Image(this.avatar)
                  .width(80)
                  .height(80)
                  .borderRadius(40)
                  .objectFit(ImageFit.Cover);
              } else {
                Text(this.nickname.trim().length > 0 ? this.nickname.trim().charAt(0) : '?')
                  .width(80)
                  .height(80)
                  .borderRadius(40)
                  .fontSize(28)
                  .fontColor(Color.White)
                  .backgroundColor($r('app.color.brand_primary'))
                  .textAlign(TextAlign.Center);
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
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'));
    .transition(TransitionEffect.OPACITY
      .animation({ duration: 300, curve: Curve.EaseOut })
      .combine(TransitionEffect.translate({ x: 50 })
        .animation({ duration: 350, curve: Curve.EaseOut })))
  }
}
