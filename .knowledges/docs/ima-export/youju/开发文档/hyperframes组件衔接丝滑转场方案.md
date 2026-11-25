---
title: "hyperframes组件衔接丝滑转场方案.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_0ba25f96c02cf0a8c26779a11711ea2c7505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# HyperFrames 抖音宣发片 · 组件衔接丝滑转场方案

## Summary

把当前 6 处统一的「缩放交叉溶解」转场，改为**共享元素（组件）接力式转场**：在每两个分镜切换的瞬间，取前一分镜的标志性组件，通过一个全屏 `bridge` 覆盖层（z-index 最高）从旧位置飞到新场景的对应位置，新旧场景在 bridge 运行期间错峰淡入淡出，实现「一个组件从一个场景"长"进下一个场景」的丝滑衔接。所有转场保持确定性、符合 HyperFrames 规则（不使用场景 exit 动画，转场本身即退场）。

目标文件：`/Users/itxiaobai/HarmonyProject1/hyperframes-tiktok/index.html`（单文件主合成，24.0s→保持 28.2s 总时长不变，仅替换转场段）。

## 现状分析

- 全部 6 个转场（S0→S1@2.6、S1→S2@8.0、S2→S3@12.0、S3→S4@16.2、S4→S5@20.0、S5→S6@23.6）都是同一写法：
  ```js
  tl.to("#sceneX", { opacity: 0, scale: 1.06, duration: 0.6, ease: "power2.inOut" }, T);
  tl.fromTo("#sceneY", { opacity: 0, scale: 0.96 }, { opacity: 1, scale: 1, duration: 0.6, ease: "power2.inOut" }, T);
  ```
- 问题：纯透明度+缩放溶解，缺少「上一场景的东西延续到下一场景」的叙事感，用户观感偏"套模板"。
- HyperFrames 约束（须遵守）：禁止在转场前对场景内容做 exit 动画（转场即退场）；转场必须要有；入场动画每个场景都要有（现有保留）；确定性（无 random）；`clip` class + `data-start/duration/track-index` 必填。

## 方案设计：共享元素 Bridge 转场

### 通用架构

1. 在 `#root` 内最底部（grain 之上、所有 scene 之后）新增 6 个 bridge 覆盖层，每个只在其转场窗口可见：
   ```html
   <div id="bridge01" class="clip bridge" data-start="2.55" data-duration="0.85" data-track-index="0">…共享元素副本…</div>
   ```
   CSS：`.bridge { position:absolute; inset:0; z-index:70; pointer-events:none; }`（高过全部 scene），共享元素用绝对定位放置在**起点坐标**。
2. 通用编排（T=转场启动时刻，`B` 为对应 bridge）：
   - `T`：旧场景 `opacity→0, 0.45s, power2.inOut`（去掉 scale）
   - `T+0.12`：新场景 `opacity 0→1, 0.45s, power2.inOut`（去掉 scale）
   - `T+0.05`：bridge 内共享元素 `x/y/scale/rotation` 从起点飞到终点，`0.65s, power2.inOut`（带轻微 overshoot 用 `back.out(1.1)` 亦可），终点精确落位在新场景对应组件中心
   - `T+0.6`：bridge 整体 `opacity→0, 0.22s, power2.in`（完成交接后隐藏）
3. 各场景自身的入场动画（headline 遮罩、卡 stagger 等）**全部保留不动**；只是把原「缩放交叉溶解」两行替换成上面的编排段。
4. 坐标为硬编码绝对值（1080×1920 画布），执行时以 Studio 实际布局微调，保证 bridge 终点与新组件中心对齐。

### 6 段共享元素与轨迹

| 转场 | T | Bridge 共享元素（副本） | 起点（旧场景） | 终点（新场景） |
|---|---|---|---|---|
| S0→S1 | 2.6 | 金环 + Logo（176px，`logo-intro.png`） | 画面中心 (540, 700) | 缩小到 88px 落进真机屏幕顶部中心 (540, 560) |
| S1→S2 | 8.0 | 卡堆顶卡副本（白卡+封面+mata 结构，640 宽） | 卡堆中心 (540, 700) | 缩到 430 宽对齐 S2 第 1 张体裁卡中心 (540, 782) |
| S2→S3 | 12.0 | 金色圆斑（模拟投票进度条色块） | 投票卡中心 (540, 1180) | 放大成星环核心光晕 obCore (540, 1240) |
| S3→S4 | 16.2 | 选圈卡片副本（obCard：标题「旅游出行」+ 进圈按钮） | 底部选圈卡 (540, 1560) | 缩成 S4 中间「圈子」feat 卡 (540, 1350) |
| S4→S5 | 20.0 | 宋体大字块「留下来。」（line-inner 副本） | S4 大标第二行 (540, 760) | S5 大标位 (540, 800) 缩小后淡出，S5「有据可循」遮罩揭示承接 |
| S5→S6 | 23.6 | HarmonyOS 胶囊 chip 副本 | S5 chips 行 (540, 1150) | 放大成 S6 金环+Logo 定版 (540, 860) |

> 每段 bridge 元素在起点的初始态与旧场景对应组件视觉一致；运行期只动 transform/opacity，不碰布局属性。bridge 终点附近的新组件入场动画时间要与 bridge 落位时间对齐（如 S1 真机在 2.85s 已入场、S2 genre1 在 9.05s 入场——若 bridge 落位早于新组件入场，新组件会用自身入场动画"接住"bridge，视觉自然；执行时微调新组件入场时间或 bridge 终点时刻）。

## 修改内容（index.html）

1. **CSS 新增**（`<style>` 内）：
   - `.bridge` 定位/z-index；按需 `.bridge .b-*` 元素样式（金环、卡片、胶囊、大字复用现有 token 变量）。
2. **DOM 新增**（`#root` 内、所有 scene 之后）：6 个 `bridge01..bridge06` 覆盖层，各自含共享元素副本与 `data-layout-allow-overlap/occlusion/overflow` 标注（避免 Layout 检查误报）。
3. **GSAP 替换**：把 6 段「缩放交叉溶解」替换为上述通用编排（旧淡出、新淡入、bridge 飞行、bridge 淡出）；bridge 的初始隐藏态用 `gsap.set` 在 timeline 外立即设置；末尾保留 S6 淡出收尾。
4. **时间轴不变**：各场景 `data-start/data-duration`、场景内入场动画全部保持；总时长 28.2s。

## 假设与决策

- 采用「共享元素 Overlay」而非「旧组件直接飞出」——后者违反 HyperFrames 禁 exit 规则，前者合规且是标准"连接型转场"。
- 6 段全部组件化，不做部分保留溶解。
- 转场时长从 0.6s 微升至 0.75~0.85s（bridge 飞行需要），仍属「Medium/丝滑」区间；不引入 shader（CSS 足够，避免 html2canvas 兼容负担）。
- 用户所选 frontend-design / web-app-development 插件本任务不直接调用；动效遵循已加载的 hyperframes + gsap 技能规范。
- 所有坐标先按当前布局估算，执行后以 `npm run check` + Studio 预览逐段校正。

## 验证

1. `cd /Users/itxiaobai/HarmonyProject1/hyperframes-tiktok && npm run check` → Lint / Runtime / Layout / Motion / Contrast 全 0 错误。
2. `npx hyperframes preview --background` + Studio 逐段检查 6 个转场：bridge 起点与旧组件对齐、终点与新组件对齐、无闪跳、无重叠文字误报（必要时补 `data-layout-allow-overlap`）。
3. 逐段用 `npx hyperframes inspect --at <T>` 抽查转场帧。
4. 用户确认后 `npm run render` 出 MP4，出 3×3 contact-sheet 审片。
