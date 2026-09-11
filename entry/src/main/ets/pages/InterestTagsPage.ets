// 兴趣标签管理页：查看 / 删除用于「每日一贴」个性化推荐的兴趣标签。
// 合规依据：《互联网信息服务算法推荐管理规定》第 17 条第 2 款——用户应能查看、选择、删除
// 用于个性化推荐的标签。删除即时生效，后端列表接口会立即反映。
// 复用 design system 令牌 + 共享 BackButton/EmptyState，与其它二级页 UI 统一。

import { listTags, listFollowedTags, followTag, unfollowTag } from '../services/api';
import { Tag } from '../models/types';
import { safeShowToast } from '../utils/toast';
import { buildPageTransition } from '../utils/styles';
import { barBottomReserve } from '../utils/cardTokens';
import { BackButton } from '../design/components/BackButton';
import { EmptyState } from '../design/components/EmptyState';
import { ColorTokens } from '../design/tokens/color';
import { IconTokens } from '../design/tokens/icon';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Entry
@Component
export struct InterestTagsPage {
  @State followed: string[] = [];
  @State allNames: string[] = [];
  @State loadFinished: boolean = false;
  @State loadError: string = '';
  @State busy: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.loadAll();
  }

  private async loadAll(): Promise<void> {
    this.loadError = '';
    this.loadFinished = false;
    try {
      const followed: string[] = await listFollowedTags();
      const tags: Tag[] = await listTags();
      const names: string[] = [];
      for (const tag of tags) {
        const name: string | undefined = tag.name;
        if (name !== undefined && name.length > 0) {
          names.push(name);
        }
      }
      this.followed = followed;
      this.allNames = names;
    } catch (e) {
      this.loadError = (e as Error).message;
    }
    this.loadFinished = true;
  }

  private availableNames(): string[] {
    const out: string[] = [];
    for (const name of this.allNames) {
      if (this.followed.indexOf(name) < 0) {
        out.push(name);
      }
    }
    return out;
  }

  private onRemove(name: string): void {
    this.getUIContext().showAlertDialog({
      title: '删除该兴趣标签？',
      message: '删除「' + name + '」后，个性化推荐将不再依据该标签为你推荐内容。',
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.semantic_red'),
        action: async (): Promise<void> => { await this.applyUnfollow(name); },
      },
    });
  }

  private async applyUnfollow(name: string): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      await unfollowTag(name);
      this.followed = this.followed.filter((item: string) => item !== name);
      safeShowToast(this.getUIContext(), { message: '已删除「' + name + '」' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
    this.busy = false;
  }

  private async onAdd(name: string): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      await followTag(name);
      this.followed = this.followed.concat([name]);
      safeShowToast(this.getUIContext(), { message: '已添加「' + name + '」' });
    } catch (e) {
      safeShowToast(this.getUIContext(), { message: (e as Error).message });
    }
    this.busy = false;
  }

  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
      .fontWeight(TypeTokens.caption.weight)
      .lineHeight(TypeTokens.caption.lineHeight)
      .fontColor(ColorTokens.secondary)
      .alignSelf(ItemAlign.Start)
      .padding({ left: SpaceTokens.inlineTight, bottom: SpaceTokens.inline });
  }

  // 已关注标签：点击删除
  @Builder
  private followedChips() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.followed, (name: string) => {
        Row({ space: SpaceTokens.inlineTight }) {
          Text(name)
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.callout.weight)
            .fontColor(ColorTokens.primary)
          Text('×')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontWeight(TypeTokens.headline.weight)
            .fontColor(ColorTokens.secondary)
        }
        .padding({ left: SpaceTokens.item, right: SpaceTokens.item, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
        .backgroundColor(ColorTokens.brandTint)
        .borderRadius(RadiusTokens.pill)
        .margin({ right: SpaceTokens.inline, bottom: SpaceTokens.inline })
        .onClick((): void => { this.onRemove(name); })
      }, (name: string) => 'followed-' + name)
    }
    .width('100%')
  }

  // 可添加标签：描边样式，点击添加
  @Builder
  private availableChips() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.availableNames(), (name: string) => {
        Text(name)
          .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.callout.weight)
          .fontColor(ColorTokens.secondary)
          .padding({ left: SpaceTokens.item, right: SpaceTokens.item, top: SpaceTokens.sm, bottom: SpaceTokens.sm })
          .borderRadius(RadiusTokens.pill)
          .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
          .margin({ right: SpaceTokens.inline, bottom: SpaceTokens.inline })
          .onClick((): void => { this.onAdd(name); })
      }, (name: string) => 'available-' + name)
    }
    .width('100%')
  }

  build() {
    Column() {
      // 顶栏：BackButton + 居中标题（与其它二级页一致）
      Row() {
        BackButton({ action: (): void => { this.getUIContext().getRouter().back(); } })
        Blank()
        Text('兴趣标签')
          .fontSize(TypeTokens.title.size).fontFamily(TypeTokens.fontFamilySerif)
          .fontWeight(TypeTokens.title.weight)
          .lineHeight(TypeTokens.title.lineHeight)
          .fontColor(ColorTokens.primary)
        Blank()
        Text('')
          .width(LayoutTokens.minTouchTarget)
          .height(LayoutTokens.minTouchTarget)
      }
      .width('100%')
      .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact, top: SpaceTokens.md, bottom: SpaceTokens.sm })
      .alignItems(VerticalAlign.Center)

      if (!this.loadFinished) {
        Column({ space: SpaceTokens.item }) {
          LoadingProgress().width(IconTokens.empty).height(IconTokens.empty).color(ColorTokens.secondary)
          Text('正在加载兴趣标签')
            .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
            .fontColor(ColorTokens.secondary)
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.loadError) {
        Column() {
          EmptyState({
            icon: $r('app.media.empty_inbox'),
            title: '加载失败',
            message: this.loadError,
            actionLabel: '重试',
            onAction: (): void => { this.loadAll(); },
          })
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: SpaceTokens.section }) {
            // 说明：这些标签的用途与删除效果
            Text('以下标签用于「每日一贴」的个性化推荐。你可以随时删除任意标签，删除后立即生效；也可以重新添加。')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.callout.weight)
              .lineHeight(TypeTokens.callout.lineHeight)
              .fontColor(ColorTokens.secondary)
              .width('100%')
              .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact })

            // 已关注
            Column({ space: SpaceTokens.none }) {
              this.sectionTitle('已关注的标签（' + this.followed.length + '）')
              if (this.followed.length === 0) {
                Text('暂无已关注的标签。你可以在「圈子」中关注感兴趣的标签，或从下方直接添加。')
                  .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
                  .lineHeight(TypeTokens.callout.lineHeight)
                  .fontColor(ColorTokens.tertiary)
                  .width('100%')
                  .padding({ left: SpaceTokens.inlineTight })
              } else {
                this.followedChips()
              }
            }
            .width('100%')
            .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact })

            // 可添加（按当前全量标签减去已关注）
            Column({ space: SpaceTokens.none }) {
              this.sectionTitle('可添加的标签')
              this.availableChips()
            }
            .width('100%')
            .padding({ left: SpaceTokens.pageCompact, right: SpaceTokens.pageCompact })

            // 底部预留：末行滚过系统导航区到达物理屏底的滚动余量
            Column() {
              Blank().width('100%').height(barBottomReserve())
            }
            .width('100%')
          }
          .width('100%')
          .padding({ top: SpaceTokens.base })
          .constraintSize({ minHeight: '100%' })
        }
        .layoutWeight(1).width('100%')
      }
    }
    .width('100%').padding({ top: this.statusBarHeight }).height('100%')
    .backgroundColor(ColorTokens.canvas)
    .transition(buildPageTransition())
  }
}
