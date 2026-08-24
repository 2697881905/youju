# 有据品牌宣传视频 · 最终成片方案（HyperFrames 逐组件动画版）

## Summary

基于「有据」上线预告海报系列 P1–P4（1080×1920 竖版）与已锁定的品牌设计令牌，用 **HyperFrames（HTML + GSAP）** 制作一支 **约 24 秒、竖版 1080×1920（9:16）** 的品牌宣传视频。与既有 17s「PNG 背景 + Ken Burns」旧版不同，本方案**用 HTML 重建海报的每一个组件**（大标、信息流卡片、五体裁卡、投票进度条、宣言行、权益清单、CTA 图标），并以 **Apple 官网式丝滑动画**逐组件驱动叙事：标题遮罩逐行揭示、卡片错峰滑入、进度条 scaleX 生长、图标弹性弹出。转场采用 Apple 式「缩放交叉溶解」（scale + crossfade）。结尾以品牌 Logo + 大标 + 行动号召（点赞 / 收藏 / 转发）收尾。全程色调、字体、Logo 严格锁定海报令牌。

## Current State Analysis

### 已有素材（充足，可直接复用）
- **海报源 HTML**：`design/beta-posters/index.html` —— 4 张海报的全部组件结构（`.p-head` 品牌区、`.headline` 大标、`.sub` 副文案、`.feed/.fcard` 信息流卡、`.genres/.gcard` 五体裁卡、`.vote/.vfill` 投票进度条、`.manifesto/.mrow` 宣言行、`.perks/.perk` 权益清单、`.p-cta` 传播区）与完整 CSS 设计令牌。**这是逐组件动画的直接素材源**。
- **海报 PNG**：`design/beta-posters/export/P1-4.png`（1080×1920）。
- **品牌 Logo**：`design/beta-posters/有据logo.png`（272KB，海报实际使用）。
- **既有工程**：`hyperframes-promo/` 已初始化（hyperframes@0.8.10，`assets/` 已含 P1-4.png 与 logo.png），但当前 `index.html` 是「PNG 全出血背景 + Ken Burns + 底部纸白面板」的 17s 旧版，**未渲染出片**（`renders/` 为空）。
- **环境**：Node v23、Chrome、FFmpeg 9.0.1 就绪；`hyperframes-demo/` 已验证「HTML→check→render MP4」全流程。

### 品牌设计令牌（已锁定，全片必须遵守）
| 角色 | 值 |
|---|---|
| 纸白底 / 卡片白 / 浅灰块 | `#FAFAFA` / `#FFFFFF` / `#F2F2F5` |
| 主文字 / 次级 / 三级 / 分隔线 | `#0D0F12` / `#6E6E73` / `#AEAEB2` / `#E5E5EA` |
| 品牌蓝（仅点缀） | `#1677FF`（仅 CTA 图标、关键数字、锚点、方案B 进度条） |
| 中文大标 | Noto Serif SC（对应 Songti SC）· 900 |
| 中文正文 | Noto Sans SC（对应 PingFang SC）· 300/400/600 |
| 英文/数字 | Outfit / Helvetica Neue / Arial · 600/800 |

> 字体说明：Songti SC / PingFang SC 为 macOS 系统字体不可嵌入，叠加/重建文字一律用 Google Fonts 托管的 **Noto Serif SC / Noto Sans SC / Outfit**（编译器自动内嵌），字形与海报一致。

### 素材现状与补充建议（按需求明确指出）
- **现状**：4 张海报覆盖「品牌预告（P1）+ 三大价值观（理性 P2 / 友善 P3 / 共创 P4）」，对一支「价值观驱动、即将上线」的预告片已足够；无产品界面、无下载入口，符合「纯宣传不引流」定位。
- **建议补充（可选，非阻塞）**：
  1. **产品界面截图 2–3 张**（信息流 / 测评详情页 / 辩论投票页）：海报纯排版无产品画面，若想强化「产品感」可在 S1 或结尾前插入 0.5–1s 的 App 界面快闪。当前方案不依赖，可后续叠加。
  2. **BGM / 轻音效**：当前静音版；Apple 式丝滑动画配轻量 BGM 效果最佳。可用 hyperframes 的 media/tts 能力或提供音乐文件后叠加（本方案先出静音版，音轨可后补）。
  3. **高清 Logo 矢量源（SVG）**：现有 PNG 足够常规尺寸；如需结尾 Logo 大特写缩放可提供矢量源。
  4. **二维码 / 下载入口**：如需引流可在结尾 CTA 后补二维码画面（当前定位不引流，故不加入）。

## 成片方案（分镜脚本 / 动画节奏 / 时间分配 / 转场 / 结尾 CTA）

- **画幅**：1080×1920 竖版（9:16），30fps，**总时长 24.0s**（满足 15–30s）。
- **叙事弧线**：S1 品牌钩子（真实经验，有据可循）→ S2 理性 → S3 友善 → S4 共创 → S5 结尾 CTA。每张海报的组件按「大标 → 副文案 → 视觉主体 → 标签/清单 → 底部传播标语」的层级依次入场，形成 Apple 式「逐层揭示」节奏。
- **动画节奏原则**：入场动画 0.4–0.8s、错峰 stagger 0.06–0.18s；标题用 **power4.out / expo.out**（快起慢落，Apple 签名手感），卡片用 power3.out，弹跳元素（圆点/对勾/图标）用 **back.out(1.6–2)**，进度条用 power4.out；同场景至少 3 种缓动，避免重复入场模式。

### 分镜表（组件级动画序列）

| 镜号 | 时间 | 画面（组件动画序列） | 转场 |
|---|---|---|---|
| **S1 开场 P1** | 0.0–4.0s | 纸白底淡入 → 品牌区（Logo+「有据」）滑入 + eyebrow「即将上线 · HARMONYOS NEXT」逐字遮罩 → 大标「真实经验，有据可循。」**双行遮罩逐行揭示**（每行 y:100%→0）→ 副文案淡入 → 2 张信息流卡**错峰滑入**（y+scale，卡内头像圆点弹入、标题上移、♥/💬 数字淡入）→ 5 枚标签 chip 弹性弹出 → 底部标语「把真话，讲给懂的人听」遮罩揭示 + 点赞/收藏/转发图标弹出 | 开场淡入 0.5s |
| **S2 理性 P2** | 4.0–8.5s | 大标「拒绝标题党，把经验讲清楚。」遮罩揭示 → 副文案「有结构的内容，才配叫「有据」。」→ **5 张体裁卡**（测评/避坑/教程/辩论/分享）错峰滑入（scale 0.92→1）→ 投票卡滑入，**两条进度条 scaleX 0→62% / 0→38%**（方案B 蓝色）→ 3 枚标签弹出 → 底部标语「少一点标题党，多一点真话」+ 图标 | 缩放交叉溶解 0.6s |
| **S3 友善 P3** | 8.5–13.0s | 大标「不喜欢就少推点，拉黑就别再见。」遮罩揭示 → 副文案 → **巨型「」引号**（300px 装饰字）放大淡入 + 蓝色锚点弹入 → **3 行宣言**错峰滑入（x 位移 + 圆点 back.out 弹出，高亮行「三道内容安全防线」蓝点）→ 脚注「两档社交距离 · 7 类举报理由…」淡入 → 底部标语「不喜欢就少推点，别吵架」+ 图标 | 缩放交叉溶解 0.6s |
| **S4 共创 P4** | 13.0–17.5s | 大标「把经验，装进口袋。」遮罩揭示 → 副文案「上线在即，先占一个位置。」→ **5 条权益清单**错峰滑入（y+scale，每行 ✓ 对勾 back.out 弹出）→ 底部标语「好经验，值得被更多人看见」+ 图标 | 缩放交叉溶解 0.6s |
| **S5 结尾 CTA** | 17.5–24.0s | 纸白底 → **品牌 Logo +「有据」** back.out 弹入 → 大标「真实经验，有据可循。」遮罩揭示（「有据可循」品牌蓝点缀）→ 副文案「一个鸿蒙原生的理性内容社区 · 上架在即」→ **3 个行动号召**（点赞 / 收藏 / 转发，feather 线性图标）错峰弹出 → CTA 文案「觉得有用，欢迎点赞 · 收藏 · 转发」→ 保持可读 2s → 结尾整体淡出收尾 | 缩放交叉溶解入 + 结尾淡出（final scene 允许） |

> 每场景底部传播标语（slogan）与海报自身文案一致，作为「价值观记忆点」重复强化；S1 与 S5 不叠加底部面板，保留大标冲击力与 CTA 干净收尾。

### 转场设计（Apple 式「缩放交叉溶解」）
- 统一转场时长 **0.6s**，缓动 `power2.inOut`：出场景 `scale 1.0→1.06 + opacity→0`，入场景 `scale 0.96→1.0 + opacity→1`，产生「轻微推近穿越」的丝滑过渡。
- 转场前**不做**任何离场动画（出场景内容在转场瞬间必须完整可见），转场即离场；仅 S5 结尾允许淡出收尾。
- 组件级「擦除/遮罩」效果用于**标题逐行揭示**（clip-path 或 overflow 遮罩 + y 位移），不做整场景擦除，避免与转场冲突。

## Proposed Changes（实施步骤）

### 1. 重写 `hyperframes-promo/index.html`（核心交付）
- 将 4 张海报**从 PNG 背景改为 HTML 组件重建**（复用 `design/beta-posters/index.html` 的 CSS 令牌与结构，去掉画廊/导出脚本，按 1080×1920 场景适配）。
- 结构：`#root[data-composition-id=main][data-width=1080][data-height=1920][data-duration=24.0]`，内含 5 个 `.clip.scene`（S1–S5），各自 `data-start` / `data-duration` / `data-track-index` 递增、后续场景初始 `opacity:0` + 递增 z-index 以支持交叉溶解。
- 每个场景内组件按分镜表组织（`.p-head` / `.headline` / `.sub` / `.feed` / `.genres` / `.vote` / `.manifesto` / `.perks` / `.p-cta`），大标每行包一层 `.line-mask`（overflow:hidden）供遮罩揭示。
- 单一 GSAP 时间线 `window.__timelines["main"]`（`{paused:true}`），全部入场用 `gsap.from`，转场用 `tl.to(出,{opacity:0,scale:1.06})` + `tl.fromTo(入,{opacity:0,scale:0.96},{opacity:1,scale:1})`；进度条用 `scaleX`（transform-origin:left，**不用 width**）；无 `repeat:-1`、无异步建线、无 `Math.random`。
- 字体：Google Fonts 引入 Noto Serif SC / Noto Sans SC / Outfit（编译器内嵌）；Logo 用 `assets/logo.png`（`crossorigin="anonymous"`）。
- 品牌蓝 `#1677FF` 仅用于：CTA 图标 hover/锚点、方案B 进度条、结尾大标「有据可循」点缀、宣言高亮行蓝点。

### 2. 更新 `hyperframes-promo/design.md`
- 保留色板/字体/禁止项；将 Motion Rules 更新为「组件级 Apple 式动画」：标题遮罩逐行揭示（power4.out）、卡片错峰滑入（power3.out）、弹跳元素 back.out、进度条 scaleX、转场缩放交叉溶解 0.6s。

### 3. 重写 `hyperframes-promo/字幕文案-分镜.md`（交付物）
- 更新为 24s 分镜表（画面 / 时间 / 组件动画 / 转场）+ 逐条字幕文案 + 素材清单 + 补充素材建议。

### 4. 校验与渲染
- `cd hyperframes-promo && npm run check` → 修至 **0 error**（lint / validate / inspect 布局 / 对比度 WCAG AA）。
- `npm run render -- --output youju-promo-animated.mp4 --quality high` → 产出 1080×1920、24s、30fps MP4。
- 必要时 `npx hyperframes preview --background` 供交互预览。

## Assumptions & Decisions

- **竖版 9:16（1080×1920）**：海报面向抖音/朋友圈竖屏，全片随海报竖版。
- **HTML 重建海报组件而非用 PNG 背景**：这是本次「逐组件动画」需求的前提；组件结构与 CSS 直接复用海报源 HTML，保证与设计稿像素级一致。
- **总时长 24s**：落在 15–30s 区间，每张海报约 4.5s 足够承载 6–8 个组件动画 + 结尾 CTA 保持可读 2s。
- **静音版**：默认无音轨；BGM/旁白可后续用 hyperframes media/tts 叠加（已在补充建议中说明）。
- **Seedance（AI 视频生成）不作为主线**：AI 生成无法像素级复刻海报文字/Logo/色板，故核心成片走 HyperFrames 逐组件动画；Seedance 仅作为可选补充素材手段（如抽象背景/粒子），不在本方案主线内。
- **复用既有 `hyperframes-promo` 工程**：不新建工程，直接重写其 `index.html` / `design.md` / `字幕文案-分镜.md`，`assets/logo.png` 继续使用；P1-4.png 背景不再使用（保留文件不删除，避免破坏既有工作）。

## Verification

1. `cd hyperframes-promo && npm run check` 全部通过（尤其字幕/文字对比度 WCAG AA、布局无溢出）。
2. 渲染 `youju-promo-animated.mp4`：竖版 1080×1920、约 24s、30fps、转场均 0.6s、4 张海报组件全部出镜并逐层动画、结尾含 Logo + CTA。
3. 人工过片核对：S1→S2→S3→S4→S5 顺序正确、组件入场与字幕同步、品牌色未漂移、动画丝滑无跳变。
4. 交付：成片 MP4 + `字幕文案-分镜.md`（分镜 + 字幕文案 + 素材建议）+ 预览地址。
