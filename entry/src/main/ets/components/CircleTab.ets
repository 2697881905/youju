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

  private async toggleJoin(name: string): Promise<void> {
    if (this.togglingName !== '') {
      return;
    }
    this.togglingName = name;
    const joined: boolean = this.isJoined(name);
    try {
      if (joined) {
        await unfollowTag(name);
        this.joinedNames = this.joinedNames.filter((n: string) => n !== name);
        safeShowToast(this.getUIContext(), { message: '已退出「' + name + '」' });
      } else {
        await followTag(name);
        const next: string[] = this.joinedNames.slice();
        next.push(name);
        this.joinedNames = next;
        safeShowToast(this.getUIContext(), { message: '已加入「' + name + '」' });
      }
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: '操作失败：' + (e as Error).message });
    } finally {
      this.togglingName = '';
    }
  }

  @Builder
  circleCard(c: Tag): void {
    Column({ space: 10 }) {
      // 线条图标 + 圈子名
      Column({ space: 6 }) {
        TagIcon({ name: c.name ?? '', iconSize: 40, tint: $r('app.color.brand_primary') })
        Text(c.name ?? '')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text((c.useCount ?? 0) + ' 人加入')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // 加入/已加入按钮
      Button(this.isJoined(c.name ?? '') ? '已加入' : '加入圈子')
        .width('100%')
        .height(32)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .enabled(this.togglingName !== (c.name ?? ''))
        .backgroundColor(this.isJoined(c.name ?? '')
          ? $r('app.color.bg_secondary')
          : $r('app.color.brand_primary'))
        .fontColor(this.isJoined(c.name ?? '')
          ? $r('app.color.brand_primary')
          : '#FFFFFF')
        .border(this.isJoined(c.name ?? '')
          ? { width: 1, color: $r('app.color.brand_primary') }
          : { width: 0 })
        .borderRadius(16)
        .onClick(() => { this.toggleJoin(c.name ?? ''); })
    }
    .width('100%')
    .padding(CARD_PADDING)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(CARD_RADIUS)
    .shadow(CARD_SHADOW)
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
                  this.circleCard(c)
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