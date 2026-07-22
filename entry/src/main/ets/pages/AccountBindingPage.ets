// 账号绑定管理页（核心）：列表（harmony 主账号置顶 + 第三方）+ 绑定/解绑 + 二次确认 + 空状态。
// 入口：设置页 → 账号绑定。遵循现有深色主题与 safeShowToast 提示风格。

import { BindingItem, Provider } from '../models/types';
import { listBindings, bindAccount, unbindAccount } from '../services/api';
import { HuaweiBindButton } from '../components/HuaweiBindButton';
import { ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { resolveActionIcon } from '../utils/actionIcons';
import { CARD_RADIUS, CARD_SHADOW } from '../utils/cardTokens';
import { resolveSettingsIcon } from '../utils/settingsIcons';

@Entry
@Component
struct AccountBindingPage {
  @State bindings: BindingItem[] = [];
  @State loading: boolean = false;
  @State pendingUnbindProvider: Provider = 'huawei';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.init();
  }

  private async init(): Promise<void> {
    // 确保有登录态（沿用现有 ensureLogin），再拉取绑定列表
    try {
      await ensureLogin();
    } catch (e) {
      // 登录失败不阻断渲染；列表接口会因缺 token 返回 401，由 loadBindings 的 catch 提示
    }
    await this.loadBindings();
  }

  private async loadBindings(): Promise<void> {
    this.loading = true;
    try {
      const list: BindingItem[] = await listBindings();
      this.bindings = list;
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    } finally {
      this.loading = false;
    }
  }

  // 华为绑定按钮成功回调（拿到 authorizationCode）
  private async handleBindHuawei(code: string): Promise<void> {
    try {
      await bindAccount('huawei', code);
      safeShowToast(this.getUIContext(), { message: '绑定成功' });
      await this.loadBindings();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  private handleBindFailure(error: string | Error): void {
    const msg: string = typeof error === 'string' ? error : error.message;
    safeShowToast(this.getUIContext(), { message: msg || '华为授权失败' });
  }

  // 二次确认后执行解绑
  private async confirmUnbind(): Promise<void> {
    const provider: Provider = this.pendingUnbindProvider;
    try {
      await unbindAccount(provider);
      safeShowToast(this.getUIContext(), { message: '解绑成功' });
      await this.loadBindings();
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
  }

  private isHuaweiBound(): boolean {
    for (const b of this.bindings) {
      if (b.provider === 'huawei') {
        return true;
      }
    }
    return false;
  }

  // 绑定时间格式化：'YYYY-MM-DD 绑定'
  private formatBoundAt(iso: string): string {
    const d: Date = new Date(iso);
    if (isNaN(d.getTime())) {
      return '';
    }
    const y: number = d.getFullYear();
    const m: string = (d.getMonth() + 1).toString().padStart(2, '0');
    const day: string = d.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${day} 绑定`;
  }

  @Builder
  harmonyRow(item: BindingItem) {
    Row() {
      Image(resolveActionIcon('phone'))
        .width(28)
        .height(28)
        .fillColor($r('app.color.text_primary'))
      Column({ space: 4 }) {
        Row() {
          Text(item.displayName)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text('主账号')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 8 })
        }
        Text(this.formatBoundAt(item.boundAt))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(CARD_RADIUS)
    .shadow(CARD_SHADOW)
  }

  @Builder
  boundRow(item: BindingItem) {
    Row() {
      Circle({ width: 28, height: 28 })
        .fill(item.provider === 'huawei' ? '#3C7BFF' : '#34C759')
      Column({ space: 4 }) {
        Text(item.displayName)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.formatBoundAt(item.boundAt))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('解绑')
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'))
        .onClick(() => {
          this.pendingUnbindProvider = item.provider;
          this.getUIContext().showAlertDialog({
            title: '解绑华为账号？',
            message: '解绑后你将无法使用华为账号登录大蓝书，但仍可用鸿蒙主账号登录。',
            primaryButton: {
              value: '确定解绑',
              fontColor: $r('app.color.semantic_red'),
              action: (): void => {
                this.confirmUnbind();
              },
            },
            secondaryButton: {
              value: '取消',
              action: (): void => {
                // 取消无需操作
              },
            },
          });
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(CARD_RADIUS)
    .shadow(CARD_SHADOW)
  }

  // 华为未绑定行（兼作「空状态」：引导文案 + 去绑定按钮）
  @Builder
  huaweiUnboundRow() {
    Column({ space: 12 }) {
      Row() {
        Circle({ width: 28, height: 28 })
          .fill('#3C7BFF')
        Column({ space: 4 }) {
          Text('华为账号')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text('绑定后可用华为账号快捷登录')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(CARD_RADIUS)
      .shadow(CARD_SHADOW)

      Column({ space: 10 }) {
        Text('暂未绑定第三方账号，绑定后可在其他设备用华为一键登录。')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
        HuaweiBindButton({
          onHuaweiBindSuccess: (code: string): void => {
            this.handleBindHuawei(code);
          },
          onHuaweiBindFailure: (error: string | Error): void => {
            this.handleBindFailure(error);
          },
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 8 })
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Column() {
      // 顶栏：返回 + 标题
      Row() {
        Row() {
          Image(resolveSettingsIcon('back'))
            .width(24).height(24)
            .fillColor($r('app.color.text_primary'))
        }
        .width(48).height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })
        Text('账号绑定')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('')
          .width(48)
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 })

      // 说明
      Text('以下账号可用于登录大蓝书')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })

      // 列表区
      if (this.loading) {
        Column() {
          LoadingProgress().width(28).height(28)
          Text('加载中…').fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 10 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column({ space: 12 }) {
          ForEach(this.bindings, (item: BindingItem) => {
            if (item.provider === 'harmony') {
              this.harmonyRow(item)
            } else {
              this.boundRow(item)
            }
          }, (item: BindingItem) => item.provider)

          // 华为未绑定 → 绑定行（兼作空状态引导）
          if (!this.isHuaweiBound()) {
            this.huaweiUnboundRow()
          }
        }
        .width('100%')
        .padding(16)
        .layoutWeight(1)
      }

      // 底部安全提示
      Text('解绑后将无法使用该方式登录；鸿蒙账号为主账号，不可解绑。')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding(16)
    }
    .width('100%')
    .padding({ top: this.statusBarHeight })
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .transition(buildPageTransition())
  }
}
