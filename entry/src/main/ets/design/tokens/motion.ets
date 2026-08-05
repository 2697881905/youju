import { curves } from '@kit.ArkUI';

// design token: motion. 仅 transform/opacity 消费这些参数。
export class MotionTokens {
  static readonly instant: number = 100;
  static readonly fast: number = 140;
  static readonly base: number = 220;
  static readonly slow: number = 320;
  static readonly enter: number = 360;
  // 交互节奏：按压 < 控件切换 < 容器展开 < 页面进入。
  // 页面只消费这些语义 token，避免各处写出不同的“手感”。
  static readonly interaction: number = MotionTokens.fast;
  static readonly control: number = MotionTokens.base;
  static readonly container: number = MotionTokens.slow;
  static readonly page: number = 420;
  static readonly emphasis: number = 460;
  static readonly stagger: number = 40;
  static readonly staggerEmphasis: number = 56;
  static readonly shimmer: number = 1200;

  static readonly pressScale: number = 0.97;
  static readonly pressOpacity: number = 0.92;
  static readonly successScale: number = 1.045;
  static readonly enterScale: number = 0.975;
}

export class MotionCurves {
  static readonly standard: ICurve = curves.cubicBezierCurve(0.2, 0.8, 0.2, 1);
  static readonly decelerate: ICurve = curves.cubicBezierCurve(0, 0, 0.2, 1);
  static readonly accelerate: ICurve = curves.cubicBezierCurve(0.4, 0, 1, 1);
  static readonly spring: ICurve = curves.cubicBezierCurve(0.34, 1.56, 0.64, 1);
  static readonly springSoft: ICurve = curves.cubicBezierCurve(0.22, 1.22, 0.36, 1);
  static readonly emphasized: ICurve = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
  static readonly linear: ICurve = curves.cubicBezierCurve(0, 0, 1, 1);
}
