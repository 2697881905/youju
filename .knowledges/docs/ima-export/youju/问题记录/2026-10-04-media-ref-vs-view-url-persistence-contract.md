---
title: "2026-10-04-media-ref-vs-view-url-persistence-contract.md"
id: markdown_798285c88467638f6a8dc28635ad6f33_d1a35be55ced9887cf9bda263cc7178f7505655250320770
kb: 有据-YouJu
folder: "问题记录"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
---
id: 2026-10-04-media-ref-vs-view-url-persistence-contract
title: 媒体资源持久化必须存稳定引用而非短时 URL：mediaRef 与 viewUrl 分离契约
category: coding-pattern
nature: pitfall
created_at: 2026-10-04T22:48:18
updated_at: 2026-10-04T22:48:18
tags: [media-upload, url-resolution, persistence, object-storage, cos]
keywords: [mediaRef, viewUrl, resolveDisplayImageUrl, resolveUploadPutUrl, getUploadSignature, cos://, 预签名, 短时链接, BASE_URL, Image 明文限制, 对象存储]
problem_patterns: [persist-short-lived-url-into-db, per-call-url-string-concatenation, upload-uses-lan-ip-in-local-mode, image-vs-http-plaintext-behavior-mismatch]
source_sessions: [ses_ef8a5f1e1ffe6ZlDmgrucRDwMC]
project: HarmonyProject1
severity: high
quality_score: 84
hit_count: 0
last_hit_at: null
low_quality_hit_count: 0
tier: A
related_experiences: [2026-09-15-unified-api-wrapper-bypass-risk, 2026-09-15-arkui-image-error-handling]
---

# 媒体资源持久化必须存稳定引用而非短时 URL：mediaRef 与 viewUrl 分离契约

## Scenario
图片/视频经对象存储上传后，前端会拿到多个形态的地址：预签名 PUT 上传地址、短时预览链接、对象 key、CDN 地址、后端的媒介引用。业务数据（帖子、草稿、头像、背景图）需要把其中一个写库长期保存。

## Key Signals
- 把短时预览链接 / CDN 链接直接写库 → 链接过期或换域名后，历史数据全部白屏。
- 后端把宿主 LAN IP（如 `192.168.1.100`）写进 URL → 换网络/换网段后失效，真机报"无法连接后端服务"。
- 上传在模拟器失败：预签名 URL 指向宿主 LAN IP，模拟器连不上。
- 同一张图"接口能取到、`http` 模块能请求，但 `Image` 组件不显示"——症状相同但根因不同。

## Essence
把"持久化用的标识"和"展示/上传用的 URL"当成两个不同的东西，用契约隔离：

- **持久化层只存稳定引用** `mediaRef`（如 `cos://<key>`），**绝不**存短时 `viewUrl` / `cdnUrl`；写库唯一入口是 `toStoredMediaRef(sig)`。
- **展示层**统一通过 `resolveDisplayImageUrl(url)` 在读取时把引用重写为当前可用的展示 URL：`cos://` 前缀 → 固定走生产 HTTPS media 代理；历史 LAN IP → 按当前 `BASE_URL` 重写。
- **上传层**通过 `resolveUploadPutUrl(sig)` 解析直传目标：`cos` 模式直接用后端下发的外部预签名地址；`local` 模式必须改写成 `BASE_URL`（否则模拟器直连 LAN IP 上传失败）。

关键认知：`cos://` 展示统一走生产 HTTPS 代理，是因为 **ArkUI `Image` 组件对明文 http / IP 地址有额外限制，而 NetworkKit `http` 模块不受同样限制**——两者行为不对称。所以上传（走 http 模块）可用 `BASE_URL`，而图片展示必须给 `Image` 一个 HTTPS 地址。

替代方案取舍：各处自行拼接 URL 被否——一旦域名/协议策略变化需全量改；统一重写函数被采纳，风险收敛到一处。

## Approach
1. 在 `UploadSignature` 中显式区分字段语义：`url`(直传目标) / `key`(对象 key) / `mediaRef`(持久化引用) / `viewUrl`(短时预览) / `cdnUrl`(兼容不写库) / `mode`(cos|local)。
2. 业务写库只调用 `toStoredMediaRef(sig)`，禁止写入 `viewUrl`。
3. 所有展示路径先过 `resolveDisplayImageUrl`，禁止在页面里直接拼 `BASE_URL`。
4. 上传调用 `resolveUploadPutUrl(sig)` 分支处理 cos/local，不要在调用处判断。
5. `BASE_URL` 由构建期常量 `DEBUG` 决定（debug=本地联调、release=生产），不硬编码在业务代码。

## Faster Next Time
- 写库前先问两个问题：这个 URL 会过期吗？会随网络/域名变化吗？任一为"会"，就改存 key/引用。
- URL 重写逻辑**必须收敛到单一函数**；出现第二处字符串拼接就是隐患。
- 真机图片不显示时，先分类：数据里存了错的 URL，还是 `Image` 组件不接受该协议/地址？两者修复路径不同。
- 本地联调上传优先用 `hdc rport tcp:3000 tcp:3000` 端口转发（与网络环境解耦）；LAN IP 仅作备份，换网即失效。

## Applicability Boundaries
- 适用：使用对象存储 / CDN / 预签名上传的媒体持久化场景。
- 不适用：URL 本身就是稳定永久地址的情况。
- 触发重估：存储服务、域名策略、调试通道（rport ↔ LAN IP）变更时。

## Evidence or Examples
（来源：HarmonyProject1 发布流程调研）
- `entry/src/main/ets/services/api.ets` L15-18 `BASE_URL`（debug `http://127.0.0.1:3000` / release `https://api.youju.chat`）；L22-36 `resolveDisplayImageUrl`（`cos://` → `https://api.youju.chat/v1/media/<key>`；历史 LAN IP 重写）；L280-289 `UploadSignature` 各字段注释；L291-293 `toStoredMediaRef`（"持久化必须使用 mediaRef"）；L300-309 `resolveUploadPutUrl`；L735-749 `getUploadSignature`（release 走 cos，debug 走 local）。
- `entry/src/main/ets/components/ImagePicker.ets` L1-3 头注释（PhotoViewPicker → 压缩 → 预签名 PUT 直传）；L69-96 `putBinary` 直接用 `http` PUT 到 COS，绕过 `api.ets`（对照 experience `unified-api-wrapper-bypass-risk`）。
- api.ets L28-30 注释：`Image` 组件不发 http 明文/IP 请求，`http` module 不受限——平台行为不对称的直接证据。
