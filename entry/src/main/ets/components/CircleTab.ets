// 圈子（Tab 内容）：用已有的标签体系渲染圈子卡片，支持加入/退出
// 数据来源：listTags（services/api.ets）
import { promptAction } from '@kit.ArkUI';
import { Tag } from '../models/types';
import { listTags } from '../services/api';

@Component
export struct CircleTab {
  @State circles: Tag[] = [];
  @State joinedNames: string[] = [];
  @State loading: boolean = false;
  @State error: string = '';

  aboutToAppear(): void {
    this.loadCircles();
  }

  async loadCircles(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      this.circles = await listTags();
    } catch (e) {
      this.error = (e as Error).message;
      this.circles = [];
    } finally {
      this.loading = false;
    }
  }

  private isJoined(name: string): boolean {
    return this.joinedNames.indexOf(name) >= 0;
  }

  private toggleJoin(name: string): void {
    if (this.isJoined(name)) {
      this.joinedNames = this.joinedNames.filter((n: string) => n !== name);
      promptAction.showToast({ message: '已退出「' + name + '」' });
    } else {
      this.joinedNames = [...this.joinedNames, name];
      promptAction.showToast({ message: '已加入「' + name + '」' });
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
        .backgroundColor(this.isJoined(c.name ?? '') ? $r('app.color.bg_primary') : $r('app.color.brand_primary'))
        .fontColor(this.isJoined(c.name ?? '') ? $r('app.color.text_secondary') : Color.White)
        .onClick(() => this.toggleJoin(c.name ?? ''))
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.bg_secondary'))
    .borderRadius(12)
  }

  build() {
    Column() {
      // 圈子标题
      Text('圈子')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .padding({ left: 16, top: 10, bottom: 8 })

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
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
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
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .padding(12)
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_primary'))
  }
}
