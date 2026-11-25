---
title: "Docs · design-v1 · README.md"
id: markdown_cls1_798285c88467638f6a8dc28635ad6f33_04c97df9548b0182c95383433ebdd9967526104239726721
kb: 有径-YouJing
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# design-v1 · 设计底稿快照（2026-10-26）

> 本目录是「有径-设计底稿 v1」三份契约文档的**只读快照**，防仓库外单点丢失。
> 原件与后续更新仍在：`~/Pictures/有径/有径-设计底稿-v1/docs/`（底稿目录共约 9 MB，
> 含帧截图等资产，不在本快照范围内）。

| 文件 | 角色 |
|---|---|
| `DESIGN.md` | 色板 / 字阶 / 几何 / 材质等设计契约本体，八把审计脚本（`tools/audit_*.py`）的对表基准 |
| `youjing-engineering-handoff.md` | 工程交接稿：§7 逐帧必改表、§12 路由表、帧清单（文档中「handoff §N」均指此文件） |
| `youjing-stitch-prompts.md` | 39 帧的生成底稿（帧哈希 7fc1cb85、1ab099b1 等的出处） |

## 使用口径

- **审计脚本不指向本目录**：`tools/audit_colors.py` 等默认仍读原件路径（底稿搬家后传参即可）。
  快照落后于原件时不影响任何审计行为；如需比对，`diff Docs/design-v1/DESIGN.md <原件路径>`。
- 底稿升版（v2）后，请另建 `design-v2/` 快照目录并更新本 README，不覆盖 v1。
- 快照时间：2026-10-26，原件 mtime 2026-10-22 23:04。
