# 大蓝书 BigBlueBook 鸿蒙应用 — 上线前全检报告

**日期**：2026-07-26
**场景**：上线前检查（代码架构审查 + 安全审计 + QA 测试）
**参与成员**：产品官（架构/未完成逻辑）+ 安全卫士（OWASP+STRIDE 审计）+ 质量门神（QA 测试与发布）
**受审工程**：`/Users/itxiaobai/HarmonyProject1`（鸿蒙 ArkTS/ArkUI 前端 + Express/Prisma 后端，git `main`）
**用户约束**：无鸿蒙真机、无域名、无服务器

---

## 📌 TL;DR（执行摘要）

- **整体结论：🔴 No-Go（当前不可直接进入上架流程）**
- 代码架构整体合理、前后端契约 1:1 完全对齐、状态/错误/空态处理成熟，但**三件硬依赖未闭环**：生产域名+HTTPS、AGC 客户端/推送/签名配置、关闭开发桩登录并切换 `BASE_URL`。
- **安全侧存在致命设计缺陷**：开放 `openId` 登录可任意冒充身份、开发桩账号直通管理员、`.env` 含真实可用的腾讯云密钥与静态 JWT 密钥。
- **质量侧**：后端测试套件 8/134 失败（测试腐化，非产品缺陷）、缺 CI、前端无真机/联调测试能力（受约束阻塞）。
- 阻塞项 8 项 + 依赖资源项若干；下一步先清 P0 代码/配置问题，再补域名/服务器/真机/AGC 资源。

---

## 🎯 核心结论卡片

| 项目 | 内容 |
|------|------|
| Go / No-Go | 🔴 No-Go |
| 严重度分布 | 🔴 6 / 🟠 8 / 🟡 12 / 🟢 6（含正面观察） |
| 关键行动项 | 10 条 |
| 建议负责人 | 全栈 / 运维 / 产品 / 法务 |
| 上线前最大风险 | 开发桩登录直通管理员 + 密钥明文 + 无真机联调验证 |

---

## 1. 各成员核心结论

### 🔍 产品官（代码架构审查 + 未完成逻辑）
架构成熟度超出 MVP 预期：前端分层清晰（pages/components/services/utils/models），状态管理用 AppStorage+PersistentStorage + `likeStore`/`nav` 单例，列表页三态（loading/error+重试/空态）完整；后端为 Express+Prisma+JWT+Helmet+CORS+限流+全局错误归一，生产缺失 `JWT_SECRET`/`CORS_ORIGIN` 会 fail-hard 拒绝启动。前后端 50 个接口路径 1:1 对齐、无悬空调用。阻塞项集中在发布配置与外部依赖：`BASE_URL` 硬编码 localhost、开发桩登录在生产路径、真实登录/推送/上传依赖 AGC/签名/域名/COS。未完逻辑含分享占位、上传生产链路未闭环、微信绑定死代码等。

### 🛡️ 安全卫士（OWASP Top 10 + STRIDE 审计）
后端鉴权/授权框架规范（强制 auth 中间件、归属校验、管理员 `auth+adminAuth`、投影剥离 openId、Prisma 参数化查询、无 WebView/无深链接），但**一处致命缺陷**：`/v1/auth/login` 接受任意 `openId` 且无身份证明即签发 JWT，叠加"种子管理员 `dev-seed-openid`=id 1 + 默认 `ADMIN_USER_IDS=1` + 开发桩按钮随包发布"，攻击者可零成本冒充任意用户甚至取得管理员权限。另 `.env` 含真实腾讯云密钥与静态 JWT 密钥、Token 明文存 Preferences、全链路 HTTP。共 🔴3/🟠4/🟡6/🟢6（含 2 项正面观察）。

### ✅ 质量门神（QA 测试与发布就绪）
后端具备 Jest+ts-jest 离线测试资产（18 套件/134 用例，实测 126 通过/8 失败），但已腐化且**无 CI/pre-commit 门禁**未被拦截；前端 4 个 .ets 测试均为 DevEco 脚手架桩（零业务覆盖），HAP 构建/lint 仅 IDE 可做。受约束阻塞：真机 UI/性能/功耗、端到端联调、线上灰度监控均无法完成。`BASE_URL` 硬编码 localhost。结论 🔴 NO-GO，须先修复后端测试、切生产域名、补 CI、DevEco 实跑 release 构建+lint；真机/联调类以"IDE 构建通过+后端 mock 测试全绿+静态检查+人工评审"作替代证据并明示风险。

---

## 2. 综合审查发现（去重合并后按严重度排序）

| # | 严重度 | 类别 | 位置 | 问题描述 | 建议 | 来源成员 |
|---|--------|------|------|---------|------|---------|
| 1 | 🔴 | 认证绕过 | backend/src/routes/auth.ts:17-22, authService.ts:11-30; entry/.../utils/auth.ets:92-96; LoginPage.ets:179-195 | 开放 `openId` 登录，接受任意客户端 openId 即签发 JWT，可任意身份冒充/账户接管 | 生产禁用该入口；登录强制走华为 Account Kit（服务端 client_secret 换 token） | 安全卫士 |
| 2 | 🔴 | 权限提升 | prisma/seed-post.ts:11-20; backend/.env:35; middleware/adminAuth.ts:9 | 种子管理员 `dev-seed-openid`=id 1，默认 `ADMIN_USER_IDS=1`，开发桩按钮一键拿管理员令牌 | 移除开发桩可达路径；取消默认 id=1 管理员，改显式开通流程 | 安全卫士/产品官 |
| 3 | 🔴 | 密钥泄露 | backend/.env:13,26-27 | 含真实腾讯云 AK/SK 与静态 JWT_SECRET（明文落盘） | 立即轮换；生产用密钥管理服务/环境变量注入，禁止入库或镜像 | 安全卫士 |
| 4 | 🔴 | 配置 | entry/src/main/ets/services/api.ets:9 | `BASE_URL='http://127.0.0.1:3000'` 编译期常量，release 指向 localhost | 改 `https://api.bigbluebook.com` 并支持 build-mode 注入 | 产品官/质量门神/安全卫士 |
| 5 | 🔴 | 测试腐化 | routes/posts.test.ts, posts.following.test.ts, postService.test.ts, privacyService.test.ts | 后端 8/134 测试失败（mock 缺 prisma.debateVote；隐私断言仍用 allowMessage 应为 dmPolicy） | 补 debateVote mock + 隐私断言改 dmPolicy，使 npm test 全绿 | 质量门神 |
| 6 | 🔴 | 认证绕过 | LoginPage.ets:179-195; auth.ets:92-104 | 生产路径保留"其他方式登录"按钮调 `loginWithDevStub()`，任何人可借此登录/批量建号 | 加 `NODE_ENV`/`buildMode` 开关，release 移除该按钮 | 产品官（重叠 #1/#2） |
| 7 | 🟠 | 密钥存储 | entry/.../utils/auth.ets:9,47-55 | JWT 明文存 PersistentStorage（Preferences 不加密），30 天有效无吊销 | 改存 `@ohos.security.asset` Asset Store；缩短有效期+刷新令牌 | 安全卫士 |
| 8 | 🟠 | 传输安全 | api.ets:9; backend/.env:7 | 全链路 HTTP，Token/PII 明文传输，无 HTTPS/证书固定 | 切 HTTPS；生产强制 HTTPS 重定向；评估证书固定 | 安全卫士 |
| 9 | 🟠 | 鉴权缺失 | backend/src/routes/upload.ts:41-65; app.ts:55 | 本地上传 `/v1/upload/local` 无 auth，`/uploads` 静态暴露（开发兜底误用于生产风险） | 生产仅允许 COS 模式；移除 `/uploads` 静态挂载 | 安全卫士 |
| 10 | 🟠 | 配置 | backend/docker-compose.yml:6-15 | MySQL root/bigbluebook 弱口令 + 3306 映射宿主机所有网卡 | 强随机密码；`127.0.0.1:3306` 仅绑本地；生产用托管库+安全组 | 安全卫士/质量门神 |
| 11 | 🟠 | 密钥卫生 | entry/build-profile.json5:10-14 | 签名 keyPassword/storePassword 明文入库（.p12 已被 gitignore 未泄露本体，但密码入库存放不当） | 密码移出仓库，用 AGC/环境变量注入 | 产品官/质量门神/安全卫士 |
| 12 | 🟠 | 功能未完成 | utils/share.ets; DetailPage.ets:366-370; ShareSheet.ets | 分享仅复制占位域名链接，未接 SystemShareKit，"系统分享"仅 toast | 定域名后替换 `SHARE_BASE` 并接入系统分享面板 | 产品官 |
| 13 | 🟠 | 功能未闭环 | app.ts:55; image.ets; api.ets:159-168 | 图片上传生产须 COS 直链+CDN，现仅本地静态兜底 | 配置 COS+CDN，生产替换本地兜底 | 产品官 |
| 14 | 🟠 | 工程门禁 | 仓库无 .github/workflows；无 husky | 无 CI/无 pre-commit，后端测试腐化未被拦截 | 加 GitHub Actions 跑 npm test + tsc | 质量门神 |
| 15 | 🟡 | 安全闸口 | backend/src/index.ts:11-23; config/env.ts:8-9 | 安全闸口仅依赖 `NODE_ENV=production`，遗漏则 CORS 退化为全放开 | 以显式安全开关为准，缺失关键配置无论环境均拒绝启动 | 安全卫士 |
| 16 | 🟡 | 限流失效 | 未设 `trust proxy`；rateLimit.ts | 代理后 `req.ip` 解析错误，per-IP 限流被绕过 | 按拓扑 `app.set('trust proxy', 1)`；限流键结合 XFF+用户身份 | 安全卫士 |
| 17 | 🟡 | 滥用风险 | posts.ts:104; comments.ts:35; messages.ts:63 | 发帖/评论/私信/关注缺用户级频控 | 按 userId 加合理频控 | 安全卫士 |
| 18 | 🟡 | 日志泄露 | errorHandler.ts:45-47; posts.ts:127; comments.ts:52 | 5xx 直接 `console.error` 完整 err，可能含 SQL/参数/用户标识 | 结构化日志脱敏，仅记错误码/追踪 ID | 安全卫士 |
| 19 | 🟡 | 合规(PIPL) | auth.ets:18,121-128; Index.ets | 隐私同意仅客户端标记，服务端无留存/可追溯 | 服务端落地同意版本+时间戳，支持撤回/导出 | 安全卫士 |
| 20 | 🟡 | 最小暴露 | auth.ts:43-47 | `/auth/me` 返回完整 User 行（含 openId/unionID） | 仅投影公开/自用必要字段 | 安全卫士 |
| 21 | 🟡 | 死代码 | accountBindingService.ts:19; schema.prisma; types.ets | 微信绑定声明但未实现（bind 返回"暂不支持"） | 实现 OAuth 或清理声明 | 产品官 |
| 22 | 🟡 | 配置卫生 | backend/src/config/env.ts:13-20,33 | `OSS_*` 死配置未用；`REPORT_THRESHOLD` 变量名笔误 | 删除死配置；修正变量名 | 产品官 |
| 23 | 🟡 | 可观测性 | theme.ets; Index.ets:87; MessagePage | 防御性 `catch {}` 空吞异常，排障困难 | 关键路径至少 `hilog` 留痕 | 产品官 |
| 24 | 🟡 | 体验 | 列表均每次拉后端，无离线缓存 | 断网即无内容 | MVP 可接受，标注风险 | 产品官 |
| 25 | 🟡 | 可测性 | api.ets 直接依赖 AppStorage+http 单例 | 无 DI，难单测 | 引入可注入网络层 | 质量门神 |
| 26 | 🟡 | 工程 | 前端 code-linter 仅 IDE 可做 | CLI 无 hvigor/ohpm 工具链 | 列入发布前人工清单 | 质量门神 |
| 27 | 🟢 | 产品决策 | 全仓无 payment/pay/order/iap | 无支付/内购模块（设计如此？） | 立项确认无需 IAP/电商后再上架 | 产品官 |
| 28 | 🟢 | 安全 | messageService.ts:126-137 | `$queryRawUnsafe` 但参数化（`?` 绑定），不可注入 | 收敛为类型化查询或固化注释 | 安全卫士 |
| 29 | 🟢 | 供应链 | package.json | 依赖较新（express 4.21.x/jsonwebtoken 9），无显旧项 | 上线前跑 `npm audit`/SCA | 安全卫士 |
| 30 | 🟢 | 正面观察 | module.json5:55-59 等 | 权限最小化（仅 INTERNET）、无 WebView、无深链接消费 | 保持为上线基线 | 安全卫士 |
| 31 | 🟡 | 合规/运营 | ModerationPage; /v1/admin/* | 管理员审核台存在，需确认 `ADMIN_USER_IDS` 角色下发与可用性 | 上线前自查审核流真实可用 | 产品官 |
| 32 | 🟡 | 合规 | PrivacyPage/UserAgreementPage | 隐私政策正文疑似占位 | 替换为正式法务文案 | 产品官 |

---

## 3. Go/No-Go 决策与阻塞项清单（上线前检查专属）

### 决策：🔴 NO-GO（当前不可直接上架）

**阻塞项清单（必须清零方可 Go）：**
1. 修复后端 8 个测试失败（Q-001 / 发现 #5）
2. `BASE_URL` 切换为生产 HTTPS 域名（发现 #4）
3. 禁用 openId 开发登录入口 + 移除前端"其他方式登录"按钮 + 取消 `ADMIN_USER_IDS=1` 默认（发现 #1/#2/#6）
4. 轮换 JWT_SECRET 与腾讯云 AK/SK，移出 `.env`，生产用注入式密钥（发现 #3）
5. 补齐 CI 或人工门禁，确保测试不腐化（发现 #14）
6. 前端 release 构建 + code-linter 在 DevEco 实跑通过（受工具链约束，手动执行）
7. Token 改存 Asset Store + 缩短有效期（发现 #7，部分依赖 HTTPS）
8. 隐私政策正式法务文案 + 服务端同意持久化（发现 #19/#32）

**依赖资源、暂无法闭环（须显式记录为上线风险）：**
- 无域名/服务器 → 生产 `BASE_URL`、CORS_ORIGIN、DATABASE_URL、COS/CDN、Push 凭证、AGC 应用配置均无法落地（发现 #4/#8/#9/#10/#12/#13）。
- 无真机 → 真机兼容性/性能/功耗、华为 Account Kit 端到端登录、真机推送、沙箱/备份提取 Token 可行性（发现 #7/#8 动态层）无法验证。
- 无服务器 → 后端生产部署、线上联调、灰度监控、trust proxy/限流真实表现、5xx 日志内容（发现 #15-#20 动态层）无法验证。

### 回滚预案（草案）
- **应用侧（AppGallery）**：暂停分阶段发布 / 重提上一稳定版本包 / 紧急下架；`BASE_URL` 经 AGC Remote Configuration 远程下发，避免为配置回滚发版；灰度 1%→5%→20%→100% 阶梯，保留上一版产物。
- **后端侧**：`git revert` + 重启 node（start.sh）；Prisma 前向-only，回退需 `migrate resolve --rolled-back` 或 down migration，重大变更前备份 MySQL volume；`.env` 经环境变量管理；保留上一进程/镜像。当前无蓝绿/金丝雀能力，建议补。

---

## ✅ 行动清单（具体可执行项）

| # | 行动 | 负责方 | 紧急度 | 期望完成 |
|---|------|--------|--------|---------|
| 1 | 修复 8 个后端测试失败（补 `prisma.debateVote` mock + 隐私断言改 `dmPolicy`） | 后端 dev | P0 | 本周 |
| 2 | `BASE_URL` 改 `https://api.bigbluebook.com` + 引入 build-mode 切换，release 不再硬编码 localhost | 前端 dev | P0 | 取域名后 |
| 3 | 后端禁用 openId 登录入口 + 前端移除"其他方式登录"按钮（加 NODE_ENV 开关）；取消 `ADMIN_USER_IDS=1` 默认，改显式管理员开通 | 全栈 | P0 | 发布前 |
| 4 | 轮换 JWT_SECRET 与腾讯云 AK/SK；密钥/签名密码移出仓库（环境变量/AGC 注入） | 运维+全栈 | P0 | 立即 |
| 5 | 加 GitHub Actions CI：npm test + tsc；前端 lint 列入发布前人工清单 | devops | P1 | 本周 |
| 6 | Token 改存 `@ohos.security.asset` Asset Store + 缩短有效期 + 全链路 HTTPS | 前端+运维 | P1 | 域名就绪后 |
| 7 | 取域名+服务器后配置 CORS_ORIGIN/DATABASE_URL/COS/CDN/Push 凭证 + AGC 应用配置（client_id/签名指纹/Push） | 运维+AGC | P0/P1 | 资源就绪后 |
| 8 | 分享接入 SystemShareKit + 真实 `SHARE_BASE`；上传改用 COS+CDN；推送开 AGC Push | 全栈 | P1 | 资源就绪后 |
| 9 | 隐私政策正式法务文案替换占位；服务端落地同意版本+时间戳（PIPL） | 产品+法务+后端 | P1 | 发布前 |
| 10 | 清理死代码（OSS_*/wechat 绑定/REPORT_THRESHOLD 笔误）+ 空 catch 加 hilog | 前端+后端 | P2 | 迭代内 |

---

## ⚠️ 待完善 / 已知局限

- 本次为**纯静态代码审计**，无真机/无服务器/无动态渗透：发现 #7/#8/#9/#10/#15-#20/#29 等动态/环境层面需在具备资源后补验。
- **真机兼容性/性能/功耗、端到端联调、线上灰度监控** 4 类测试因"无真机+无服务器+无域名"无法完成，已显式记录为上线风险。
- 结论基于 2026-07-26 代码快照；代码后续变更需重审。
- 后端 `.env` 密钥未提交 git（已 gitignore，git 历史无记录），但明文存在于工作目录，须立即轮换。

---

## 📚 成员产出索引

- gstack-product-reviewer（产品官）原始产出：本会话 teammate 消息《架构审查 + 未完成逻辑报告》
- gstack-security-officer（安全卫士）原始产出：本会话 teammate 消息《OWASP Top 10 + STRIDE 安全审计报告》
- gstack-qa-lead（质量门神）原始产出：`/Users/itxiaobai/HarmonyProject1/deliverables/gstack/qa-release-readiness-bigbluebook-2026-07-26.md`

---

> 本报告由软件工坊 AI 协作生成（GStack 主理人汇编），关键决策请由工程负责人复核。
