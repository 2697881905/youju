---
title: "2026-09-15-arkui-spring-motion-card-deck.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_da9c238a555a64c2ddd57277b575776b7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T15:08:22.227Z
---
---
id: 2026-09-15-arkui-spring-motion-card-deck
title: ArkUI 卡堆弹簧物理动画：springMotion 多层独立弹簧参数模式
category: coding-pattern
nature: technique
created_at: 2026-09-15T15:08:04
updated_at: 2026-09-26T15:34:47
tags: [ArkUI, springMotion, card-deck, physics-animation, drag]
keywords: [springMotion, curves.springMotion, response, dampingFraction, card deck, 卡堆, 弹簧动画, 跟手拖拽, 回弹, DailyPostDeck, DECK_SPRING, DECK_ROT_SPRING]
problem_patterns: [unnatural-card-swipe, uniform-spring-stiffness, no-parallax-depth]
source_sessions: [ses_f5c27a718ffeXtJJltNE8iMaPp]
project: HarmonyProject1
severity: medium
quality_score: 83
hit_count: 1
last_hit_at: 2026-09-15T23:09:06
low_quality_hit_count: 0
tier: A
related_experiences: [2026-09-15-arkui-motion-design-token-system, 2026-09-26-arkui-animateto-appstorage-layout-transition]
---

# ArkUI 卡堆弹簧物理动画：springMotion 多层独立弹簧参数模式

## Scenario

实现类似 Tinder/每日一帖的卡堆滑动交互时，需要满足以下体验要求：

1. **跟手拖拽**：顶卡随手指即时移动并微倾，不能有延迟感
2. **下层视差**：拖拽顶卡时下层卡跟随移动，但跟随系数逐层递减，形成深度感
3. **回弹摇晃**：松手后顶卡回弹归位，下层卡各自滞后归位，形成自然的"摇晃"相位差
4. **推进抛射**：滑出阈值后顶卡带速度飞出，下层卡依次顶上
5. **入场仪式**：首次进入时顶卡升起 + 整叠淡入

如果所有卡使用同一组弹簧参数，回弹时所有卡同时归位，缺乏层次感和自然感。

## Key Signals

- 卡堆回弹时所有卡同时归位，视觉上像"机械复位"而非"自然回弹"
- 下层卡与顶卡同步移动，没有视差深度感
- 拖拽顶卡时倾角与位移使用同一弹簧，回弹时旋转和位移同时归位，缺乏相位差
- 入场时所有卡同时出现，没有"升起"仪式感

## Essence

ArkUI 的 `curves.springMotion(response, dampingFraction)` 创建物理弹簧曲线：

- **response**：弹簧响应速度，越大越迟钝（回弹越慢）
- **dampingFraction**：阻尼比，越大越不弹（振荡越少）

核心模式：**为卡堆每张卡配置独立的弹簧参数——顶卡最弹（response 小、dampingFraction 小），越往后越稳（response 大、dampingFraction 大）**。这样回弹时各卡按各自频率振荡，产生自然的"摇晃"相位差。

进一步细化：**位移和旋转使用不同的弹簧参数**——旋转弹簧比位移弹簧更慢（response 更大），形成"位移先归位、旋转滞后归位"的相位差，模拟物理世界中卡片的"晃动"感。

关键约束：

- **跟手阶段不挂动画**：拖拽时位移/倾角直接绑定手指位置（每帧直绑），不经过 animateTo，确保零延迟跟手
- **回稳/推进才由 animateTo 驱动**：松手后才用弹簧曲线驱动回弹或飞出

## Approach

### 步骤 1：定义各槽位弹簧参数

```typescript
import { curves } from '@kit.ArkUI';

// 位移弹簧：顶卡最弹、越往后越稳
const DECK_SPRING: ICurve[] = [
  curves.springMotion(0.26, 0.56),  // 顶卡：快速回弹，明显振荡
  curves.springMotion(0.34, 0.64),  // 中卡：稍慢，振荡减弱
  curves.springMotion(0.40, 0.70),  // 底卡：更稳，轻微振荡
  curves.springMotion(0.46, 0.76),  // 预备卡：最稳，几乎不振荡
];

// 旋转弹簧：比位移更慢，形成"晃动"相位差
const DECK_ROT_SPRING: ICurve[] = [
  curves.springMotion(0.48, 0.45),  // 顶卡旋转：慢于位移，明显晃动
  curves.springMotion(0.58, 0.54),
  curves.springMotion(0.64, 0.62),
  curves.springMotion(0.70, 0.70),
];
```

### 步骤 2：跟手阶段——直绑不挂动画

```typescript
// 拖拽事件中直接更新状态变量（不经过 animateTo）
private onDragUpdate(x: number): void {
  this.dragX = x;
  this.dragRot = (x / this.deckWidth) * -5;  // 最大倾角 5°
  // 下层卡视差跟随（系数逐层递减）
  // DECK_PARAX = [0, 0.13, 0.06, 0] → 顶卡不跟随自己，中卡 13%，底卡 6%，预备卡不跟随
}
```

### 步骤 3：回稳/推进——animateTo 驱动弹簧

```typescript
// 松手回稳：animateTo + 弹簧曲线
this.getUIContext().animateTo({
  duration: MotionTokens.slow,
  curve: MotionCurves.springRelease,  // springMotion(0.5, 0.75)
}, () => {
  this.dragX = 0;
  this.dragRot = 0;
});

// 推进抛射：旧顶卡带速度飞出
this.getUIContext().animateTo({
  duration: MotionTokens.slow,
  curve: MotionCurves.springRelease,
}, () => {
  this.flyX = this.dragDir * (this.deckWidth * 1.6 + 200);  // 飞出屏外
  this.flyRot = this.dragDir * -9;  // 飞行倾角
});
```

### 步骤 4：每张卡的 .animation 绑定独立弹簧

```typescript
// 每张卡的位移层绑定 DECK_SPRING[depth]，旋转层绑定 DECK_ROT_SPRING[depth]
.animation({
  duration: MotionTokens.slow,
  curve: DECK_SPRING[Math.min(Math.max(this.curDepth(), 0), DECK_SPRING.length - 1)],
})
```

### 步骤 5：入场仪式——顶卡升起 + 整叠淡入

```typescript
private startRitual(): void {
  this.animRise = 0;
  this.getUIContext().animateTo({
    duration: MotionTokens.emphasis,  // 460ms
    curve: MotionCurves.springRelease,  // springMotion(0.5, 0.75)
  }, () => {
    this.animRise = 1;  // 顶卡从 0 升到 1（升起 26vp + 缩放 0.025）
  });
}
```

### 步骤 6：卡堆扇位参数

```typescript
const DECK_FAN_X: number = 30;          // 层间水平行程（抽出左上角）
const DECK_FAN_Y: number = 7;           // 层间纵向行程（右下角收拢）
const DECK_FAN_ANGLE: number = 4;       // 层间角差
const DECK_DRAG_TILT: number = 5;       // 顶卡拖拽最大倾角
const DECK_RISE: number = 26;           // 入场升起行程
const DECK_RISE_SCALE: number = 0.025;  // 入场缩放幅度
const DECK_VISIBLE: number = 4;         // 可见槽位数
const DECK_FAN_OP: number[] = [1, 0.86, 0.72, 0.45];  // 各槽位不透明度
const DECK_PARAX: number[] = [0, 0.13, 0.06, 0];      // 拖拽视差系数
const DECK_PAR_ROT: number[] = [0, 0.30, 0.18, 0.08]; // 拖拽视差倾角系数
```

## Faster Next Time

- **弹簧参数调优起点**：顶卡 `springMotion(0.26, 0.56)`、最底层 `springMotion(0.46, 0.76)`，中间层均匀递增；旋转弹簧 response 比位移大 0.2 左右
- **跟手阶段必须直绑**：拖拽时不要用 animateTo，直接更新状态变量，否则会有 1-2 帧延迟
- **视差系数设置**：顶卡 [0（不跟随自己）, 0.13, 0.06, 0]，预备卡不跟随——如果所有下层卡都跟随，深度感反而消失
- **入场仪式用 springRelease**：升起动画用 `springMotion(0.5, 0.75)` 而非贝塞尔曲线，物理弹性更自然
- **帧率适配**：所有 animateTo 调用传入 `expectedFrameRateRange`，确保 60/120Hz 设备上动画时长一致

## Applicability Boundaries

- **适用**：卡堆/Tinder 式滑动交互，需要物理弹性的跟手+回弹+推进
- **适用**：需要多层视差深度感的交互场景
- **不适用**：简单的单卡片滑动（不需要多层独立弹簧）
- **不适用**：非拖拽交互（如按钮点击的弹性反馈，用单条 springMotion 即可）
- **注意**：`springMotion` 的 duration 由曲线自身计算，传入的 duration 参数会被覆盖——不要试图通过 duration 控制弹簧动画时长，应通过 response/dampingFraction 调节
- **注意**：4 槽位（顶/中/底/预备）是经验值——更多槽位会增加渲染负担且底层卡几乎不可见

## Evidence or Examples

HarmonyProject1 项目中 `DailyPostDeck.ets` 的实际实现：

- 定义了 `DECK_SPRING[4]` 和 `DECK_ROT_SPRING[4]` 两组弹簧参数，位移和旋转独立
- 拖拽阶段通过 `onTouch` 事件直接更新 `dragX`/`dragRot` 状态变量，不经过 animateTo
- 回稳/推进通过 `animateTo({ curve: MotionCurves.springRelease })` 驱动
- 入场仪式 `startRitual()` 使用 `animateTo({ duration: MotionTokens.emphasis, curve: MotionCurves.springRelease })`
- 飞行卡抛射：`flyX = dragDir * (deckWidth * 1.6 + 200)`，确保飞出屏外
- 卡堆扇位参数（DECK_FAN_X/Y/ANGLE/DRAG_TILT/RISE/RISE_SCALE）全部以常量定义在文件顶部
- 完成态覆盖层使用 `TransitionEffect.OPACITY.animation({ duration: 550, curve: MotionCurves.decelerate })`
