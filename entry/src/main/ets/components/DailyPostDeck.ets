import { DailyPost } from '../models/types';
import { resolveDisplayImageUrl } from '../services/api';
import { ColorTokens } from '../design/tokens/color';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { RadiusTokens } from '../design/tokens/radius';
import { LayoutTokens, SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

@Component
export struct DailyPostDeck {
  @Prop @Watch('resetDeck') deckVersion: number = 0;
  @Prop posts: DailyPost[] = [];
  @Prop loading: boolean = false;
  @Prop finished: boolean = false;
  onLoadMore?: () => void = undefined;
  onOpen?: (post: DailyPost) => void = undefined;

  @State activeIndex: number = 0;
  @State dragOffsetX: number = 0;
  @State advancing: boolean = false;
  @State deckWidth: number = 0;
  @State presentationVersion: number = 0;
  @State reflowOffsetX: number = 0;
  @State reflowScale: number = 1;

  private readonly fanStepX: number = 18;
  private readonly fanStepY: number = 8;
  private readonly fanStepAngle: number = 4;
  private readonly dismissRatio: number = 0.3;
  private readonly deckVisualScale: number = 1.06;

  resetDeck(): void {
    this.activeIndex = 0;
    this.dragOffsetX = 0;
    this.advancing = false;
    this.presentationVersion += 1;
    this.reflowOffsetX = 0;
    this.reflowScale = 1;
  }

  private hasMedia(post: DailyPost): boolean {
    return (post.videoUrl ?? '').length > 0 || (post.videoCover ?? '').length > 0 || (post.coverImage ?? '').length > 0;
  }

  private mediaUrl(post: DailyPost): string {
    if ((post.videoCover ?? '').length > 0) {
      return post.videoCover ?? '';
    }
    return post.coverImage ?? '';
  }

  private genreLabel(genre?: string): string {
    if (genre === 'review') {
      return '测评';
    }
    if (genre === 'pitfall') {
      return '避坑';
    }
    if (genre === 'tutorial') {
      return '教程';
    }
    if (genre === 'debate') {
      return '讨论';
    }
    if (genre === 'share') {
      return '分享';
    }
    return '今日内容';
  }

  private visibleDepths(): number[] {
    const depths: number[] = [];
    for (let depth = 2; depth >= 0; depth--) {
      if (this.activeIndex + depth < this.posts.length) {
        depths.push(depth);
      }
    }
    return depths;
  }

  private cardOffsetX(depth: number): number {
    if (depth === 0) {
      return this.dragOffsetX;
    }
    return -depth * this.fanStepX;
  }

  private cardOffsetY(depth: number): number {
    return depth * this.fanStepY;
  }

  private cardAngle(depth: number): number {
    if (depth === 0) {
      const width = Math.max(this.deckWidth, 1);
      return Math.min(this.dragOffsetX / width, 1) * this.fanStepAngle;
    }
    return -depth * this.fanStepAngle;
  }

  private cardScale(depth: number): number {
    return 1 - depth * 0.028;
  }

  private dismissDistance(): number {
    return Math.max(this.deckWidth, 1) * this.deckVisualScale * this.dismissRatio;
  }

  private exitDistance(): number {
    return Math.max(this.deckWidth * this.deckVisualScale + SpaceTokens.x3l, 480);
  }

  private resetDrag(): void {
    this.getUIContext().animateTo({ duration: MotionTokens.container, curve: MotionCurves.springSoft }, () => {
      this.dragOffsetX = 0;
    });
  }

  private advance(): void {
    if (this.advancing || this.activeIndex >= this.posts.length) {
      return;
    }
    this.advancing = true;
    this.getUIContext().animateTo({ duration: MotionTokens.container, curve: MotionCurves.accelerate }, () => {
      this.dragOffsetX = this.exitDistance();
    });
    setTimeout((): void => {
      this.activeIndex += 1;
      this.dragOffsetX = 0;
      // ArkUI 复用 ForEach 节点时不会稳定刷新闭包中的扇形深度；切换展示层以确保新顶卡可交互。
      this.presentationVersion += 1;
      this.reflowOffsetX = -SpaceTokens.lg;
      this.reflowScale = 0.98;
      this.advancing = false;
      this.getUIContext().animateTo({ duration: MotionTokens.emphasis, curve: MotionCurves.springSoft }, () => {
        this.reflowOffsetX = 0;
        this.reflowScale = 1;
      });
      if (this.activeIndex >= this.posts.length - 3 && !this.finished) {
        this.onLoadMore?.();
      }
    }, MotionTokens.container);
  }

  private onTopPanUpdate(event: GestureEvent): void {
    if (this.advancing) {
      return;
    }
    this.dragOffsetX = Math.max(0, event.offsetX);
  }

  private onTopPanEnd(): void {
    if (this.advancing) {
      return;
    }
    if (this.dragOffsetX >= this.dismissDistance()) {
      this.advance();
      return;
    }
    this.resetDrag();
  }

  private openActivePost(): void {
    const activePost = this.posts[this.activeIndex];
    if (!this.advancing && activePost !== undefined) {
      this.onOpen?.(activePost);
    }
  }

  @Builder
  private textSurface(post: DailyPost): void {
    Column() {
      Text(post.content ?? post.title ?? '')
        .fontSize(TypeTokens.display.size).fontFamily(TypeTokens.fontFamilySerif)
        .fontWeight(TypeTokens.display.weight)
        .lineHeight(TypeTokens.display.lineHeight)
        .fontColor(ColorTokens.primary)
        .maxLines(5)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .padding({ left: SpaceTokens.xl, right: SpaceTokens.xl })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(ColorTokens.elevated)
    .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
  }

  @Builder
  private postFace(post: DailyPost): void {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.hasMedia(post)) {
        Image(resolveDisplayImageUrl(this.mediaUrl(post)))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .backgroundColor(ColorTokens.sunken)
      } else {
        this.textSurface(post)
      }
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column({ space: SpaceTokens.xs }) {
          Text(post.title ?? '一条值得读的经验')
            .fontSize(TypeTokens.headline.size).fontFamily(TypeTokens.fontFamilySerif)
            .fontWeight(TypeTokens.headline.weight)
            .lineHeight(TypeTokens.headline.lineHeight)
            .fontColor(ColorTokens.primary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Center)
          Row({ space: SpaceTokens.xs }) {
            if ((post.user?.avatar ?? '').length > 0) {
              Image(resolveDisplayImageUrl(post.user?.avatar ?? ''))
                .width(SpaceTokens.base)
                .height(SpaceTokens.base)
                .borderRadius(RadiusTokens.pill)
                .objectFit(ImageFit.Cover)
            } else {
              Text((post.user?.nickname ?? '有据用户').slice(0, 1))
                .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
                .fontWeight(TypeTokens.overline.weight)
                .fontColor(ColorTokens.brand)
                .width(SpaceTokens.base)
                .height(SpaceTokens.base)
                .textAlign(TextAlign.Center)
                .backgroundColor(ColorTokens.brandTint)
                .borderRadius(RadiusTokens.pill)
            }
            Text(post.user?.nickname ?? '有据用户')
              .fontSize(TypeTokens.caption.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.caption.weight)
              .fontColor(ColorTokens.secondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        Text(this.genreLabel(post.genre))
          .fontSize(TypeTokens.overline.size).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.overline.weight)
          .fontColor(ColorTokens.tertiary)
      }
      .width('100%')
      .height(92)
      .padding({ left: SpaceTokens.base, right: SpaceTokens.base, top: SpaceTokens.sm, bottom: SpaceTokens.md })
      .backgroundColor(ColorTokens.elevated)
      .border({ width: 1, color: ColorTokens.separator, style: BorderStyle.Solid })
      .borderRadius({ topLeft: RadiusTokens.lg, topRight: RadiusTokens.lg, bottomLeft: 0, bottomRight: 0 })
    }
    .width('100%')
    .aspectRatio(LayoutTokens.cardMediaAspectRatio)
    .backgroundColor(ColorTokens.sunken)
    .borderRadius(RadiusTokens.xl)
    .clip(true)
    .shadow({ radius: 16, color: ColorTokens.barShadow, offsetY: 7 })
  }

  @Builder
  private stackedCard(depth: number, post: DailyPost): void {
    Stack() {
      this.postFace(post)
    }
      .width('88%')
      .aspectRatio(LayoutTokens.cardMediaAspectRatio)
      .translate({ x: this.cardOffsetX(depth), y: this.cardOffsetY(depth) })
      .scale({ x: this.cardScale(depth), y: this.cardScale(depth) })
      .rotate({ angle: this.cardAngle(depth), centerX: '50%', centerY: '100%' })
      .opacity(1 - depth * 0.1)
      .zIndex(10 - depth)
      .animation({ duration: MotionTokens.enter, curve: MotionCurves.springSoft })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 舞台固定接收手势，展示层按推进版本刷新，避免复用后的旧深度与手势闭包。
      Stack({ alignContent: Alignment.Center }) {
        ForEach(this.visibleDepths(), (depth: number) => {
          this.stackedCard(depth, this.posts[this.activeIndex + depth])
        }, (depth: number) => this.presentationVersion.toString() + '_' + (this.activeIndex + depth).toString())
        if (this.activeIndex >= this.posts.length && this.loading) {
          Column() {
            LoadingProgress().width(36).height(36)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.activeIndex >= this.posts.length && this.finished) {
          Column() {
            Text('今日内容已读完')
              .fontSize(TypeTokens.callout.size).fontFamily(TypeTokens.fontFamily)
              .fontWeight(TypeTokens.callout.weight)
              .fontColor(ColorTokens.secondary)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .aspectRatio(LayoutTokens.cardMediaAspectRatio)
      .translate({ x: this.reflowOffsetX })
      .scale({ x: this.reflowScale * this.deckVisualScale, y: this.reflowScale * this.deckVisualScale })
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal, distance: 4 })
          .onActionUpdate((event: GestureEvent): void => { this.onTopPanUpdate(event); })
          .onActionEnd((): void => { this.onTopPanEnd(); })
          .onActionCancel((): void => { this.resetDrag(); })
      )
      .onClick((): void => { this.openActivePost(); })
    }
    .width('100%')
    .height('100%')
    .padding({ left: SpaceTokens.lg, right: SpaceTokens.lg, top: SpaceTokens.sm })
    // 内容区包含底部悬浮导航的预留空间，视觉中心需略向上校正。
    .translate({ y: -(SpaceTokens.x2l + SpaceTokens.lg) })
    .onAreaChange((_old: Area, next: Area) => {
      this.deckWidth = next.width as number;
    })
  }
}
