import { TagIcon } from './TagIcon';
import { resolveDisplayImageUrl } from '../services/api';
import { ColorTokens } from '../design/tokens/color';
import { MotionCurves, MotionTokens } from '../design/tokens/motion';
import { SpaceTokens } from '../design/tokens/space';
import { TypeTokens } from '../design/tokens/type';

export interface OrbitCircleItem {
  name: string;
  followCount: number;
  size: number;
  ring: number;
  baseAngle: number;
}

interface StarDot {
  x: number;
  y: number;
  size: number;
}

const STAR_DOTS: StarDot[] = [
  { x: 8, y: 14, size: 2 }, { x: 22, y: 33, size: 3 }, { x: 79, y: 8, size: 2 },
  { x: 93, y: 27, size: 2 }, { x: 11, y: 72, size: 2 }, { x: 88, y: 82, size: 3 },
  { x: 39, y: 92, size: 2 }, { x: 67, y: 65, size: 2 },
];

const PLANET_BOX_WIDTH: number = 64;
const PLANET_BOX_HEIGHT: number = 86;
const PLANET_ICON_HIT_SIZE: number = 40;
const CENTER_AVATAR_SIZE: number = 64;
const RIPPLE_FIRST_SIZE: number = 68;
const RIPPLE_SECOND_SIZE: number = 88;
const RIPPLE_CYCLE_DURATION: number = 920;
const RIPPLE_STAGGER: number = 180;

// 纯视图星环：父页面负责角度、惯性和暂停规则，本组件只消费计算后的轨道与行星坐标。
@Component
export struct CircleOrbitCanvas {
  @Prop galaxySize: number = 343;
  @Prop ringAngles: number[] = [0, 0, 0];
  @Prop radii: number[] = [0, 0, 0];
  @Prop circles: OrbitCircleItem[] = [];
  @Prop selectedName: string = '';
  @Prop centeredName: string = '';
  @Prop ringDragging: boolean = false;
  @Prop reduceMotion: boolean = false;
  @Prop avatar: string = '';
  @Prop nickname: string = '';
  onPlanet: (name: string) => void = (_name: string): void => {};
  onPanStart: () => void = (): void => {};
  onPanUpdate: (event: GestureEvent) => void = (_event: GestureEvent): void => {};
  onPanEnd: () => void = (): void => {};

  private angleFor(ring: number): number {
    return this.ringAngles[ring] ?? 0;
  }

  private radiusFor(ring: number): number {
    return this.radii[ring] ?? 0;
  }

  private circlesFor(ring: number): OrbitCircleItem[] {
    return this.circles.filter((circle: OrbitCircleItem): boolean => circle.ring === ring);
  }

  @Builder
  private starDots(): void {
    ForEach(STAR_DOTS, (dot: StarDot, index: number) => {
      Circle()
        .width(dot.size)
        .height(dot.size)
        .fill(ColorTokens.tertiary)
        .opacity(0.05)
        .position({ x: this.galaxySize * dot.x / 100, y: this.galaxySize * dot.y / 100 })
        .hitTestBehavior(HitTestMode.None)
    }, (_dot: StarDot, index: number) => 'star_' + index)
  }

  @Builder
  private orbitRing(ring: number): void {
    OrbitRingLayer({
      galaxySize: this.galaxySize,
      radius: this.radiusFor(ring),
      ringAngle: this.angleFor(ring),
      circles: this.circlesFor(ring),
      selectedName: this.selectedName,
      centeredName: this.centeredName,
      ringDragging: this.ringDragging,
      reduceMotion: this.reduceMotion,
      onPlanet: (name: string): void => { this.onPlanet(name); },
    })
  }

  @Builder
  private coreStar(): void {
    Stack({ alignContent: Alignment.Center }) {
      if (this.avatar.length > 0) {
        Image(resolveDisplayImageUrl(this.avatar))
          .width(CENTER_AVATAR_SIZE)
          .height(CENTER_AVATAR_SIZE)
          .borderRadius(CENTER_AVATAR_SIZE / 2)
          .objectFit(ImageFit.Cover)
          .clip(true)
      } else {
        Text(this.nickname.trim().length > 0 ? this.nickname.trim().charAt(0) : '?')
          .width(CENTER_AVATAR_SIZE)
          .height(CENTER_AVATAR_SIZE)
          .borderRadius(CENTER_AVATAR_SIZE / 2)
          .fontSize(CENTER_AVATAR_SIZE * 0.42).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.title.weight)
          .fontColor(ColorTokens.onBrand)
          .textAlign(TextAlign.Center)
          .backgroundColor(ColorTokens.brand)
      }
    }
    .width(CENTER_AVATAR_SIZE)
    .height(CENTER_AVATAR_SIZE)
    .borderRadius(CENTER_AVATAR_SIZE / 2)
    .clip(true)
    .position({ x: this.galaxySize / 2 - CENTER_AVATAR_SIZE / 2, y: this.galaxySize / 2 - CENTER_AVATAR_SIZE / 2 })
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [this.galaxySize / 2, this.galaxySize * 0.44],
          radius: this.galaxySize * 0.56,
          colors: [[ColorTokens.brandTint, 0], [ColorTokens.glassClear, 1]],
        })
      this.starDots()
      this.coreStar()
      this.orbitRing(0)
      this.orbitRing(1)
      this.orbitRing(2)
    }
    .width(this.galaxySize)
    .height(this.galaxySize)
    .clip(false)
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 2 })
        .onActionStart((): void => { this.onPanStart(); })
        .onActionUpdate((event: GestureEvent): void => { this.onPanUpdate(event); })
        .onActionEnd((): void => { this.onPanEnd(); })
        .onActionCancel((): void => { this.onPanEnd(); })
    )
  }
}

// 每条圆环与所属 Logo 共享同一份圆心、半径和实时角度，作为一个运动单元渲染。
@Component
struct OrbitRingLayer {
  @Prop galaxySize: number = 343;
  @Prop radius: number = 0;
  @Prop ringAngle: number = 0;
  @Prop circles: OrbitCircleItem[] = [];
  @Prop selectedName: string = '';
  @Prop centeredName: string = '';
  @Prop ringDragging: boolean = false;
  @Prop reduceMotion: boolean = false;
  onPlanet: (name: string) => void = (_name: string): void => {};

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Circle()
        .width(this.radius * 2)
        .height(this.radius * 2)
        .fill(Color.Transparent)
        .stroke(ColorTokens.secondary)
        .strokeWidth(1.5)
        .strokeDashArray([4, 6])
        .opacity(0.82)
        .position({ x: this.galaxySize / 2 - this.radius, y: this.galaxySize / 2 - this.radius })
        .rotate({ angle: this.ringAngle, centerX: '50%', centerY: '50%' })
        .animation({ duration: this.reduceMotion || this.ringDragging ? MotionTokens.instant : MotionTokens.fast, curve: MotionCurves.standard })
        .hitTestBehavior(HitTestMode.None)
      ForEach(this.circles, (circle: OrbitCircleItem) => {
        OrbitPlanet({
          name: circle.name,
          followCount: circle.followCount,
          planetSize: circle.size,
          selectedName: this.selectedName,
          centeredName: this.centeredName,
          galaxySize: this.galaxySize,
          radius: this.radius,
          baseAngle: circle.baseAngle,
          ringAngle: this.ringAngle,
          reduceMotion: this.reduceMotion,
          onPlanet: (name: string): void => { this.onPlanet(name); },
        })
      }, (circle: OrbitCircleItem) => circle.name)
    }
    .width(this.galaxySize)
    .height(this.galaxySize)
    .hitTestBehavior(HitTestMode.Transparent)
  }
}

// 独立组件使用标量 @Prop 和 translate 更新坐标，避免 keyed ForEach 复用静态 position。
@Component
struct OrbitPlanet {
  @Prop name: string = '';
  @Prop followCount: number = 0;
  @Prop planetSize: number = 46;
  @Prop selectedName: string = '';
  @Prop @Watch('onCenteredNameChanged') centeredName: string = '';
  @Prop galaxySize: number = 343;
  @Prop radius: number = 0;
  @Prop baseAngle: number = 0;
  @Prop ringAngle: number = 0;
  @Prop reduceMotion: boolean = false;
  @State firstRippleScale: number = 0.72;
  @State firstRippleOpacity: number = 0;
  @State secondRippleScale: number = 0.72;
  @State secondRippleOpacity: number = 0;
  private rippleArrivalTimer: number = 0;
  private rippleStaggerTimer: number = 0;
  private rippleCycleTimer: number = 0;
  onPlanet: (name: string) => void = (_name: string): void => {};

  aboutToAppear(): void {
    if (this.isCentered()) {
      this.scheduleRipple();
    }
  }

  aboutToDisappear(): void {
    this.stopRipple();
  }

  private isSelected(): boolean {
    return this.name === this.selectedName;
  }

  private isCentered(): boolean {
    return this.name === this.centeredName;
  }

  private onCenteredNameChanged(): void {
    if (this.isCentered()) {
      this.scheduleRipple();
    } else {
      this.stopRipple();
    }
  }

  private clearRippleTimers(): void {
    if (this.rippleArrivalTimer !== 0) {
      clearTimeout(this.rippleArrivalTimer);
      this.rippleArrivalTimer = 0;
    }
    if (this.rippleStaggerTimer !== 0) {
      clearTimeout(this.rippleStaggerTimer);
      this.rippleStaggerTimer = 0;
    }
    if (this.rippleCycleTimer !== 0) {
      clearTimeout(this.rippleCycleTimer);
      this.rippleCycleTimer = 0;
    }
  }

  private stopRipple(): void {
    this.clearRippleTimers();
    this.firstRippleOpacity = 0;
    this.secondRippleOpacity = 0;
  }

  private scheduleRipple(): void {
    this.stopRipple();
    if (this.reduceMotion) {
      this.firstRippleScale = 1.12;
      this.firstRippleOpacity = 0.22;
      return;
    }
    this.rippleArrivalTimer = setTimeout(() => {
      this.rippleArrivalTimer = 0;
      this.playRippleCycle();
    }, MotionTokens.emphasis) as number;
  }

  private animateRipple(first: boolean): void {
    if (!this.isCentered()) {
      return;
    }
    if (first) {
      this.firstRippleScale = 0.72;
      this.firstRippleOpacity = 0.42;
      this.getUIContext().animateTo({ duration: MotionTokens.emphasis, curve: MotionCurves.decelerate }, () => {
        this.firstRippleScale = 1.62;
        this.firstRippleOpacity = 0;
      });
    } else {
      this.secondRippleScale = 0.72;
      this.secondRippleOpacity = 0.28;
      this.getUIContext().animateTo({ duration: MotionTokens.emphasis, curve: MotionCurves.decelerate }, () => {
        this.secondRippleScale = 1.46;
        this.secondRippleOpacity = 0;
      });
    }
  }

  private playRippleCycle(): void {
    if (!this.isCentered() || this.reduceMotion) {
      return;
    }
    this.animateRipple(true);
    this.rippleStaggerTimer = setTimeout(() => {
      this.rippleStaggerTimer = 0;
      this.animateRipple(false);
    }, RIPPLE_STAGGER) as number;
    this.rippleCycleTimer = setTimeout(() => {
      this.rippleCycleTimer = 0;
      this.playRippleCycle();
    }, RIPPLE_CYCLE_DURATION) as number;
  }

  private left(): number {
    const angle: number = (this.baseAngle + this.ringAngle) * Math.PI / 180;
    return this.galaxySize / 2 + this.radius * Math.cos(angle) - PLANET_BOX_WIDTH / 2;
  }

  private top(): number {
    const angle: number = (this.baseAngle + this.ringAngle) * Math.PI / 180;
    return this.galaxySize / 2 + this.radius * Math.sin(angle) - PLANET_ICON_HIT_SIZE / 2;
  }

  private focusTranslateX(): number {
    if (!this.isCentered()) {
      return 0;
    }
    return this.galaxySize / 2 - (this.left() + PLANET_BOX_WIDTH / 2);
  }

  private focusTranslateY(): number {
    if (!this.isCentered()) {
      return 0;
    }
    return this.galaxySize / 2 - (this.top() + PLANET_ICON_HIT_SIZE / 2);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.isCentered()) {
          Circle()
            .width(RIPPLE_SECOND_SIZE)
            .height(RIPPLE_SECOND_SIZE)
            .fill(Color.Transparent)
            .stroke(ColorTokens.brand)
            .strokeWidth(1)
            .opacity(this.secondRippleOpacity)
            .scale({ x: this.secondRippleScale, y: this.secondRippleScale })
            .hitTestBehavior(HitTestMode.None)
          Circle()
            .width(RIPPLE_FIRST_SIZE)
            .height(RIPPLE_FIRST_SIZE)
            .fill(Color.Transparent)
            .stroke(ColorTokens.brand)
            .strokeWidth(1.5)
            .opacity(this.firstRippleOpacity)
            .scale({ x: this.firstRippleScale, y: this.firstRippleScale })
            .hitTestBehavior(HitTestMode.None)
        }
        if (this.isSelected()) {
          TagIcon({ name: this.name, iconSize: Math.min(34, this.planetSize * 0.46 + 6), tint: ColorTokens.brand })
        }
        TagIcon({ name: this.name, iconSize: Math.min(28, this.planetSize * 0.46), tint: ColorTokens.brand })
      }
      .width(PLANET_ICON_HIT_SIZE)
      .height(PLANET_ICON_HIT_SIZE)
      .position({ x: (PLANET_BOX_WIDTH - PLANET_ICON_HIT_SIZE) / 2, y: 0 })
      .scale({ x: this.isSelected() ? 1.12 : 1, y: this.isSelected() ? 1.12 : 1 })
      .animation({ duration: this.reduceMotion ? MotionTokens.instant : MotionTokens.base, curve: MotionCurves.standard })
      .translate({ x: this.focusTranslateX(), y: this.focusTranslateY() })
      .animation({ duration: this.reduceMotion ? MotionTokens.instant : MotionTokens.emphasis, curve: MotionCurves.springSoft })
      .onClick((): void => { this.onPlanet(this.name); })
      Column({ space: SpaceTokens.inlineTight }) {
        Text(this.name)
          .width(PLANET_BOX_WIDTH)
          .fontSize(9).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.overline.lineHeight)
          .fontColor(this.isSelected() ? ColorTokens.brand : ColorTokens.primary)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(String(this.followCount) + ' 人加入')
          .width(PLANET_BOX_WIDTH)
          .fontSize(9).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.overline.weight)
          .lineHeight(TypeTokens.overline.lineHeight)
          .fontFeature(TypeTokens.tabularFeature)
          .fontColor(ColorTokens.tertiary)
          .textAlign(TextAlign.Center)
      }
      .width(PLANET_BOX_WIDTH)
      .position({ x: 0, y: PLANET_ICON_HIT_SIZE + SpaceTokens.xs })
      .hitTestBehavior(HitTestMode.None)
    }
    .width(PLANET_BOX_WIDTH)
    .height(PLANET_BOX_HEIGHT)
    .hitTestBehavior(HitTestMode.Transparent)
    .opacity(this.isSelected() ? 1 : 0.76)
    .animation({ duration: this.reduceMotion ? MotionTokens.instant : MotionTokens.base, curve: MotionCurves.standard })
    .position({ x: 0, y: 0 })
    .translate({ x: this.left(), y: this.top() })
  }
}
