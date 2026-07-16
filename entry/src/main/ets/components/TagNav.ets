import { Tag } from '../models/types';

@Component
export struct TagNav {
  @Prop tags: Tag[] = [];
  @Link selectedIndex: number;

  build() {
    Scroll() {
      Row() {
        ForEach(
          this.tags,
          (tag: Tag, index: number) => {
            Text((tag.emoji ?? '') + ' ' + (tag.name ?? ''))
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.selectedIndex === index ? $r('app.color.brand_primary') : $r('app.color.card_bg'))
              .fontColor(this.selectedIndex === index ? '#FFFFFF' : $r('app.color.text_primary'))
              .borderRadius(16)
              .onClick(() => {
                if (this.selectedIndex !== index) {
                  this.selectedIndex = index;
                }
              });
          },
          (tag: Tag) => tag.id?.toString() ?? (tag.name ?? '')
        );
      }
      .padding({ left: 12, right: 12 });
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%');
  }
}
