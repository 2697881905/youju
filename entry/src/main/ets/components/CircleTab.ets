// 圈子 — Apple 风格卡片网格
// 展示所有标签圈子，支持加入/退出（后端持久化）
// 数据来源：listTags / followTag / unfollowTag / listFollowedTags
//
// 关键实现说明（ArkUI 更新机制）：
//   之前用「@State 数组整体替换 + ForEach + @Prop 子组件」，
//   在 ForEach 对 key 相同的项进行组件复用时不重新初始化 @Prop，导致 followCount 变化不刷新。
//   现改为官方推荐的 @Observed + @ObjectLink：CircleTag 为 @Observed 类，
//   点击时原地修改其属性（followCount/joined/toggling），@ObjectLink 必然触发子组件重渲染。

import { Tag, User } from '../models/types';
import { TagIcon } from './TagIcon';
import { listTags, followTag, unfollowTag, listFollowedTags } from '../services/api';
import { ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';
import { observeGridColumns, gridColumnTemplate } from '../utils/responsive';
import { CARD_RADIUS, CARD_PADDING, CARD_SHADOW, GRID_GAP, GRID_PADDING } from '../utils/cardTokens';
import { common } from '@kit.AbilityKit';

// 用 @Observed 包装：使「数组中对象属性变化」能驱动子组件重渲染
@Observed
class CircleTag {
  id?: number;
  name?: string;
  emoji?: string;
  category?: string;
  useCount?: number;
  followCount?: number;
  joined: boolean = false;
  toggling: boolean = false;

  constructor(t: Tag) {
    this.id = t.id;
    this.name = t.name;
    this.emoji = t.emoji;
    this.category = t.category;
    this.useCount = t.useCount;
    this.followCount = t.followCount;
  }
}

@Component
struct CircleCard {
  @ObjectLink item: CircleTag;
  // 普通属性（回调）：由父组件在 ForEach 中传入，非 @Prop/@Link
  onToggle: () => void = () => {};

  build() {
    Column({ space: 10 }) {
      Column({ space: 6 }) {
        TagIcon({ name: this.item.name ?? '', iconSize: 40, tint: $r('app.color.brand_primary') })
        Text(this.item.name ?? '')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text((this.item.followCount ?? 0) + ' 人加入')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Button(this.item.joined ? '已加入' : '加入圈子')
        .width('100%')
        .height(32)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .enabled(!this.item.toggling)
        .backgroundColor(this.item.joined ? $r('app.color.bg_secondary') : $r('app.color.brand_primary'))
        .fontColor(this.item.joined ? $r('app.color.brand_primary') : '#FFFFFF')
        .border(this.item.joined ? { width: 1, color: $r('app.color.brand_primary') } : { width: 0 })
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
  @State circles: CircleTag[] = [];
  @State joinedNames: string[] = [];
  @State loading: boolean = false;
  @State error: string = '';
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
      const tags: Tag[] = await listTags();
      const followed: string[] = await listFollowedTags();
      this.circles = tags.map((t: Tag): CircleTag => {
        const ct: CircleTag = new CircleTag(t);
        ct.joined = followed.indexOf(t.name ?? '') >= 0;
        return ct;
      });
      this.joinedNames = followed;
    } catch (e) {
      this.error = (e as Error).message;
      this.circles = [];
      this.joinedNames = [];
    } finally {
      this.loading = false;
    }
  }

  // 把服务端最新数据同步到本地 @Observed 对象（原地改属性，触发 @ObjectLink 重渲染）
  // 注意：不整体替换数组，以免断开 @ObjectLink 绑定
  private async refreshCircles(): Promise<void> {
    const tags: Tag[] = await listTags();
    const followed: string[] = await listFollowedTags();
    this.joinedNames = followed;
    for (const t of tags) {
      const idx: number = this.circles.findIndex((c: CircleTag) => c.name === t.name);
      if (idx >= 0) {
        this.circles[idx].followCount = t.followCount ?? 0;
        this.circles[idx].useCount = t.useCount;
        this.circles[idx].joined = followed.indexOf(t.name ?? '') >= 0;
      }
    }
  }

  private async toggleJoin(name: string): Promise<void> {
    const idx: number = this.circles.findIndex((c: CircleTag) => c.name === name);
    if (idx < 0) {
      return;
    }
    if (this.circles[idx].toggling) {
      return;
    }
    const wasJoined: boolean = this.circles[idx].joined;
    const delta: number = wasJoined ? -1 : 1;

    // 乐观更新：原地修改 @Observed 对象属性，@ObjectLink 立即刷新（无需等待网络）
    this.circles[idx].toggling = true;
    this.circles[idx].followCount = (this.circles[idx].followCount ?? 0) + delta;
    this.circles[idx].joined = !wasJoined;
    this.joinedNames = wasJoined
      ? this.joinedNames.filter((n: string) => n !== name)
      : this.joinedNames.concat([name]);

    try {
      if (wasJoined) {
        await unfollowTag(name);
        safeShowToast(this.getUIContext(), { message: '已退出「' + name + '」' });
      } else {
        await followTag(name);
        safeShowToast(this.getUIContext(), { message: '已加入「' + name + '」' });
      }
      // 权威同步：把服务端真值写回本地 @Observed 对象
      await this.refreshCircles();
    } catch (e) {
      // 失败回滚乐观更新
      this.circles[idx].followCount = (this.circles[idx].followCount ?? 0) - delta;
      this.circles[idx].joined = wasJoined;
      this.joinedNames = wasJoined
        ? this.joinedNames.concat([name])
        : this.joinedNames.filter((n: string) => n !== name);
      safeShowToast(this.getUIContext(), { message: '操作失败：' + (e as Error).message });
    } finally {
      this.circles[idx].toggling = false;
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
              (c: CircleTag) => {
                GridItem() {
                  CircleCard({
                    item: c,
                    onToggle: () => { this.toggleJoin(c.name ?? ''); }
                  })
                }
              },
              (c: CircleTag) => c.name ?? ''
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
