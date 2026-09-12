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
  // GSAP 级弹性预设（springMotion 系列）：duration 由曲线自算，response 越大越迟、dampingFraction 越大越不弹。
  static readonly springInteract: ICurve = curves.springMotion(0.6, 0.85); // 柔和弹性（点赞按钮通用）
  static readonly springBounce: ICurve = curves.springMotion(0.4, 0.7);   // 明显回弹（成功脉冲）
  static readonly springRelease: ICurve = curves.springMotion(0.5, 0.75); // 离手回稳/飞出
  // 卡堆专用复位：更快 + 轻微回弹（对应网页 return 弹簧 K=210/C=13 的“油润”手感）
  static readonly springSettle: ICurve = curves.springMotion(0.3, 0.62);
  // 卡堆拖拽追踪：质量弹簧追随手指（对应网页 drag K=300/C=19），快甩带轻微弹性滞后与速度量
  static readonly springTrack: ICurve = curves.springMotion(0.25, 0.72);
}

// 60/120Hz 帧率适配：交给 animateTo / .animation 使用，避免高刷设备上动画时长不一致。
export class MotionFrameRates {
  static readonly default: ExpectedFrameRateRange = { min: 30, max: 120, expected: 60 };
}
