# 「有据」AGC 上架前全面工程审查报告

- 应用：有据 youju · com.youju.app · HarmonyOS NEXT（API 24，ArkTS V1 严格模式）
- 审查方式：静态代码审查 + 生产只读探测（curl/openssl，未改动任何环境）
- 审查时间：2026-08-16 · 审查范围：前端 entry/ · 后端 backend/ · MySQL · COS · 华为 AGC 集成
- 结论：**有条件不通过**。3 阻塞 + 5 高 + 7 中 + 6 低；架构与安全基础扎实，阻塞项均为配置/验证类，1~2 天可闭环。

---

## 1. 执行摘要

| 项 | 结论 |
|---|---|
| 后端生产可用性 | ✅ 已部署，域名/证书/TLS/helmet/CORS 白名单/登录闸门全部实测正常 |
| 核心安全基线 | ✅ 无 IDOR、无 SQL 注入、JWT 强随机、敏感词/举报/拉黑/注销/PIPL 同意齐备 |
| 上架就绪度 | ⚠️ **有条件不通过**：B1 client_id 一致性、B2 release 真机回归、B4 COS 图片 30 天失效 未闭环 |
| 最高优先动作 | ① 同步 App 内隐私政策/用户协议为公开版（H1，驳回点）② 确认 COS 桶 ACL 并补对象删除（B4）③ 真机回归 release 全链路（B2） |

---

## 2. 问题清单

### 🔴 阻塞（必须解决后提交/重新提交）

| ID | 定位 | 影响 | 修复方案 | 优先级 |
|---|---|---|---|---|
| B1 | `entry/src/main/module.json5:52` client_id=`6917613566723435312`；`entry/src/main/resources/rawfile/agconnect-services.json` app_id/oauth_client.client_id=`118624731`（8/13 旧应用）**不一致**；该文件含**明文 client_secret** 且被 git 跟踪 | Account Kit 登录读 module.json5（正常），但 Push Kit/AGC 云服务初始化若读 rawfile 会指向旧应用；凭据入库泄露面；审核一致性风险 | ① 人工核对 AGC 后台当前应用 App ID ② 从 AGC 重新下载与 Release Profile 匹配的 agconnect-services.json 覆盖 ③ rawfile 移除 client_secret（仅留后端 .env）④ 加三处一致性校验 | P0 |
| B2 | `entry/src/main/ets/services/api.ets:11-14` release BASE_URL=`https://api.mindtype.cn` | 生产探测显示后端/COS 配置正常，但 **release 包全链路（华为登录→上传→发布→消费）未真机回归**；hdc rport 逻辑 release 不适用 | 真机安装 release 签名包，回归登录/发布/图片视频/详情/私信全链路；华为登录真机验证 client_id 与签名指纹 | P0 |
| B4 | `backend/src/services/uploadService.ts:65,83` PUT 预签名 600s / GET 预签名 **2592000s(30天)**；viewUrl 落库静态保存；`grep deleteObject` 仅注释无实现；桶预期私有（L74 注释） | 上线 30 天后**全部历史图片 viewUrl 过期 404**；删除/注销后对象残留 COS 最长 30 天可达（PIPL 删除权缺口） | ① 立即确认桶 ACL（公开读则风险降级）② DB 改存 key，viewUrl 后端按需动态签发（短时效）或桶公开/CDN 化 ③ 删帖/注销/举报下架时级联 `deleteObject` | P0 |

### 🟠 高

| ID | 定位 | 影响 | 修复方案 | 优先级 |
|---|---|---|---|---|
| H1 | `PrivacyPage.ets:68`、`UserAgreementPage.ets:76` 占位邮箱 `privacy@youju.com`/`agreement@youju.com`；App 内嵌版为 7/20 陈旧版，缺运营主体/未成年人条款/第三方 SDK 清单 | 公开版（8/14，白逸飞/2697881905@qq.com/SDK 清单齐全）已部署，但审核员**在 App 内打开政策页即见无效邮箱与缺失声明** → 最可能的驳回点 | 将 App 内 PrivacyPage/UserAgreementPage 同步为公开版内容（运营主体、真实邮箱、SDK 清单、未成年人条款），并注明更新日期 | P0 |
| H2 | `backend/src/routes/` 23 处 `(e as Error).message` 直接回显（auth:43/upload:41/push:31/posts:156,243/comments:114,133/dislike×3/privacy×2/block×3/notificationPrefs×2/export:17/messages×5） | 绕过全局 errorHandler 脱敏，触发时泄露 Prisma/DB 表列结构 | 统一改为 `fail(res, CODE.SERVER_ERROR, '服务器开小差了，请稍后重试')`，真实错误仅 console.error | P1 |
| H3 | `utils/share.ets:11-12` SHARE_BASE=`https://youju.app`（TODO(上线)） | 分享链接/分享文案指向不存在的域名 | 域名确定后改一行；若暂不提供分享，隐藏入口 | P1 |
| H4 | `backend/src/app.ts:71` loginLimiter 仅挂 `/v1/auth/login`；`/v1/users/login` 与 `/v1/auth/huawei/exchange` 绕过 | 生产 403 闸门当前挡住 /login 系列，但 `/huawei/exchange` 无闸门无独立限流（仅全局限流 300/15min） | loginLimiter 同时挂 `/v1/users/login` 与 `/v1/auth/huawei/exchange` | P1 |
| H5 | `backend/src/routes/upload.ts:18-21` contentType 仅判 string 无白名单 | 可传 SVG/HTML → 存储型 XSS 面（需登录+预签名，中高） | 加白名单 `image/jpeg|png|webp|gif`、`video/mp4`，与 local 模式 ALLOWED_LOCAL_TYPES 对齐 | P1 |

### 🟡 中

| ID | 定位 | 影响 | 修复方案 | 优先级 |
|---|---|---|---|---|
| M1 | `components/ImagePicker.ets:132` `getUploadSignature('image/jpeg')` 未传 folder → 帖子图片误传 avatars 目录 | 存储归类错误，影响生命周期/清理策略 | 补 `'posts'` folder（与 VideoPicker/textPoster 对齐） | P2 |
| M2 | `pages/Index.ets` HomeTab 无发布完成监听 | 发布后返回首页不自动刷新，新帖需手动下拉 | 发布成功发事件/单例标记，HomeTab onPageShow 或 @Watch 刷新 | P2 |
| M5 | `pages/Index.ets:239-267` 首启隐私弹窗仅「同意/不同意」，无「查看全文」链接 | 用户无法在弹窗内查看政策全文（部分审核要求弹窗含链接） | 弹窗增加跳转 PrivacyPage/UserAgreementPage 的链接按钮 | P2 |
| M6 | `pages/SettingsPage.ets:107-124` 数据导出仅 toast 数量（注释「文件写入后续实现」） | PIPL 数据可携权弱实现 | 后端生成 JSON 导出文件（COS 预签名或临时直链），前端下载 | P2 |
| M7 | `build-profile.json5:41-51` 声明 Push Kit 能力但 `backend/.env` HUAWEI_PUSH_APP_ID/SECRET 为空；公开隐私政策未列推送 SDK | 推送静默不可用；审核问询"已声明能力但未实现" | 二选一：配置推送凭据+隐私政策补充推送说明；或移除 capabilities 声明 | P2 |
| M8 | `components/CircleTab.ets:37-50,201` 硬编码圈子成员数（1280 等）演示数据；强制登录才能浏览 | 演示数据上架观感差；游客无法浏览与「社区」定位冲突 | 接真实统计或移除演示值；去掉强制登录门槛或加游客引导 | P2 |
| M9 | 无测试账号说明文档；软著受理中；`ADMIN_USER_IDS` 生产配置未知（审核台可能无管理员） | 审核需测试账号；内容审核机制缺人工兜底 | AGC 提审备注填写测试说明；生产配置真实 ADMIN_USER_IDS；版权材料用受理通知书/承诺书过渡并提前确认 | P2 |

### 🟢 低

| ID | 定位 | 修复方案 |
|---|---|---|
| L1 | `main_pages.json:27` FoundationPreviewPage（设计预览页）混入 release HAP | 从 main_pages.json 移除 |
| L2 | `VERSION.md:3` 0.1.0 vs app.json5 1.0.0；引用的 `pre-launch-check-youju-2026-07-27.md` 不存在 | 同步版本号与文档引用 |
| L3 | 评论/私信/审核台/废纸篓仅取第一页（DetailPage getPost 全量、ChatPage:81、ModerationPage:109、TrashBoxPage:30） | 补分页 |
| L4 | `agconnect-services.json` 含明文 client_secret 被 git 跟踪；putBinary 4 份重复（ImagePicker:69/VideoPicker:25/EditProfile:247/textPoster:204） | 移除 secret 后入库；收敛 putBinary 为共享 helper |
| L5 | `~/.ohos/config/` 旧签名材料残留；DetailPage 点赞失败文案「请先登录」不准确 | 清理旧材料；改文案 |
| L6 | backend 工作区 **40 个文件未提交**（schema.prisma/posts.ts/postService.ts 等，1360+/496- 行） | 确认生产部署版本与仓库一致性后提交推送（版本漂移风险） |

### 已验证通过（√，不重复检查）
- 生产：域名/证书（Let's Encrypt，SAN 正确，至 2026-10-28）/http→https 301/TLS 强制/helmet 全套头/CORS 白名单生效（非白名单 Origin 不反射）/`/v1/auth/login` 与 `/v1/users/login` 均 403「开放登录已禁用」（NODE_ENV=production 生效）/health 200/公开隐私政策与用户协议已部署（真实邮箱+SDK 清单）
- 安全：JWT 98 字符强随机、30d 过期、IDOR 全查无、无 SQL 注入、敏感词 619 词、举报阈值 3 自动下架、拉黑双向过滤、注销匿名化、PIPL 隐私同意前后端版本一致（1.0.0）、token 硬件加密（Asset Store）、上传统一 resolveUploadPutUrl
- 合规：包名一致、versionCode 1000000/versionName 1.0.0 从未回退、签名 key4 最新 app_gallery Profile（app-identifier 与 client_id 一致）、图标 1024 分层齐全、无 user_grant 权限面（仅 INTERNET + STORE_PERSISTENT_DATA，相册走系统 PhotoViewPicker）

---

## 3. AGC 合规核对表

| 检查项 | 现状 | 证据 | 结论 |
|---|---|---|---|
| 包名 bundleName | com.youju.app | app.json5:3 | ✅ |
| 版本号 versionCode/Name | 1000000 / 1.0.0，未回退 | app.json5:5-6 | ✅（提交前在 AGC 后台核对是否与已提版本冲突） |
| 签名一致性 | key4 最新 app_gallery Release Profile，app-identifier=6917613566723435312 与 client_id 一致 | build-profile.json5:3-17；~/.ohos/config/youju-release-key4-20260815Release.p7b | ✅（Profile 无 device-ids，本地真机调试会 9568332，不影响上架） |
| 权限声明 | 仅 INTERNET + STORE_PERSISTENT_DATA，无 user_grant | module.json5:55-62 | ✅（STORE_PERSISTENT_DATA 建议核实后移除） |
| 隐私政策（公开） | 已部署 api.mindtype.cn/privacy，含运营主体/真实邮箱/SDK 清单/未成年人条款 | 实测 200 | ✅ |
| 隐私政策（App 内） | **7/20 陈旧版，占位邮箱、缺 SDK 清单** | PrivacyPage.ets:68 | ❌ H1（驳回点） |
| 用户协议（App 内） | **陈旧版，占位邮箱** | UserAgreementPage.ets:76 | ❌ H1 |
| 首启隐私弹窗 | 有，同意才继续，不同意退出；已登录落地 PIPL 记录 | Index.ets:239-267 | ✅（缺「查看全文」链接 → M5） |
| 注销入口 | 设置页双层确认，软删匿名化 | SettingsPage.ets:60-87 | ✅ |
| 数据导出 | 仅 toast 数量，未真正导出 | SettingsPage.ets:107-124 | ⚠️ M6 |
| 测试账号 | 无说明文档 | 全仓检索 | ⚠️ M9 |
| 登录方式 | 华为 AccountKit 真实链路；开发桩 release 双门控（BUILD_MODE !== 'release' + throw） | auth.ets:117-135 | ✅ |
| 内容审核 | 敏感词 619 + 举报阈值自动下架 + 管理台（ADMIN_USER_IDS 生产未知） | sensitiveWordService.ts；env.prod.example:42 | ⚠️ M9 |
| 版权/备案 | 软著受理中；建议受理通知书/版权承诺书过渡 | AGC_STORE_COPY.md | ⚠️ M9 |
| 平台约束 | API 24、deviceTypes=phone、图标 1024 分层、名称「有据」一致 | build-profile.json5:22-23 | ✅ |

---

## 4. 全链路功能检查汇总（六层）

| 层 | 关键结论 | 闭环缺口 |
|---|---|---|
| 前端 UI | 27 页面三态（加载/空/错误）齐全，乐观更新+回滚覆盖点赞/收藏/关注/拉黑 | M2 发布后首页不刷新；M8 圈子演示数据；L1 预览页混入 |
| 后端 API | 77 路由，55 需鉴权，越权 IDOR 全查无；幂等（唯一约束） | H2 错误回显；H4 限流绕过；M10 私信/昵称无敏感词 |
| 数据库 | 19 模型，唯一约束/级联齐全，软删；**无 prisma/migrations，靠 db push** | 无迁移版本控制；L6 40 文件未提交（schema 变更无升级脚本） |
| API 层 | 统一响应 {code,data,message}；网络错误映射；http destroy 无泄漏 | H2 22 处绕过全局脱敏 |
| COS 集成 | PUT 600s / GET 30 天预签名；key=folder/yyyy/MM/uuid；凭据仅 .env | **B4 过期失效+无删除**；H5 contentType 无白名单；M1 图片误传 avatars |
| 华为集成 | 登录真链路（exchange→unionID）；client_id 后端一致 | B1 rawfile 旧应用+明文 secret；B2 release 真机未回归；M7 Push 未配置 |

数据流结论：登录→发布→消费主链路代码闭环，未发现断链；风险集中在**配置一致性（B1）与存储生命周期（B4）**，均为上线后可观测但难即时修复的隐患。

---

## 5. 就绪度评估

```
整体：🟡 有条件不通过
  ├─ 阻塞 B1/B2/B4   → 未就绪（P0）
  ├─ 高 H1~H5        → 未就绪（P0/P1）
  ├─ 中 M1~M9        → 部分就绪（P2）
  └─ 基础架构与安全   → ✅ 就绪（实测+静态双验证）
```

- 放行条件（全部满足方可正式提审）：B1 一致性闭环 + B2 真机回归通过 + B4 桶 ACL 确认与删除治理 + H1 App 内政策页同步。
- 预计工作量：1~2 天（配置/文案/验证类为主，无架构返工）。

---

## 6. 事故响应演练报告

### 事故一：B1 client_id 不一致 → 华为登录/AGC 服务指向旧应用（S1/P0）

| 环节 | 内容 | 可验证结果 |
|---|---|---|
| 发现 | 三处 client_id 比对：module.json5=6917613566723435312 ≠ rawfile=118624731；Release Profile app-identifier=6917613566723435312 | `grep -n client_id` 三文件输出齐全，差异明确 |
| 级别 | S1（P0）：登录是唯一入口 + 审核驳回点 | 影响用户=全部 |
| 影响 | 用户：AccountKit 若读 rawfile 则登录/云服务异常；数据：无直接损失；审核：配置不一致易驳回 | 影响面=登录+AGC 服务 |
| 根因 | 8/13 旧应用迁移后 module.json5/Profile 已更新，rawfile 未同步（遗留 118624731），且含明文 secret | 证据链=时间线+三处比对 |
| 修复 | 止血：确认 SDK 读取源，rawfile 强制对齐 6917613566723435312；正式：重下 AGC 配置+rawfile 移除 secret+CI 一致性校验；验证：真机完整登录一次 | 登录 200 + `/v1/auth/me` 可访问 + rawfile 无 secret |
| 复盘 | 预案新增「AGC 配置一致性」S1 检查点；CI 增加三处 client_id 一致性任务 | 登记表落项 |

### 事故二：B4 viewUrl 30 天过期 → 历史图片全量 404（S2/P1）

| 环节 | 内容 | 可验证结果 |
|---|---|---|
| 发现 | uploadService.ts:65,83 预签名 600s/2592000s；viewUrl 落库静态；deleteObject 仅注释 | `grep Expires uploadService.ts` + `grep deleteObject`（0 实现） |
| 级别 | S2（P1）：渐进失效，非即时全量 |
| 影响 | 用户：≥30 天前的帖图/头像/背景 404；数据：对象残留 COS（成本+PIPL 删除权缺口）；审核：删除权实现不完整 | 影响面=存量内容 |
| 根因 | GET 预签名一次性生成落库，过期无重签；删除链路无 deleteObject | 证据链=签名时长+存储路径+删除逻辑 |
| 修复 | 止血：确认桶 ACL（若公开读则不再阻塞）；正式：DB 仅存 key + 后端动态签发（短时效）或公开读/CDN；删除/注销/下架级联 deleteObject；验证：存量 key 新 URL 200 + 删帖后对象消失 | 存量 100% 可达 + 删除闭环生效 |
| 复盘 | 预案新增「存储生命周期」S2 检查点；新特性验收必须含对象删除 | 登记表落项 |

---

## 7. 事故响应预案（可复用）

| 级别 | 定义 | 响应时效 | 角色 |
|---|---|---|---|
| S1/P0 | 全量不可用/登录失效/数据泄露 | 15min 响应 / 30min 止血 | 值班（判级）→ 后端/鸿蒙工程师 → 华为侧接口人 → 负责人（上报） |
| S2/P1 | 部分功能/存量数据渐进失效 | 30min 响应 / 2h 止血 | 同上，降级响应 |
| S3/P2 | 单功能缺陷/体验问题 | 2h 响应 / 当日 | 后端或前端单侧 |
| S4/P3 | 文案/优化 | 正常排期 | — |

应急命令清单（复用 Phase 8 探测/定位命令）+ 上线前风险登记表：登记 B1~B5、H1~H6、M1~M9，字段=ID/级别/触发条件/止损动作/修复指引/责任人/状态。演练记录复用第 6 节模板。

---

## 8. 可复现验证命令清单

```bash
# 生产探测（只读）
curl -sI https://api.mindtype.cn/health                          # 200 + helmet 头
curl -s  https://api.mindtype.cn/health                          # {"ok":true}
echo | openssl s_client -connect api.mindtype.cn:443 -servername api.mindtype.cn 2>/dev/null | openssl x509 -noout -subject -dates -ext subjectAltName
curl -s -i -X OPTIONS https://api.mindtype.cn/v1/posts -H "Origin: https://youju-app.com" -H "Access-Control-Request-Method: GET" | grep -i access-control
curl -s -X POST https://api.mindtype.cn/v1/auth/login -H "Content-Type: application/json" -d '{}'   # 期望 403
curl -sL https://api.mindtype.cn/privacy | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
curl -sI http://api.mindtype.cn/health                            # 期望 301

# 静态定位
grep -n client_id entry/src/main/module.json5 entry/src/main/resources/rawfile/agconnect-services.json
grep -rn "deleteObject" backend/src                                # 期望仅注释
grep -rn "(e as Error).message" backend/src/routes | wc -l         # 23 处
grep -n "loginLimiter" backend/src/app.ts                           # 仅 /v1/auth/login
grep -n "SHARE_BASE" entry/src/main/ets/utils/share.ets
grep -rn "privacy@youju.com\|agreement@youju.com" entry/src/main/ets
git ls-files | grep agconnect-services.json                          # 敏感文件被跟踪
```

---

*附注：本报告仅诊断+方案，未改动任何代码/配置/生产环境。修复实施与重新提审由你决定。*
