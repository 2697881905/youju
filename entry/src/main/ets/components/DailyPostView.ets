/**
 * 每日一帖的 Apple-inspired light surface 版本。
 * 组件自带两条 mock 数据，可直接放入预览页；接入真实接口时传入 posts 即可。
 */
export type PostType = 'text' | 'image';

export interface Post {
  id: number;
  type: PostType;
  content: string;
  imageUrl?: string;
  title: string;
  author: string;
  avatar: string;
}

const MOCK_POSTS: Post[] = [
  {
    id: 1,
    type: 'text',
    content: '真正重要的事，往往值得慢一点决定。',
    title: '给今天留一点余地',
    author: '林默',
    avatar: '林',
  },
  {
    id: 2,
    type: 'image',
    content: '一段安静的路，也能带来新的答案。',
    imageUrl: 'https://images.unsplash.com/photo-1500534623283-312aade485b7?w=1200&q=85',
    title: '周末去看一场日落',
    author: '周予安',
    avatar: '周',
  },
];

@Component
export struct DailyPostView {
  @Prop posts: Post[] = MOCK_POSTS;
  @State private activeIndex: number = 0;

  private readonly pageBackground: string = '#F2F2F7';
  private readonly cardBackground: string = '#FFFFFF';
  private readonly primaryText: string = '#1C1C1E';
  private readonly secondaryText: string = '#8E8E93';
  private readonly accent: string = '#007AFF';

  private nextCard(): void {
    if (this.posts.length === 0) {
      return;
    }
    this.activeIndex = (this.activeIndex + 1) % this.posts.length;
  }

  @Builder
  private avatar(post: Post): void {
    if (post.avatar.length > 0) {
      Text(post.avatar.slice(0, 1))
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
        .fontSize(14)
        .fontColor(this.secondaryText)
        .backgroundColor('#F2F2F7')
        .borderRadius(12);
    }
  }

  @Builder
  private textPostCard(post: Post): void {
    Column() {
      Text(post.content)
        .width('100%')
        .fontSize(28)
        .lineHeight(48)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryText)
        .textAlign(TextAlign.Center)
        .maxLines(5)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Column() {
        Text(post.title)
          .fontSize(15)
          .lineHeight(22)
          .fontColor(this.secondaryText)
          .margin({ bottom: 12 });
        Row({ space: 8 }) {
          this.avatar(post);
          Text(post.author)
            .fontSize(14)
            .fontColor(this.secondaryText);
        }
        .alignItems(VerticalAlign.Center);
      }
      .margin({ top: 40 })
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(40)
    .backgroundColor(this.cardBackground)
    .borderRadius(24)
    .shadow({ radius: 24, color: '#0A000000', offsetX: 0, offsetY: 12 });
  }

  @Builder
  private imagePostCard(post: Post): void {
    Stack({ alignContent: Alignment.Bottom }) {
      Image(post.imageUrl ?? '')
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .backgroundColor('#E5E5EA')
        .borderRadius({ topLeft: 24, topRight: 24, bottomLeft: 24, bottomRight: 24 })
        .clip(true);

      Row({ space: 12 }) {
        this.avatar(post);
        Column() {
          Text(post.title)
            .width('100%')
            .fontSize(18)
            .lineHeight(24)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(post.author)
            .fontSize(14)
            .lineHeight(20)
            .fontColor(this.secondaryText)
            .margin({ top: 4 });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('calc(100% - 32vp)')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor('rgba(255,255,255,0.7)')
      .backgroundBlurStyle(BlurStyle.Thin)
      .borderRadius(18)
      .margin({ left: 16, right: 16, bottom: 16 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.cardBackground)
    .borderRadius(24)
    .clip(true)
    .shadow({ radius: 24, color: '#0A000000', offsetX: 0, offsetY: 12 });
  }

  @Builder
  private stackedCard(post: Post, depth: number): void {
    Stack() {
      if (post.type === 'image') {
        this.imagePostCard(post);
      } else {
        this.textPostCard(post);
      }
    }
    .width('100%')
    .aspectRatio(0.75)
    .scale({ x: depth === 0 ? 1 : 0.95, y: depth === 0 ? 1 : 0.95 })
    .opacity(depth === 0 ? 1 : 0.6)
    .translate({ y: depth === 0 ? 0 : 20 })
    .zIndex(depth === 0 ? 2 : 1)
    .animation({ duration: 260, curve: Curve.EaseInOut })
    .onClick((): void => {
      if (depth === 0) {
        this.nextCard();
      }
    });
  }

  build() {
    Column({ space: 20 }) {
      Row() {
        Text('每日一帖')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText);
        Blank().layoutWeight(1);
        Text('今日精选')
          .fontSize(14)
          .fontColor(this.accent);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Stack({ alignContent: Alignment.Center }) {
        if (this.posts.length > 1) {
          this.stackedCard(this.posts[(this.activeIndex + 1) % this.posts.length], 1);
        }
        if (this.posts.length > 0) {
          this.stackedCard(this.posts[this.activeIndex], 0);
        } else {
          Text('暂无内容')
            .fontSize(17)
            .fontColor(this.secondaryText);
        }
      }
      .width('88%')
      .aspectRatio(0.75);

      Text('轻触卡片阅读下一帖')
        .fontSize(13)
        .fontColor(this.secondaryText)
        .width('100%')
        .textAlign(TextAlign.Center);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 20, right: 20, top: 24, bottom: 24 })
    .backgroundColor(this.pageBackground);
  }
}
