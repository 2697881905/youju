// 账号绑定管理页：展示当前可用于登录有据的账号。
// ⚠️ v1 采用单一登录方式：只用华为账号（AccountKit → unionID）登录，登录即绑定。
//    早期并列的「鸿蒙账号（openId）」已废弃（生产禁用 openId 登录、新用户 openId 恒为 null），
//    故本页只展示华为主账号（不可解绑）+ 未来接入的第三方（如微信，可解绑），
//    不再提供「去绑定华为」入口——重复绑定会覆盖 User.unionID，存在串号风险。
// 入口：设置页 → 账号绑定。遵循现有深色主题与 safeShowToast 提示风格。

import { BindingItem, Provider, User } from '../models/types';
import { listBindings, unbindAccount } from '../services/api';
import { ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { CARD_RADIUS, CARD_SHADOW } from '../utils/cardTokens';
import { brandIconRes, brandTileTint } from '../utils/brandIcons';
import { BackButton } from '../design/components/BackButton';

@Entry
@Component
struct AccountBindingPage {
  @State bindings: BindingItem[] = [];
  @State loading: boolean = false;
  @State pendingUnbindProvider: Provider = 'wechat';
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.init();
  }

  private async init(): Promise<void> {
    // 确保有登录态（沿用现有 ensureLogin），再拉取绑定列表
    try {
      const u: User | null = await ensureLogin();
      if (!u) {
        // 无登录态：ensureLogin 已跳 LoginPage，不再拉列表
        return;
      }
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

  // 二次确认后执行解绑（仅第三方账号；华为主账号由后端 403 兜底）
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

  // 品牌 Logo 块：44 圆角方底（品牌色低透明）承载彩色品牌 Logo，替代纯色实心圆点/单色图标。
  @Builder
  providerTile(provider: Provider) {
    Stack() {
      Image(brandIconRes(provider))
        .width(27)
        .height(27)
        .objectFit(ImageFit.Contain)
    }
    .width(44)
    .height(44)
    .borderRadius(12)
    .backgroundColor(brandTileTint(provider))
    .margin({ right: 13 })
  }

  // 华为主账号行：置顶、标记主账号、无解绑入口
  @Builder
  primaryRow(item: BindingItem) {
    Row() {
      this.providerTile('huawei')
      Column({ space: 4 }) {
        Row() {
          Text('华为账号')
            .fontSize(17).fontFamily($r('app.string.font_family'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text('主账号')
            .fontSize(13).fontFamily($r('app.string.font_family'))
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 8 })
        }
        Text(this.primarySubtitle(item))
          .fontSize(13).fontFamily($r('app.string.font_family'))
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

  // 主账号副标题：脱敏尾号 + 绑定时间
  private primarySubtitle(item: BindingItem): string {
    const time: string = this.formatBoundAt(item.boundAt);
    const masked: string = item.externalId ? item.externalId : '****';
    if (time === '') {
      return masked;
    }
    return masked + ' · ' + time;
  }

  // 第三方已绑定行（当前仅预留给微信等未来接入的 provider）
  @Builder
  boundRow(item: BindingItem) {
    Row() {
      this.providerTile(item.provider)
      Column({ space: 4 }) {
        Text(item.displayName)
          .fontSize(17).fontFamily($r('app.string.font_family'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.primarySubtitle(item))
          .fontSize(13).fontFamily($r('app.string.font_family'))
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('解绑')
        .fontSize(15).fontFamily($r('app.string.font_family'))
        .fontColor($r('app.color.text_secondary'))
        .onClick(() => {
          this.pendingUnbindProvider = item.provider;
          this.getUIContext().showAlertDialog({
            title: '解绑该账号？',
            message: '解绑后你将无法使用该账号登录有据，华为账号仍可正常登录。',
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

  build() {
    Column() {
      // 顶栏：返回 + 标题
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Text('账号绑定')
          .fontSize(17).fontFamily($r('app.string.font_family'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('')
          .width(44)
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 })

      // 说明
      Text('以下账号可用于登录有据')
        .fontSize(13).fontFamily($r('app.string.font_family'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })

      // 列表区
      if (this.loading) {
        Column() {
          LoadingProgress().width(28).height(28)
          Text('加载中…').fontSize(13).fontFamily($r('app.string.font_family')).fontColor($r('app.color.text_secondary')).margin({ top: 10 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column({ space: 12 }) {
          ForEach(this.bindings, (item: BindingItem) => {
            if (item.provider === 'huawei') {
              this.primaryRow(item)
            } else {
              this.boundRow(item)
            }
          }, (item: BindingItem) => item.provider)
        }
        .width('100%')
        .padding(16)
        .layoutWeight(1)
      }

      // 底部安全提示
      Text('华为账号是你的登录方式，登录即完成绑定，不支持解绑。')
        .fontSize(13).fontFamily($r('app.string.font_family'))
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
