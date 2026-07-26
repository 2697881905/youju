# 大蓝书 BigBlueBook 鸿蒙应用 — QA 测试与发布就绪评估报告

- **评估日期**：2026-07-26
- **评估人**：gstack-qa-lead（QA 测试与发布就绪）
- **工程位置**：`/Users/itxiaobai/HarmonyProject1`（entry 前端 / backend 后端 / docs / deliverables）
- **约束前提**：用户明确【无鸿蒙真机、无域名、无服务器】。本评估据此区分「可做 / 被阻塞」，所有结论均基于真实代码证据。

---

## 1. 测试现状总结（一段）

后端具备较完整的 **Jest + ts-jest** 测试资产（18 套件 / 134 用例），且团队规范地用 `jest.mock('../prisma')` 与 `global.fetch` mock 把数据库与外部 HTTP 全部拦截，**可完全离线运行**（实测 0.8s，126 通过 / 8 失败）；前端则仅配置了 `@ohos/hypium`+`@ohos/hamock` 依赖，但 4 个 `.ets` 测试文件均为 DevEco 脚手架桩（只断言 `expect('abc').assertContain('b')`），**真实业务零覆盖**；HarmonyOS 构建与 code-linter 工具链（ohpm/hvigor）**不在本机 CLI**，但 `.hvigor/report` 证明 DevEco IDE 曾成功执行 `PreviewBuild`/`assembleHap`，故构建能力存在、仅无法在此环境脚本化执行。当前**无 CI、无 pre-commit 门禁**，导致后端测试已腐化（8 例失败）却未被拦截。

---

## 2. 可测试 vs 被阻塞矩阵

| 测试类别 | 状态 | 证据 / 原因 |
|---|---|---|
| 后端 单测 / 路由集成（mock DB） | ✅ **可做** | Jest 离线可跑，已实测 134 用例 |
| 后端 类型检查（`npm run build` tsc） | ✅ **可做** | `tsc -p tsconfig.json`；ts-jest 已 `isolatedModules` |
| 后端 真实 DB 集成测试 | 🔴 **阻塞** | 无 MySQL 服务器（`docker-compose.yml` 仅定义 mysql，本地未起） |
| 后端 E2E / 负载 / 契约测试 | 🔴 **缺失+阻塞** | 无实现；且需服务器 |
| 前端 静态检查（code-linter） | 🟡 **仅 IDE 可做** | `code-linter.json5` 已配 `@security`/`@performance`/`@typescript-eslint` 规则，但 ohpm/hvigor 不在 CLI，需 DevEco 运行 |
| 前端 hvigor 构建（debug/release HAP） | 🟡 **仅 IDE 可做** | `.hvigor/report` 证明 IDE 曾成功构建；CLI 无工具链 |
| 前端 单测（hypium） | 🔴 **阻塞（无价值）** | 现有测试为脚手架桩，无真实用例；且需 DevEco/模拟器运行 |
| 前端 UI 自动化（ohosTest） | 🔴 **阻塞** | 无真机/模拟器（hdc 无可连接设备） |
| 真机兼容性 / 性能 / 功耗 | 🔴 **阻塞** | 无真机（用户明确无设备） |
| 端到端联调（前端↔后端） | 🔴 **阻塞** | 无服务器 + 无真机 + `BASE_URL` 硬编码 localhost |
| 线上监控 / 灰度验证 | 🔴 **阻塞** | 无服务器 / 域名 / AGC 发布通道 |

---

## 3. 发现的问题清单（按严重度）

### 🔴 阻塞（发布门禁级别）
- **P1 后端测试套件 RED（8/134 失败）**
  - 位置：`backend/src/routes/posts.test.ts`、`routes/posts.following.test.ts`、`services/postService.test.ts`、`services/privacyService.test.ts`
  - 问题（已定位根因，均为**测试腐化、非产品缺陷**）：
    1. `postService` 新增 `myVote`/`debateVote` 打标（postService.ts:118、192），但 3 个测试 mock 工厂未加 `prisma.debateVote` → `TypeError: Cannot read properties of undefined (reading 'findMany')` → 路由返回 500（posts/posts.following 共 3 例）。
    2. `privacyService.test.ts` 仍断言 `allowMessage: true`，但代码/Prisma schema/前端 `types.ets` 三方一致已 rename 为 `dmPolicy`（privacyService.ts:11、schema:255、types.ets:223）→ 2 例断言失败。
  - 建议：修复 4 个套件（补 `prisma.debateVote` mock；隐私断言改 `dmPolicy:'all'`），使 `npm test` 全绿后再发布。属于低风险测试修复。
- **P2 无 CI / 无 pre-commit 门禁**
  - 位置：仓库根（无 `.github/workflows`）、`backend/package.json`（无 husky）
  - 问题：测试与 lint 不被强制，P1 腐化累积未被拦截。
  - 建议：至少加 GitHub Actions 跑 `npm test` + `npm run build`；或本地 husky pre-commit。
- **P3 前端 `BASE_URL` 硬编码 localhost**
  - 位置：`entry/src/main/ets/services/api.ets:9` → `export const BASE_URL = 'http://127.0.0.1:3000'`；注释写明「上架后：https://api.bigbluebook.com」但代码未切换，且无 build-mode/资源注入机制。
  - 问题：上架后 App 仍指向本地，无法连生产后端；且当前无域名/服务器，属「约束 + 配置缺口」双重问题。
  - 建议：按 build mode 切换（debug=local，release=生产域名），或抽到 resource 配置；发布前务必改为生产域名。

### 🟠 严重
- **P4 后端路由/服务覆盖缺口大**
  - 位置：未测路由 `block / export / interact / messages / privacy(有 service 测无 route 测) / push / search / tags / upload`（共 9）；未测服务 `accessControl / accountBinding / comment / follow / huaweiPush / interact / message / moderation / notification / search / tag / upload`（共 12）。
  - 问题：核心信息流/鉴权/通知有覆盖，但 DM 私信、点赞互动、搜索、标签、上传、隐私路由、推送等回归无保障。
  - 建议：优先为 `messages`/`interact`/`privacy`/`upload` 补集成测试。
- **P5 `build-profile.json5` 明文密钥**
  - 位置：`build-profile.json5:10-14` 的 `keyPassword`/`storePassword` 明文。
  - 问题：`.p12` 已被 `.gitignore` 排除（未入库），但密码字符串留在源码内。
  - 建议：改由 AGC/环境变量注入，不入库明文。（已同步安全官）

### 🟡 一般
- **P6 前端可测性低**：`api.ets` 直接依赖 `AppStorage` + `http` 全局单例，无 DI/接口抽象，难以在 hypium 中单测与 mock 后端。建议抽取请求层接口。
- **P7 `docker-compose.yml` MySQL 弱口令 + 暴露 3306**：`MYSQL_ROOT_PASSWORD: root`、`MYSQL_PASSWORD: bigbluebook`、端口映射 `3306:3306`。本地开发可接受，生产必须改强口令且不暴露端口。
- **P8 前端 lint 无法 CLI 执行**：需 DevEco 手动跑 code-linter；建议列入 IDE 发布前手动 Check 清单。

### 🟢 建议
- **P9 增加前后端契约测试**：本次发现 `dmPolicy/allowMessage` 前后端已对齐但测试过期，契约测试可防此类漂移。
- **P10 文档化 DB 迁移回退**：Prisma migrate 前向-only，回退需 `prisma migrate resolve --rolled-back` 或 down migration，应写入发布 SOP。

---

## 4. 上线前 QA 检查清单（Checklist）

| 条目 | 状态 |
|---|---|
| 后端 `npm test` 全绿 | 🔴 缺失（8 失败，P1） |
| 后端 `npm run build`（tsc）通过 | 🟡 部分（ts-jest 已跑通；建议实跑完整 tsc） |
| 前端 hvigor 构建（release HAP）通过 | 🟡 部分（IDE 曾成功；未用最新代码复跑） |
| 前端 code-linter 通过 | 🔴 缺失（CLI 不可跑，需 DevEco 执行） |
| CI 流水线配置 | 🔴 缺失（P2） |
| 前端功能自动化测试 | 🔴 缺失（仅脚手架桩） |
| 后端路由/服务覆盖 ≥ 核心功能 | 🟡 部分（核心有，9 路由/12 服务无） |
| 真机 UI/兼容性/性能测试 | 🔴 缺失（无真机，阻塞） |
| 端到端联调（前端↔后端） | 🔴 缺失（无服务器/域名） |
| 生产 `BASE_URL` 配置 | 🔴 缺失（硬编码 localhost，P3） |
| 隐私/合规（权限声明、华为登录资质） | 🟡 部分（`module.json5` 有 `INTERNET`/`client_id`；AGC 资质未验证） |
| 发布签名材料就绪 | ✅ 已完成（`entry/material` 已生成 `.cer/.p12/.p7b`，`build-profile` 已引用） |
| 回滚预案 | 🟡 部分（草案见 §6，未演练） |

---

## 5. Go/No-Go 初步判断

**初步判断：🔴 NO-GO（当前状态不可直接上架）。**

**必须解决的阻塞项（方可 Go）：**
1. 后端测试套件全绿（P1）—— 当前 RED。
2. 生产 `BASE_URL` 切换（P3）—— 当前 localhost。
3. 至少补齐 CI 或发布前人工门禁（P2）。
4. 前端 release 构建 + code-linter 须在 DevEco 实跑通过（§4 中 🔴 项）。
5. 真机/联调类测试因约束**永久阻塞** → 在「无真机」前提下，以「IDE 构建通过 + 后端 mock 测试全绿 + 静态检查通过 + 人工代码评审」作为替代证据，并在发布说明中明示未做真机验证的风险。

**已知风险（因约束无法闭环，须显式记录并由主理人决策是否接受）：**
- 真机兼容性、性能/功耗、线上联调、灰度监控 4 类测试在上市前无法完成。

---

## 6. 回滚预案（草案）

### 应用侧（鸿蒙 AppGallery）
- **版本标识**：`bundleName=com.bigbluebook.app`，`versionName=1.0.0`，`versionCode=1000000`。
- **回滚手段**：
  1. AppGallery Console **暂停分阶段发布**（停止向新用户灰度推送）。
  2. 重新提交/发布**上一稳定版本包**（保留已通过审核的旧 HAP/APP）。
  3. **紧急下架**（全量回退到不可见）。
- **前置要求**：每次发布保留上一版构建产物与版本号；灰度比例阶梯 `1%→5%→20%→100%`，每阶观察崩溃率/ANR。
- **客户端配置回滚**：`BASE_URL` 等建议经 AGC Remote Configuration 远程下发，避免为改配置而发版回滚。

### 后端侧
- 当前 `docker-compose.yml` **仅含 mysql**，无 app 容器；部署形态未定（本地 node / 云容器）。回滚思路：
  1. **代码回滚**：`git revert` 问题提交 → 重新构建/重启 node 进程（`start.sh`）。
  2. **数据迁移回退**：Prisma migrate 前向-only；回退需 `prisma migrate resolve --rolled-back` 或准备 down migration；重大 schema 变更前务必备份 MySQL（`docker volume bigbluebook_mysql_data`）。
  3. **配置回滚**：`.env`（JWT_SECRET/域名/对象存储）经环境变量管理，回退即改环境变量重启。
  4. **无蓝绿/金丝雀**：当前无多实例编排，建议至少保留「上一进程/镜像」以便快速重启。
- 因「无服务器」约束，后端上线动作本身被阻塞；本预案为「能力就绪后」草案。

---

### 附：已验证事实清单（可核实）
- 后端测试实测：`Test Suites: 4 failed, 14 passed, 18 total；Tests: 8 failed, 126 passed, 134 total；Time 0.8s`（完全离线）。
- 前端测试文件：`entry/src/test/LocalUnit.test.ets`、`List.test.ets`、`entry/src/ohosTest/ets/test/Ability.test.ets`、`List.test.ets` —— 均为 DevEco 脚手架桩。
- 构建证据：`/Users/itxiaobai/HarmonyProject1/.hvigor/report/report-202607261631592870.json` 含 `PreviewBuild`/`assembleHap`；`last-build-info.json` 为 `{"_":["assembleHap"]}`。
- 密钥未入库：`git ls-files backend/.env entry/material` 为空（均被 `.gitignore` 排除）。
- 无 CI：`ls .github` → No such file or directory；无 husky。
