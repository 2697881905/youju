# DESIGN.md — 有据 · 抖音宣发片（暖米棕体系）

## Style Prompt
暖纸感的编辑部头版气质：米白画布 + 深墨排版 + 焦糖棕点缀，像一份用纸墨印刷的日报上头版。大标用宋体衬线（Noto Serif SC 900），冲击力来自字重与遮罩揭示而非颜色；正文用无衬线（Noto Sans SC 300/500）。动效走「物理卡堆」路线：卡片被拖动后松手回弹（spring/back.out）、顶卡抛出带轨迹、印章 back.out 压盖。全片克制——纸色不脏、阴影柔和、无彩带粒子、无高饱和渐变，留住「有据」的理性与体面。

## Colors
- `--canvas` `#F6F1E3` — 全局画布（纸米白）
- `--surface` `#FFFCF3` — 卡片表面（白纸）
- `--sunken` `#EDE5CF` — 卡片封面凹陷底（浅亚麻）
- `--ink` `#161410` — 主文字（墨黑）
- `--ink3` `#6A6353` — 次级文字（棕灰）
- `--brand` `#8A6548` — 强调/印章/序号（焦糖棕）
- `--warm` `#E8940B` — 仅用于投票高亮条等单点点缀
- `--rule` `#E4DCC6` — 分隔细线

## Typography
- Display 大标：`"Noto Serif SC", "Songti SC", serif` weight 900 · 字号 ≥ 96px · letter-spacing .01em
- Body：`"Noto Sans SC", "PingFang SC", sans-serif` weight 300/500 · ≥ 38px
- 数字/角标：同体系 Noto Sans SC 600，`font-variant-numeric: tabular-nums`
- 字重对比必须极端（900 大标 vs 300 正文），靠字重层次而非字号堆叠

## What NOT to Do
- 不出现纯色 `#333`、`#1677FF`（纸白蓝体系禁止入境）
- 不用冷白/高饱和娱乐色；不得引入渐变「透明 → 黑」的边缘
- 动画只动 transform/opacity，不 anim 宽度高度；转场统一「缩放交叉溶解」
- 场景结束前不得把内容全部退场——转场即退场
- 不出现彩带粒子、弹跳 emoji、机械式网格转场（廉价感禁忌）