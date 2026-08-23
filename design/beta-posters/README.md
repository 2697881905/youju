# 有据 · 上线预告海报系列（P1–P4）

> 1080×1920 · 价值观驱动 · 即将上线预告 · 纸白底 + 宋体衬线大标 + 黑白灰主调 + 品牌蓝 #1677FF 仅作点缀

## 文件结构

| 文件 | 用途 |
|---|---|
| `index.html` | 4 张海报画廊页面（浏览器预览用，1080×1920 设计空间，缩放 0.5 展示） |
| `gen-posters.js` | SVG/PNG 生成脚本（Node + sharp/librsvg 渲染系统宋体） |
| `export/P1-预告主海报.svg` / `.png` | 预告主海报：真实经验，有据可循 + 灰阶信息流卡片 + 蓝 CTA |
| `export/P2-理性.svg` / `.png` | 价值观 01：拒绝标题党 + 五体裁卡 + 辩论投票（唯一蓝 = 方案B 进度条） |
| `export/P3-友善.svg` / `.png` | 价值观 02：不喜欢就少推点 + 大字「」引号母题（蓝锚点） + 三行宣言 |
| `export/P4-共创.svg` / `.png` | 价值观 03：把经验装进口袋 + 五条上架预约清单 |

## 设计令牌（已锁定）

| 角色 | 值 |
|---|---|
| 纸白底 | `#FAFAFA` |
| 卡片白 | `#FFFFFF` |
| 浅灰块 | `#F2F2F5` |
| 主文字 | `#0D0F12` |
| 次级文字 | `#6E6E73` |
| 三级文字 | `#AEAEB2` |
| 分隔线 | `#E5E5EA` |
| 品牌蓝（仅点缀） | `#1677FF` |
| 中文大标 | `Songti SC, Noto Serif SC, serif` · 900 |
| 中文正文 | `PingFang SC, Noto Sans SC, sans-serif` · 300/400 |
| 英文/数字 | `Outfit / Helvetica Neue / Arial` · 600/800 |

蓝色仅出现于 3 处：CTA 按钮、二维码占位区、关键数字 / 锚点。

## 海报文案（统一行动召唤）

**主 CTA**：预约上架提醒 →  
**提示文案**：上架第一时间通知 · 敬请期待  
**二维码**：上架提醒登记（占位，待替换为上线提醒/预约链接）  
**底部**：© 2026 有据 · 鸿蒙原生理性内容社区

## 投放建议

- 公众号封面 / 朋友圈：1080×1920 PNG 直接用
- 二维码替换：用任何二维码生成器生成后，替换 `export/P*.svg` 中的 dashed 占位区（或在 HTML 中替换 `.qr` 区块为 `<img>`）
- 文案微调：编辑 `gen-posters.js` 对应函数后重跑
- 重新导出 PNG：`cd design/beta-posters && NODE_PATH=/Users/itxiaobai/.workbuddy/binaries/node/workspace/node_modules /Users/itxiaobai/.workbuddy/binaries/node/versions/22.22.2/bin/node gen-posters.js`

## 重新生成依赖

- Node 22（托管 runtime）
- `sharp` 图像库（`/Users/itxiaobai/.workbuddy/binaries/node/workspace/node_modules` 已安装）
- librsvg 复用系统 Songti SC / PingFang SC 字体（macOS 预装）

## 备注

- 当前环境未接入 **Ardot 画布 MCP**（`~/.workbuddy/mcp.json` 未配置 ardot 服务），故采用 HTML+SVG+PNG 方案交付。Ardot 连接器接入后，可将同一套设计令牌与版式迁移至画布。
- 浏览器渲染（Chrome/Edge headless）在当前沙箱被 SIGKILL（exit 137），故改走 librsvg（sharp）渲染。
