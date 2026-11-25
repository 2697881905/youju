---
title: "harmony-learning-2026-10-01.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_67d45d843c4dfa5b6d436ff6d9ab8f237505655250320770
kb: 有据-YouJu
folder: "决策记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
# 增量学习 · 2026-10-01（有据文档同步）

> 来源：本次新处理文档 4 篇（2 新增 + 2 修改），全部归入「开发文档」：
> - 新增 `.trae/documents/unify-moderation-console.md`（审核台合并实施计划）
> - 新增 `docs/search-panel-input-analysis.md`（搜索框代码与样式分析）
> - 修改 `backend/DEPLOY.md`（补充 Git→生产自动部署章节）
> - 修改 `docs/feature-index.md`（更新举报中心合并、弹窗材质约定）

## 3 条项目事实

1. **举报中心合并完成**：原内容审核台（`ModerationPage` + `GET /v1/admin/posts/pending` + `POST /posts/:id/moderate` + `moderationService.ts`）于 2026-09-29 下线，并入举报中心（`ReportAdminPage`），成为唯一处置台。`resolve` 统一三动作 `resolved/dismissed/restore`，处置即同时决定内容 `status` 与作者通知，消除双流程与静默下架。
2. **搜索框复用 `GlowInput`（`segmentStyle:true` 玻璃材质）**：近四轮样式反复（H6 沉浸光感 → 原生 Search → H7 定制胶囊 → revert 回 `GlowInput` 玻璃底）后收敛到「与首页分段栏同材质、零 `@since 6.1.0` API 兼容风险」方案；`GlowInput` 7 个调用方（搜索面板/结果页/评论 Dock/聊天页/编辑资料/收藏夹命名/分享私信）共享一份实现。
3. **生产自动部署机制**：服务器 systemd timer 每 2 分钟 `git fetch` + fast-forward 滚动部署（保留健康检查 / 失败回滚 / schema 对账）；以 `~/.local/state/youju-autodeploy/last-deployed` SHA 为判据而非本地 HEAD；`CORS_ORIGIN` 与 `BACKEND_PUBLIC_URL` 生产必填且必须为 https，缺失启动即崩。

## 2 条关键决策

1. **审核台合并决策**：删除独立审核台全链路（页面 + 路由 + service + 类型 + 设置/消息入口）；举报处置即决定内容状态与作者通知；存量 `status=2`（旧拒绝产物）保持隐藏不恢复，恢复走一次性数据修复单独确认；`dismissed` 仅在确实处于下架态才 `0→1` 恢复并通知作者，`restore` 强校验「非 user + 无 pending + 当前 status=0」否则 400。
2. **弹窗材质决策（feature-index 重申）**：大面积承载正文的浮层不适合 `outlined`（对比不足约 1.1:1），`outlined` 仅适用于小面积单行控件级；关掉 HDS 流光后面板在部分真机会渲染为实心块，不要靠内部元素透明度解决面板问题，剩余杠杆是面板外阴影与描边对比度。

## 1 个可复用模式 / 检查项

**功能下线联动检查清单（可复用）**：删除长期存在的页面 / 接口时必须同步清理五处，避免遗留引用导致构建或运行故障：
① `main_pages.json` 摘路由 ② 设置页 / 消息页入口合并 ③ 登录门禁脚本 `GLOB/PAGES`（`scripts/verify-login-gates.mjs` 的 `GATED_PAGES`）④ 旧接口 404 护栏测试 ⑤ `docs/feature-index.md`、`docs/risk-assessment/*`、`entry/Docs/*` 文档标注「已下线」。本次审核台合并计划即此范式。

---
*运维备注（非主线）：增量同步扫描须把 `.mermaid` 纳入候选文档类型并与 state 对齐，否则已同步的 mermaid 文件会被误判为本地删除；`design/`、`hyperframes-*/`、`output/` 等展示 / 代理目录须整体排除，避免噪声条目。*
