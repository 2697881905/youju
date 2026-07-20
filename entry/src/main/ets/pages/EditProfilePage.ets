// 编辑资料页（轻量页，非弹窗）：修改昵称/简介，复用 updateMe，成功后回写本地并返回。
// 头像本期不可修改（COS 未配置），仅展示当前头像占位（复用本地昵称首字）。
import { router } from '@kit.ArkUI';
import { getCurrentUser, setSession } from '../utils/auth';
import { updateMe } from '../services/api';
import { safeShowToast } from '../utils/toast';
import { User } from '../models/types';

@Entry
@Component
export struct EditProfilePage {
  @State nickname: string = '';
  @State bio: string = '';
  @State saving: boolean = false;

  aboutToAppear(): void {
    const u: User | null = getCurrentUser();
    if (u) {
      this.nickname = u.nickname ?? '';
      this.bio = u.bio ?? '';
    }
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
      const updated: User = await updateMe({ nickname: this.nickname.trim(), bio: this.bio });
      // 合并回写本地（token 不变，仅刷新昵称/简介等字段）
      const cur: User | null = getCurrentUser();
      const merged: User = {
        id: updated.id ?? cur?.id,
        nickname: updated.nickname ?? this.nickname.trim(),
        avatar: updated.avatar ?? cur?.avatar,
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
          .onClick(() => {
            router.back();
          });
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
          .onClick(() => {
            this.onSave();
          });
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 });

      Column({ space: 20 }) {
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
            .onChange((v: string) => {
              this.nickname = v;
            });
          Text(this.nickname.trim().length + '/20')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .alignSelf(ItemAlign.End);
        }
        .width('100%')

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
            .onChange((v: string) => {
              this.bio = v;
            });
          Text(this.bio.length + '/100')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .alignSelf(ItemAlign.End);
        }
        .width('100%');
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16 });

      Blank();
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'));
  }
}
