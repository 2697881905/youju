# DESIGN.md — HyperFrames 能力演示

## Style Prompt
基于 Swiss Pulse（瑞士国际主义）的"临床、精确、科技"气质。演示内容为 HyperFrames 工具本身的能力：HTML 即视频、GSAP 动效编排、场景转场、数据可视化。网格锁定布局，数字/大标题主导画面，无装饰性浮动。

## Colors
- `--bg: #111114` — 近黑偏冷背景
- `--panel: #1a1a20` — 卡片面板
- `--fg: #f2f2f0` — 主前景（暖白）
- `--muted: #9a9aa4` — 次级文本
- `--accent: #0066FF` — 电源蓝（唯一主强调）
- `--accent2: #FFB300` — 琥珀（次级点缀）

## Typography
- Headlines: Inter · w800 · 60–110px（大标题）
- Body/Labels: Inter · w400-600 · 20-28px
- Data/code: JetBrains Mono · 16-20px

## Motion Rules
- 入场：`expo.out` / `power4.out`，快速利落、归位
- 数字跑数：count-up，tabular-nums
- 转场：Crossfade（0.5s，power2.inOut），中档能量
- 环境配饰：径向辉光呼吸 + 幽灵文字漂移，恒慢速

## What NOT to Do
- 禁止渐变文字（background-clip:text）
- 禁止纯 #000 / #fff，向强调色微调
- 禁止等尺寸重复卡片网格
- 禁止青紫霓虹渐变