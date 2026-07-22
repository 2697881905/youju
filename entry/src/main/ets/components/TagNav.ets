import { Tag } from '../models/types';
import { TagIcon } from './TagIcon';

@Component
export struct TagNav {
  @Prop tags: Tag[] = [];
  @Link selectedIndex: number;
  @State showDropdown: boolean = false;
  @State filterName: string = '';

  private get displayTags(): Tag[] {
    if (this.filterName.length === 0) {
      return this.tags;
    }
    return this.tags.filter((t: Tag) => (t.name ?? '') === this.filterName);
  }

  build() {
    Column() {
      // 标签横向滚动 + 下拉按钮
      Row() {
        Scroll() {
          Row() {
            ForEach(
              this.tags,
              (tag: Tag, index: number) => {
                Row({ space: 4 }) {
                  TagIcon({
                    name: tag.name ?? '',
                    size: 14,
                    tint: this.selectedIndex === index ? '#FFFFFF' : $r('app.color.text_primary'),
                  })
                  Text(tag.name ?? '')
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.selectedIndex === index ? '#FFFFFF' : $r('app.color.text_primary'))
                }
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor(this.selectedIndex === index ? $r('app.color.brand_primary') : $r('app.color.card_bg'))
                .borderRadius(16)
                .onClick(() => {
                  if (this.selectedIndex !== index) {
                    this.selectedIndex = index;
                  }
                })
              },
              (tag: Tag) => tag.id?.toString() ?? (tag.name ?? '')
            );
          }
          .padding({ left: 12, right: 12 });
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)

        // 下拉按钮
        Row({ space: 4 }) {
          Text('▼')
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
        }
        .width(32)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(255,255,255,0.06)')
        .borderRadius(14)
        .margin({ right: 12 })
        .onClick(() => { this.showDropdown = !this.showDropdown; })
      }
      .width('100%')
      .padding({ bottom: 4 })

      // 下拉面板
      if (this.showDropdown) {
        Scroll() {
          Column({ space: 0 }) {
            Row({ space: 8 }) {
              TagIcon({ name: '全部', size: 16, tint: $r('app.color.text_primary') })
              Text('全部圈子')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 12, bottom: 12 })
            .onClick(() => {
              this.filterName = '';
              this.showDropdown = false;
              this.selectedIndex = 0;
            })

            Divider().color('rgba(255,255,255,0.1)')

            ForEach(
              this.tags,
              (t: Tag) => {
                Row({ space: 8 }) {
                  TagIcon({
                    name: t.name ?? '',
                    size: 16,
                    tint: this.filterName === t.name ? $r('app.color.brand_primary') : $r('app.color.text_primary'),
                  })
                  Text(t.name ?? '')
                    .fontSize(14)
                    .fontColor(this.filterName === t.name ? $r('app.color.brand_primary') : $r('app.color.text_primary'))
                }
                .width('100%')
                .padding({ left: 20, right: 20, top: 12, bottom: 12 })
                .onClick(() => {
                  this.filterName = t.name ?? '';
                  this.showDropdown = false;
                  // 找到对应 tag 的 index
                  const idx = this.tags.indexOf(t);
                  if (idx >= 0) {
                    this.selectedIndex = idx;
                  }
                })
              },
              (t: Tag) => t.name ?? ''
            )
          }
          .width('100%')
        }
        .height(Math.min(this.tags.length * 48 + 48, 320))
        .width('100%')
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(12)
        .margin({ left: 12, right: 12, bottom: 8 })
      }
    }
    .width('100%')
  }
}
