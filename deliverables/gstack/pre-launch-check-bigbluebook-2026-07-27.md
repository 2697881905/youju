# 大蓝书 上线前综合检查报告

**日期**：2026-07-27
**场景**：上线前检查（产品评审 + 安全审计 + QA测试与发布）
**参与成员**：产品官（gstack-product-reviewer）+ 安全卫士（gstack-security-officer）+ 质量门神（gstack-qa-lead）

---

## 📌 TL;DR（执行摘要）

- 整体结论：🔴 **不通过（No-Go）** —— 功能开发已 100% 就绪，但上线所必须的「外部配置 / 凭证 / 真机验证 / 合规材料」四类条件均缺失。
- 阻塞项数量：**6 个 P0（任一都会导致无法上架或上线后不可用）** + 若干 P1/P2。
- 关键信号：真实华为登录凭证是空占位 → 不补则「真实用户根本登不进 App」；无真机 → 华为上架硬要求无法满足；缺对外隐私政策 URL → 应用市场直接驳回。
- 下一步：先集中火力清掉 6 个 P0（配置 + 借/购真机 + AGC 资质 + 合规 URL），再修 P1，然后走 DevEco release 构建 + 真机走通。

---

## 🎯 核心结论卡片

| 项目 | 内容 |
|------|------|
| Go / No-Go | 🔴 **No-Go**（6 个 P0 阻塞上架） |
| 严重度分布 | 🔴 6 / 🟠 7 / 🟡 6 |
| 关键行动项 | P0 × 6（必做）+ P1 × 7（上线前）+ P2 × 6（迭代） |
| 建议负责人 | 后端/DevOps（配置+部署）、产品（合规材料+真机借用）、测试（真机走通） |

---

## 1. 各成员核心结论

### 🔍 产品官（产品评审）
- **核心判断**：功能层已就绪——发帖、信息流、详情、评论、点赞、关注、个人主页、搜索、消息/通知 10 项核心能力全部实读代码确认可用；隐私政策、用户协议、设置/关于入口、首启隐私同意流均已落地（PIPL 可追溯）。**阻塞 100% 在外部事项，不在写代码。**
- **关键建议**：① 填真实华为 Account Kit 凭证接通登录（否则无人能登）；② 借/购真机做端到端验证；③ 配置 production 后端环境（NODE_ENV/CORS/DATABASE_URL）；④ 推进华为应用市场资质审核（软著/ICP/隐私备案）。

### 🛡️ 安全卫士（OWASP+STRIDE 审计）
- **核心判断**：IDOR / PII / 越权 / 鉴权中间件整体闭环，无 🔴 硬阻塞；OWASP Top 10 中 A01-A10 大多已缓解。**但有 3 个 🟠 P1 建议上架前修**，最关键的是生产环境 `PUT /v1/upload/local` 匿名可达（无 auth），存在存储滥用/DoS 风险。
- **关键建议**：生产不挂载 `/upload/local` 或加 auth；`GET /v1/auth/me` 剔除 openId/unionID；COS GET 预签名有效期从 1 年缩短或改为按需签发。

### ✅ 质量门神（QA测试与发布）
- **核心判断**：后端 `npm run build` + `npm test` **实测通过**（tsc 退出 0，jest 134 用例全绿）；前端仅做配置完整性审查（本机无 DevEco，**未真实编译**）。发布就绪度偏弱：P0 缺对外隐私政策 URL、**AGC 签名材料经核实为测试/自签占位（须换 AGC 正式）**、华为凭据还是 2 字符占位、ADMIN_USER_IDS 缺失（无审核管理员）；测试覆盖后端部分/前端几乎无；无回滚迁移、无发布文档。
- **关键建议**：补对外托管的隐私政策 URL；到 AGC 控制台核对签名真实性；DevEco 跑一次 release 构建 + 真机安装；清理 build-profile.json5 里明文 keystore 密码。

---

## 2. 综合审查发现（去重合并后按严重度排序）

### 威胁建模 (STRIDE) + OWASP Top 10 检查表（安全官核心结论）
- **STRIDE**：S 假冒🟢 / T 篡改🟢 / R 抵赖🟡(无审计日志) / I 信息泄露🟠(openId 泄露+COS 1年签名+4xx透传) / D 拒绝服务🟠(/upload/local 匿名) / E 越权🟢。
- **OWASP Top 10**：A01 失效访问控制🟠(仅 /upload/local) / A02 加密🟢 / A03 注入🟢 / A05 配置🟢 / A06 组件🟡(未跑 audit) / A07 认证🟢 / A09 日志🟡 / 其余🟢。

| # | 严重度 | 类别 | 位置 | 问题描述 | 建议 | 来源成员 |
|---|--------|------|------|---------|------|---------|
| 1 | 🔴 | 配置/登录 | backend/.env | HUAWEI_CLIENT_ID/SECRET/REDIRECT_URI 为 2 字符占位，release 已隐藏 dev stub → 真实用户无法登录 | 填真实 AGC Account Kit 凭证 | 产品官+质量门神 |
| 2 | 🔴 | 合规 | 无文件/无链接 | 缺对外托管的隐私政策 URL（华为应用市场强制要求） | 托管并填入 AppGallery | 质量门神 |
| 3 | 🔴 | 签名/上架 | entry/material/*.cer/.p7b | AGC 签名材料经复核确认为**测试/自签占位**（.gitignore 注释明示"由 AGC 正式材料替换"），自签必被拒，华为市场只接受 AGC 签发证书+描述文件 | 提交前必须用 AGC 正式 .cer+.p7b 替换并核对包名/指纹一致 | 质量门神+安全官 |
| 4 | 🔴 | 测试 | 无真机 | 真机端到端验证缺失（Account Kit 登录/推送/COS 直传/UI 真机表现均未验证）——华为上架硬要求 | 借/购真机走通核心链路 | 产品官+质量门神 |
| 5 | 🔴 | 配置/生产 | backend/.env | 无 NODE_ENV=production（安全闸口不生效）、无 CORS_ORIGIN、DATABASE_URL 为 localhost、无 ADMIN_USER_IDS、COS_CDN_BASE 占位 | 配置 production 后端环境 | 产品官+质量门神 |
| 6 | 🔴 | 合规/安全 | app.ts 加载 sensitive-words.txt | 敏感词库落地存疑 → 内容无过滤，合规风险 | 确认词库落地或明确降级策略 | 产品官+安全官 |
| 7 | 🟠 | 安全/DoS | backend upload.ts:41-65 | `PUT /v1/upload/local` 生产缺 auth，仅校验 key 格式 → 匿名写盘/存储滥用/DoS | 生产 `if(!isProduction)` 不挂载或加 auth | 安全官 |
| 8 | 🟠 | 隐私/PII | backend auth.ts:48-60 | `GET /v1/auth/me` 用 `...user` 把 openId/unionID（PII）返回客户端 | 返回最小字段集 {id,nickname,avatar,bio,gender,...} | 安全官 |
| 9 | 🟠 | 隐私 | backend uploadService.ts:79 | COS GET 预签名有效期 1 年，`viewUrl` 入库 → 删除/注销后图片仍可达最长 1 年 | 缩短有效期或按需签名 | 安全官 |
| 10 | 🟠 | 密钥管理 | 根 build-profile.json5:10,14 | keystore **密码明文存于仓库**（entry/material 密钥文件本身被 gitignore 未泄露，仅密码串泄露）；若替换为真实 AGC keystore 则密码视作已暴露须轮换 | 移出 VCS / 外部化；换正式 keystore 时同步轮换密码 | 质量门神 |
| 11 | 🟠 | 发布 | 无 | release 包未在本机真实产出，仅配置审查 | DevEco 跑 release 构建 + 真机安装验证 | 质量门神 |
| 12 | 🟠 | 运维 | upgrade-*.sql | DB 变更无 down 迁移，仅手写 upgrade | 为每次 schema 变更补回滚 SQL | 质量门神 |
| 13 | 🟡 | 测试 | 后端 10+ 模块 / 前端 | upload/push/search/tags/messages/interact 无测试；前端仅脚手架样板 | 补后端关键链路测试 + 前端业务测试 | 质量门神 |
| 14 | 🟡 | 发布文档 | 无 | 缺 VERSION / CHANGELOG.md | 补发布文档 | 质量门神 |
| 15 | 🟡 | 体验 | DetailPage / SettingsPage | 系统分享仅占位 toast、数据导出仅 toast 数量（PIPL「数据副本」不完整） | 补全或明确降级说明 | 产品官 |
| 16 | 🟡 | 推送 | backend/.env | HUAWEI_PUSH_APP_ID/SECRET 为空 → 真机推送降级 | 配真实凭据或明确降级 | 产品官+质量门神 |
| 17 | 🟡 | 合规 | privacy/agreement 邮箱 | 联系邮箱需真实可收（privacy@/agreement@bigbluebook.com） | 配置真实邮箱 | 产品官 |
| 18 | 🟡 | 安全日志 | errorHandler.ts:41 | 4xx 透传 err.message，个别异常或泄露内部细节 | 统一脱敏 | 安全官 |
| 19 | 🟡 | 依赖 | package.json | 未跑 npm audit（CVE 状态未知） | CI 加入 audit | 安全官 |

---

## 🚫 阻塞项清单（P0 —— 任一未解即无法上架/上线即故障）

1. **真实华为登录凭证缺失**（backend/.env）→ 真实用户无法登录。
2. **缺对外托管隐私政策 URL** → 华为应用市场直接驳回。
3. **AGC 签名材料为测试/自签占位（非 AGC 签发）** → 必须替换为 AGC 正式 .cer+.p7b 并核对包名 `com.bigbluebook.app` / 指纹一致，否则上架必被拒。
4. **真机端到端验证缺失**（无真机）→ 华为上架硬要求未满足。
5. **生产后端环境未配置**（NODE_ENV/CORS/DATABASE_URL/ADMIN_USER_IDS/COS_CDN_BASE）→ 生产安全闸口不生效、图片异常、无审核管理员。
6. **内容过滤敏感词库落地存疑** → 内容无过滤，合规风险。

---

## ✅ 行动清单（至少 3 条具体可执行项）

| # | 行动 | 负责方 | 紧急度 | 期望完成 |
|---|------|--------|--------|---------|
| 1 | 在 backend/.env 填真实 AGC Account Kit 凭证（CLIENT_ID/SECRET/REDIRECT_URI），并确认 module.json5 client_id 与 AGC 一致 | 后端 | P0 | 上架前 |
| 2 | 托管对外隐私政策 + 用户协议 URL，填入 AppGallery 上架资料 | 产品+后端 | P0 | 上架前 |
| 3 | 用 AGC 正式 .cer+.p7b **替换** entry/material/ 测试签名材料（勿入库），并核对包名 `com.bigbluebook.app` 与注册指纹一致、Account Kit 已开通 | DevOps/产品 | P0 | 上架前 |
| 4 | 借/购真机，端到端走通：华为登录→发帖→图片上传→推送→核心 UI | 测试+产品 | P0 | 上架前 |
| 5 | 配置 production 后端环境（NODE_ENV=production / CORS_ORIGIN / DATABASE_URL / ADMIN_USER_IDS / COS_CDN_BASE） | 后端 | P0 | 上架前 |
| 6 | 确认 sensitive-words.txt 已落地，否则补充词库或显式降级 | 后端 | P0 | 上架前 |
| 7 | 生产不挂载 `PUT /v1/upload/local` 或加 auth；`/auth/me` 剔除 openId/unionID | 后端 | P1 | 上架前 |
| 8 | 清理 build-profile.json5 明文 keystore 密码，移出 VCS | 后端 | P1 | 上架前 |
| 9 | DevEco 跑一次 release 构建 + 真机安装验证；补 DB down 迁移 + VERSION/CHANGELOG | 测试+后端 | P1 | 上架前 |
| 10 | 补后端 upload/push/search/messages 测试 + 前端业务测试；CI 加 npm audit 与前端构建 | 测试+后端 | P2 | 迭代期 |

---

## 🔄 回滚预案（上线前检查强制项）

- **数据库**：当前仅靠手写 `upgrade-*.sql`，**无 down 迁移**。须为每次 schema 变更补对应回滚 SQL（开发负责，随 PR 提交）。
- **后端**：版本回滚靠「重新部署旧版」（无镜像 tag pin / 回滚脚本）。建议上架前加部署版本 pin + 一键回滚脚本。
- **前端**：无热修能力，只能重新上架。保留上一个稳定 HAP，发现问题即重新提交审核版本。
- **签名**：AGC 签名一旦生效，回退需重新走审核流程。故上架前必须在真机本地充分验证，避免反复提交。

---

## ⚠️ 待完善 / 已知局限

- 前端 release 包**未在本机真实编译**（环境无 DevEco/hvigor），仅做配置完整性审查。
- 安全官 A06 CVE 状态、生产是否真配 COS 无法本机核实（列为推断项）。
- 真机行为、AGC Account Kit 是否真开通、证书指纹是否登记、敏感词库是否落地，均无法本机验证。
- 经安全官 + QA 交叉核实：AGC 签名材料确认为**测试/自签占位**（非 AGC 签发，.gitignore 注释明示"由 AGC 正式材料替换"）；原 QA 提出的"权限声明缺口"为**误报已移除**——module.json5 仅 INTERNET 权限，正确且充分。
- dev stub 已用 `BUILD_MODE==='release'` 门控（release 包隐藏且调用即抛错），满足「不依赖 dev stub 作登录入口」的硬要求；真实 AccountKit 代码路径已正确接入。

---

## 📚 成员产出索引

- gstack-product-reviewer（产品官）原始产出：核心功能状态表（10 项全实读确认）+ 合规物料检查 + P0×4 / P1×5 / P2 清单 + 诚实标注（见本回合回传消息）。
- gstack-security-officer（安全卫士）原始产出：IDOR 复查表 + PII 暴露分析 + 鉴权覆盖 + STRIDE + OWASP Top 10 检查表 + P1×3 / P2×2（见本回合回传消息）。
- gstack-qa-lead（质量门神）原始产出：`npm run build`/`npm test` 实测结果 + 测试覆盖分析 + 发布就绪度 + 真机缺口 6 项 + P0×3 / P1×6 / P2×4（见本回合回传消息）。

---

> 本报告由软件工坊 AI 协作生成，关键决策请由工程负责人复核。
