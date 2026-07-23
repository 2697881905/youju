// 圈子 — Apple 风格卡片网格
// 展示所有标签圈子，支持加入/退出（后端持久化）
// 数据来源：listTags / followTag / unfollowTag / listFollowedTags

import { Tag, User } from '../models/types';
import { TagIcon } from './TagIcon';
import { listTags, followTag, unfollowTag, listFollowedTags } from '../services/api';
import { ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { observeGridColumns, gridColumnTemplate } from '../utils/responsive';
import { CARD_RADIUS, CARD_PADDING, CARD_SHADOW, GRID_GAP, GRID_PADDING } from '../utils/cardTokens';
import { common } from '@kit.AbilityKit';

@Component
struct CircleCard {
  @Prop name: string = '';
  @Prop emoji: string = '';
  @Prop followCount: number = 0;
  @Prop joined: boolean = false;
  @Prop toggling: boolean = false;
  // 普通属性（回调）：由父组件在 ForEach 中传入，非 @Prop/@Link
  onToggle: () => void = () => {};

  build() {
    Column({ space: 10 }) {
      Column({ space: 6 }) {
        TagIcon({ name: this.name, iconSize: 40, tint: $r('app.color.brand_primary') })
        Text(this.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.followCount + ' 人加入')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Button(this.joined ? '已加入' : '加入圈子')
        .width('100%')
        .height(32)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .enabled(!this.toggling)
        .backgroundColor(this.joined ? $r('app.color.bg_secondary') : $r('app.color.brand_primary'))
        .fontColor(this.joined ? $r('app.color.brand_primary') : '#FFFFFF')
        .border(this.joined ? { width: 1, color: $r('app.color.brand_primary') } : { width: 0 })
        .borderRadius(16)
        .onClick(() => { this.onToggle(); })
    }
    .width('100%')
    .padding(CARD_PADDING)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(CARD_RADIUS)
    .shadow(CARD_SHADOW)
  }
}

@Component
export struct CircleTab {
  @State circles: Tag[] = [];
  @State joinedNames: string[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State togglingName: string = '';
  // 响应式列数（按屏幕宽度 2/3/4 列自适应）
  @State gridColumns: number = 2;
  @State gridTemplate: string = '1fr 1fr';
  private unregisterColumns: () => void = () => {};

  aboutToAppear(): void {
    this.unregisterColumns = observeGridColumns(
      this.getUIContext().getHostContext() as common.Context,
      (cols: number): void => {
        this.gridColumns = cols;
        this.gridTemplate = gridColumnTemplate(cols);
      }
    );
    this.initData();
  }

  aboutToDisappear(): void {
    this.unregisterColumns();
  }

  private async initData(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const u: User | null = await ensureLogin();
      if (!u) {
        // 无登录态：ensureLogin 已跳 LoginPage，本页不加载
        this.loading = false;
        return;
      }
      const tagsPromise: Promise<Tag[]> = listTags();
      const followedPromise: Promise<string[]> = listFollowedTags();
      this.circles = await tagsPromise;
      this.joinedNames = await followedPromise;
    } catch (e) {
      this.error = (e as Error).message;
      this.circles = [];
      this.joinedNames = [];
    } finally {
      this.loading = false;
    }
  }

  private isJoined(name: string): boolean {
    return this.joinedNames.indexOf(name) >= 0;
  }

  // 乐观更新本地圈子加入人数（仅用于即时反馈，最终以服务端返回为准）
  // 注意：ArkTS 禁止对象展开 {...x}，故显式构造新 Tag 对象
  private updateCircleCount(name: string, delta: number): void {
    const updated: Tag[] = [];
    for (const c of this.circles) {
      if (c.name === name) {
        const next: Tag = {
          id: c.id,
          name: c.name,
          emoji: c.emoji,
          category: c.category,
          useCount: c.useCount,
          followCount: (c.followCount ?? 0) + delta,
        };
        updated.push(next);
      } else {
        updated.push(c);
      }
    }
    this.circles = updated;
  }

  // 权威同步：从服务端重新拉全量列表覆盖本地，保证与服务端完全一致
  // 复用「重进页面即正确」的同一机制（重新赋值 @State 数组触发重渲染）
  private async refreshCircles(): Promise<void> {
    const tags: Tag[] = await listTags();
    const followed: string[] = await listFollowedTags();
    this.circles = tags;
    this.joinedNames = followed;
  }

  private async toggleJoin(name: string): Promise<void> {
    if (this.togglingName !== '') {
      return;
    }
    this.togglingName = name;
    const joined: boolean = this.isJoined(name);
    // 乐观更新：先立即 ±1 反馈，避免等待网络
    this.updateCircleCount(name, joined ? -1 : 1);
    try {
      if (joined) {
        await unfollowTag(name);
        this.joinedNames = this.joinedNames.filter((n: string) => n !== name);
        safeShowToast(this.getUIContext(), { message: '已退出「' + name + '」' });
      } else {
        await followTag(name);
        this.joinedNames = this.joinedNames.concat([name]);
        safeShowToast(this.getUIContext(), { message: '已加入「' + name + '」' });
      }
    } catch (e) {
      // 失败回滚乐观更新与已加入集合
      this.updateCircleCount(name, joined ? 1 : -1);
      this.joinedNames = joined
        ? this.joinedNames.concat([name])
        : this.joinedNames.filter((n: string) => n !== name);
      safeShowToast(this.getUIContext(), { message: '操作失败：' + (e as Error).message });
      this.togglingName = '';
      return;
    }
    // 权威同步：操作成功后重新拉全量，覆盖本地（数字必定与服务端一致）
    try {
      await this.refreshCircles();
    } catch (_e) {
      // 刷新失败不影响已成功的操作，保留乐观值
    } finally {
      this.togglingName = '';
    }
  }

  build() {
    Column() {
      // 标题
      Row() {
        Text('圈子')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(this.joinedNames.length > 0
          ? '已加入 ' + this.joinedNames.length + ' 个'
          : '发现感兴趣的话题')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 })

      // 内容区
      if (this.circles.length === 0 && this.loading) {
        Column() {
          LoadingProgress().width(28).height(28)
          Text('加载中…')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 10 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.circles.length === 0) {
        Column() {
          Text(this.error ? ('加载失败：' + this.error) : '暂无圈子')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
          if (this.error) {
            Button('重试')
              .fontSize(13)
              .height(32)
              .margin({ top: 12 })
              .backgroundColor($r('app.color.brand_primary'))
              .fontColor('#FFFFFF')
              .onClick(() => { this.initData(); })
          }
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Grid() {
            ForEach(
              this.circles,
              (c: Tag) => {
                GridItem() {
                  CircleCard({
                    name: c.name ?? '',
                    emoji: c.emoji ?? '',
                    followCount: c.followCount ?? 0,
                    joined: this.isJoined(c.name ?? ''),
                    toggling: this.togglingName === (c.name ?? ''),
                    onToggle: () => { this.toggleJoin(c.name ?? ''); }
                  })
                }
              },
              (c: Tag) => c.name ?? ''
            )
          }
          .columnsTemplate(this.gridTemplate)
          .columnsGap(GRID_GAP)
          .rowsGap(GRID_GAP)
          .padding(GRID_PADDING)
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_primary'))
    .alignItems(HorizontalAlign.Start)
  }
}