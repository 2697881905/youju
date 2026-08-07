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
  selected: boolean;
  ring: number;
  x: number;
  y: number;
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

// 纯视图星环：父页面负责角度、惯性和暂停规则，本组件只消费计算后的轨道与行星坐标。
@Component
export struct CircleOrbitCanvas {
  @Prop galaxySize: number = 343;
  @Prop ringAngles: number[] = [0, 0, 0];
  @Prop radii: number[] = [0, 0, 0];
  @Prop circles: OrbitCircleItem[] = [];
  @Prop ringDragging: boolean = false;
  @Prop reduceMotion: boolean = false;
  @Prop avatar: string = '';
  @Prop nickname: string = '';
  onPlanet: (name: string) => void = (_name: string): void => {};
  onBlank: () => void = (): void => {};
  onPanStart: () => void = (): void => {};
  onPanUpdate: (event: GestureEvent) => void = (_event: GestureEvent): void => {};
  onPanEnd: () => void = (): void => {};

  private angleFor(ring: number): number {
    return this.ringAngles[ring] ?? 0;
  }

  private radiusFor(ring: number): number {
    return this.radii[ring] ?? 0;
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
  private orbit(radius: number): void {
    Circle()
      .width(radius * 2)
      .height(radius * 2)
      .fill(Color.Transparent)
      .stroke(ColorTokens.secondary)
      .strokeWidth(1.5)
      .strokeDashArray([4, 6])
      .opacity(0.82)
      .position({ x: this.galaxySize / 2 - radius, y: this.galaxySize / 2 - radius })
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private ringLayer(ring: number): void {
    Stack() {
      this.orbit(this.radiusFor(ring))
    }
    .width('100%')
    .height('100%')
    .rotate({ angle: this.angleFor(ring) })
    .animation({ duration: this.reduceMotion || this.ringDragging ? MotionTokens.instant : MotionTokens.fast, curve: MotionCurves.standard })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  // 行星层与轨道层同角度 rotate，保证 Logo 跟随圆环公转。
  // 行星坐标只按静态 baseAngle 计算（不随角度逐帧刷新 position，
  // 规避 ForEach key 复用导致子项 position 不更新的问题）；公转由整层 rotate 驱动。
  // 各行星通过 counterAngle 抵消层旋转，图标与文字始终正立。
  @Builder
  private planetRingLayer(ring: number): void {
    Stack() {
      ForEach(this.circles.filter((circle: OrbitCircleItem): boolean => circle.ring === ring),
        (circle: OrbitCircleItem) => {
          OrbitPlanet({
            name: circle.name,
            followCount: circle.followCount,
            size: circle.size,
            selected: circle.selected,
            x: circle.x,
            y: circle.y,
            counterAngle: -this.angleFor(ring),
            reduceMotion: this.reduceMotion,
            onPlanet: (name: string): void => { this.onPlanet(name); },
          })
        },
        (circle: OrbitCircleItem) => circle.name)
    }
    .width('100%')
    .height('100%')
    .rotate({ angle: this.angleFor(ring) })
    .animation({ duration: this.reduceMotion || this.ringDragging ? MotionTokens.instant : MotionTokens.fast, curve: MotionCurves.standard })
    .hitTestBehavior(HitTestMode.Transparent)
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
        .onClick((): void => { this.onBlank(); })
      this.starDots()
      this.ringLayer(0)
      this.ringLayer(1)
      this.ringLayer(2)
      this.planetRingLayer(0)
      this.planetRingLayer(1)
      this.planetRingLayer(2)
      this.coreStar()
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

// 独立行星组件：位置由静态 baseAngle 坐标给定，公转由行星层 rotate 驱动；
// counterAngle 抵消层旋转保证图标与文字始终正立。
// 抽成独立 @Component + 标量 @Prop，规避 ForEach key 复用不刷新（含选中态高亮）。
@Component
struct OrbitPlanet {
  @Prop name: string = '';
  @Prop followCount: number = 0;
  @Prop size: number = 46;
  @Prop selected: boolean = false;
  @Prop x: number = 0;
  @Prop y: number = 0;
  @Prop counterAngle: number = 0;
  @Prop reduceMotion: boolean = false;
  onPlanet: (name: string) => void = (_name: string): void => {};

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.selected) {
          TagIcon({ name: this.name, iconSize: Math.min(34, this.size * 0.46 + 6), tint: ColorTokens.brand })
        }
        TagIcon({ name: this.name, iconSize: Math.min(28, this.size * 0.46), tint: ColorTokens.brand })
      }
      .width(PLANET_ICON_HIT_SIZE)
      .height(PLANET_ICON_HIT_SIZE)
      .position({ x: (PLANET_BOX_WIDTH - PLANET_ICON_HIT_SIZE) / 2, y: 0 })
      .scale({ x: this.selected ? 1.12 : 1, y: this.selected ? 1.12 : 1 })
      .animation({ duration: this.reduceMotion ? MotionTokens.instant : MotionTokens.base, curve: MotionCurves.standard })
      .onClick((): void => { this.onPlanet(this.name); })
      Column({ space: SpaceTokens.inlineTight }) {
        Text(this.name)
          .width(PLANET_BOX_WIDTH)
          .fontSize(9).fontFamily(TypeTokens.fontFamily)
          .fontWeight(TypeTokens.headline.weight)
          .lineHeight(TypeTokens.overline.lineHeight)
          .fontColor(this.selected ? ColorTokens.brand : ColorTokens.primary)
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
    // 抵消整层公转角度（与轨道层同 duration，避免相位滞后造成倾斜抖动）。
    .rotate({ angle: this.counterAngle })
    .animation({ duration: this.reduceMotion ? MotionTokens.instant : MotionTokens.fast, curve: MotionCurves.standard })
    .hitTestBehavior(HitTestMode.Transparent)
    .opacity(this.selected ? 1 : 0.76)
    .animation({ duration: this.reduceMotion ? MotionTokens.instant : MotionTokens.base, curve: MotionCurves.standard })
    .position({ x: this.x, y: this.y })
  }
}
