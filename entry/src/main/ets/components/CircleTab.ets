// 圈子（Tab 内容）：用已有的标签体系渲染圈子卡片，支持加入/退出（后端持久化）
// 数据来源：listTags / followTag / unfollowTag / listFollowedTags（services/api.ets）
import { Tag } from '../models/types';
import { listTags, followTag, unfollowTag, listFollowedTags } from '../services/api';
import { ensureLogin } from '../utils/auth';
import { safeShowToast } from '../utils/toast';

@Component
export struct CircleTab {
  @State circles: Tag[] = [];
  @State joinedNames: string[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State togglingName: string = ''; // 正在切换的标签名，用于按钮禁用防并发
  @State filterName: string = ''; // 下拉筛选的圈子名（空=全部）
  @State showDropdown: boolean = false;

  private get filteredCircles(): Tag[] {
    if (this.filterName.length === 0) {
      return this.circles;
    }
    return this.circles.filter((t: Tag) => (t.name ?? '') === this.filterName);
  }

  aboutToAppear(): void {
    this.initData();
  }

  private async initData(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      await ensureLogin();
      // 并行加载圈子列表与已加入列表
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
      return; // 防止并发点击
    }
    this.togglingName = name;
    const joined: boolean = this.isJoined(name);
    try {
      if (joined) {
        await unfollowTag(name);
        this.joinedNames = this.joinedNames.filter((n: string) => n !== name);
        safeShowToast(this.getUIContext(),{ message: '已退出「' + name + '」' });
      } else {
        await followTag(name);
        const next: string[] = this.joinedNames.slice();
        next.push(name);
        this.joinedNames = next;
        safeShowToast(this.getUIContext(),{ message: '已加入「' + name + '」' });
      }
    } catch (e) {
      safeShowToast(this.getUIContext(),{ message: '操作失败：' + (e as Error).message });
    } finally {
      this.togglingName = '';
    }
  }

  @Builder
  circleCard(c: Tag): void {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(c.emoji ?? '📌')
          .fontSize(24)
        Column({ space: 2 }) {
          Text(c.name ?? '')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text((c.useCount ?? 0) + ' 人')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
      }
      .width('100%')

      Button(this.isJoined(c.name ?? '') ? '已加入' : '加入')
        .width('100%')
        .height(32)
        .fontSize(13)
        .enabled(this.togglingName !== (c.name ?? ''))
        .backgroundColor(this.isJoined(c.name ?? '') ? $r('app.color.bg_primary') : $r('app.color.brand_primary'))
        .fontColor(this.isJoined(c.name ?? '') ? $r('app.color.text_secondary') : Color.White)
        .onClick(() => { this.toggleJoin(c.name ?? ''); })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.bg_secondary'))
    .borderRadius(12)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
      // 圈子标题（右侧下拉筛选）
      Row() {
        Text('圈子')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        // 下拉筛选按钮
        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Row({ space: 4 }) {
            Text(this.filterName.length > 0 ? this.filterName : '全部圈子')
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 80 })
            Text('▼')
              .fontSize(10)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .height(28)
        .backgroundColor('rgba(255,255,255,0.06)')
        .border({ width: 0.5, color: 'rgba(255,255,255,0.12)' })
        .borderRadius(14)
        .onClick(() => { this.showDropdown = !this.showDropdown; })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 8 })

      if (this.circles.length === 0 && this.loading) {
        Column() {
          LoadingProgress().width(28).height(28)
          Text('加载中…').fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 10 })
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
              .fontColor(Color.White)
              .onClick(() => { this.initData(); })
          }
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Grid() {
            ForEach(
              this.filteredCircles,
              (c: Tag) => {
                GridItem() {
                  this.circleCard(c)
                }
              },
              (c: Tag) => c.name ?? ''
            )
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(12)
          .rowsGap(12)
          .padding(12)
          .layoutWeight(1)
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_primary'))
    }

    // 下拉筛选面板（浮层）
    if (this.showDropdown) {
      Column() {
        Scroll() {
          Column({ space: 0 }) {
            Row() {
              Text('全部圈子')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .onClick(() => {
              this.filterName = '';
              this.showDropdown = false;
            })

            Divider().color('rgba(255,255,255,0.1)')

            ForEach(
              this.circles,
              (c: Tag) => {
                Row() {
                  Text(c.emoji ?? '').fontSize(14).margin({ right: 8 })
                  Text(c.name ?? '')
                    .fontSize(14)
                    .fontColor(this.filterName === c.name ? $r('app.color.brand_primary') : $r('app.color.text_primary'))
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .onClick(() => {
                  this.filterName = c.name ?? '';
                  this.showDropdown = false;
                })
              },
              (c: Tag) => c.name ?? ''
            )
          }
          .width('100%')
        }
        .height(Math.min(this.circles.length * 48 + 48, 320))
        .width('100%')
        .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK)
        .backgroundColor('rgba(0,0,0,0.9)')
        .borderRadius({ bottomLeft: 12, bottomRight: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 50 })
    }
  }
}
