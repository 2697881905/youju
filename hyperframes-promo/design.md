# DESIGN.md — 有据上线预告宣传视频（逐组件动画版）

## Style Prompt
围绕「有据」理性内容社区的预告海报体系（P1–P4）制作竖版品牌宣传视频。视觉严格继承锁定的设计令牌：纸白底、宋体衬线大标、黑白灰主调、品牌蓝仅作点缀。海报以 **HTML 组件重建**（非 PNG 背景），每个组件（大标、信息流卡、五体裁卡、投票进度条、宣言行、权益清单、CTA 图标）以 **Apple 官网式丝滑 GSAP 动画**逐层揭示，转场采用「缩放交叉溶解」。排版克制、编辑感、高可读性，与既有海报像素级一致。

## Colors（来自 design/beta-posters 已锁定令牌）
- `--paper: #FAFAFA` — 纸白底
- `--surface: #FFFFFF` — 卡片白
- `--surface-2: #F2F2F5` — 浅灰块
- `--ink: #0D0F12` — 墨黑 主文字
- `--gray: #6E6E73` — 次级文字
- `--gray-2: #AEAEB2` — 三级文字
- `--line: #E5E5EA` — 分隔线
- `--blue: #1677FF` — 品牌蓝，仅点缀（CTA 图标 / 关键数字 / 锚点 / 方案B 进度条 / 结尾大标点缀）

## Typography
- 中文大标: Noto Serif SC（对应 Songti SC）/ serif · 900
- 中文正文/小标: Noto Sans SC（对应 PingFang SC）/ sans-serif · 300/400/600
- 英文/数字: Outfit / Helvetica Neue / Arial · 600/800
- 说明：Songti SC / PingFang SC 为 macOS 系统字体不可嵌入，重建文字一律用 Google Fonts 托管的 Noto 系列以保证字形相近且可渲染。

## Motion Rules（组件级 Apple 式动画）
- **标题揭示**：大标/标语每行包 `.line-mask`（overflow:hidden），内层 `.line-inner` 从 `yPercent:110` 上滑揭示，`power4.out`，行间 stagger 0.17s —— Apple 签名手感
- **卡片/清单**：信息流卡、体裁卡、权益行错峰滑入（y + scale + opacity），`power3.out`，stagger 0.09–0.18s
- **弹跳元素**：头像圆点、chip、对勾、社交图标用 `back.out(1.6–2)` 弹性弹出
- **进度条**：投票条用 `scaleX 0→1`（transform-origin:left，不用 width），`power4.out`，stagger 0.15s
- **转场**：统一「缩放交叉溶解」0.6s，`power2.inOut`：出场景 `scale 1.0→1.06 + opacity→0`，入场景 `scale 0.96→1.0 + opacity→1`
- 同场景至少 3 种缓动，避免重复入场模式；转场前不做离场动画，仅结尾场景允许淡出收尾

## What NOT to Do
- 禁止渐变文字（background-clip:text）
- 禁止偏离令牌异地配色；品牌蓝 `#1677FF` 仅用于 CTA / 关键数字 / 锚点 / 方案B 进度条 / 结尾点缀，不得大面积使用
- 禁止使用 macOS 系统字体（Songti SC / PingFang SC）作为重建文字（无法嵌入渲染），一律用 Noto 系列
- 禁止用 `width` 动画进度条（改用 `scaleX`）；禁止 `repeat:-1`；禁止异步建线；禁止 `Math.random`
