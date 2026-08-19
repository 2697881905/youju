# 「有据」App 上架前最终审查报告

> 审查时间：2026-08-20 01:32 GMT+8
> 审查范围：前端 ArkTS 代码、配置文件、签名、隐私合规、华为登录、资源完整性
> 对照标准：HarmonyOS AGC 上架 Checklist（详见 harmonyos-code-workshop 第 10 章）

---

## 一、审查结论

**整体状态：✅ 已具备上架条件，建议尽快提交。**

发现 1 项 ⚠️ 待补强项（非一票否决）、若干 💡 上架信息填写提醒。无 🔴 阻断性问题。

---

## 二、一票否决项检查（全部通过 ✅）

| 项 | 检查结果 | 证据 |
|----|----------|------|
| APP 备案 | 待用户在 AGC 提审时确认勾选"鸿蒙"平台，包名 `com.youju.app` 已写入 `app.json5` | `AppScope/app.json5:3` |
| 应用名称非泛词 | ✅ "有据" 有识别性，非"免费壁纸/计算器"类广义词 | `AppScope/resources/base/element/string.json` |
| 名称/图标一致性 | ✅ `app_name = "有据"`、`EntryAbility_label = "有据"`、登录页标题"有据"三处一致 | 三处 string.json + LoginPage.ets:46 |
| 签名配置 | ✅ release 签名配置完整（.cer/.p7b/.p12 + SHA256withECDSA） | `build-profile.json5:3-16` |
| 隐私政策弹窗 | ✅ 首次启动拦截 + 版本更新重新弹窗 + 同意才进入 + 不同意退出 App | `Index.ets:218,321-339` |
| 账号注销入口 | ✅ 设置页"账号注销"，两层确认 + 调用 `deactivateAccount()` API + 清理本地 + 跳登录页 | `SettingsPage.ets:62-88,388` |
| 隐私政策链接 | ✅ `privacy-policy.html` 内容完整（生效日期、收集范围、第三方共享、SDK 清单、注销说明、联系方式） | 项目根目录 |
| AIGC 标识 | ✅ 不涉及 — 应用为 UGC 社区，无 AI 文生图/视频生成能力 | 全局 grep 无相关代码 |

---

## 三、关键合规项检查

### 3.1 华为账号登录（Account Kit）✅

- **`module.json5` metadata.client_id** = `6917613566723435312`（与 AGC 应用 App ID 一致）✅
- **`agconnect-services.json`** `oauth_client.client_id = 6917613566723435312`（与 module 一致）✅
- **`agconnect-services.json`** `app_id = 6917613566723435312` ✅
- **登录按钮**：使用官方 `LoginWithHuaweiIDButton` 系统组件，`supportDarkMode: true`（深色模式自动适配）✅
- **登录链路**：`HuaweiLoginButton → authorizationCode → POST /v1/auth/huawei/exchange → 后端真换 token`（全链路已实测）
- **`client_secret` / `api_key`**：在 `agconnect-services.json` 中为加密存储 `[!...]`，DevEco 构建期自动解密，**非明文硬编码** ✅

### 3.2 权限声明克制 ✅

`module.json5:55-62` 仅声明 2 个权限：

| 权限 | 用途 | 验证 |
|------|------|------|
| `ohos.permission.INTERNET` | 网络访问（加载内容/图片/视频） | 隐私政策第 2 章已声明 |
| `ohos.permission.STORE_PERSISTENT_DATA` | `preferences` API 持久化（主题偏好） | `utils/theme.ets` 已使用 |

**未声明**：相册/相机/位置/麦克风/联系人等敏感权限。图片视频选择走 `photoAccessHelper.PhotoViewPicker()` 系统选择器（不直接申请相册权限），与隐私政策第 2 章表述一致 ✅

### 3.3 测试账号说明 ⚠️ 待补强

**现状**：release 包中"其他方式登录"和"虚拟用户·小美 登录"按钮被隐藏（`devLoginVisible = BUILD_MODE !== 'release'`），唯一可见入口为华为账号一键登录。

**风险**：审核员使用自有华为账号可正常登录，无障碍；但若未在 AGC 提审页"审核备注"说明，可能被审核员误判为"必须使用特定账号"。

**建议**：在 AGC 提审页"应用审核信息 → 审核备注"填写：
> 本应用使用华为账号一键登录，请审核员使用您本人的华为账号登录即可体验全部功能，无需额外测试账号。

### 3.4 隐私政策内容完整性 ✅

`privacy-policy.html` 已覆盖：

- ✅ 运营主体：白逸飞
- ✅ 生效日期：2026-08-14
- ✅ 收集信息摘要（账号/资料/内容/设备日志）
- ✅ 设备权限说明（网络 + 持久化存储）
- ✅ 第三方共享：华为 Account Kit、腾讯云 COS
- ✅ 第三方 SDK 清单
- ✅ 账号注销路径（第 6 章）
- ✅ 存储地点：中国境内，无跨境
- ✅ 未成年人保护
- ✅ 联系邮箱：2697881905@qq.com

### 3.5 后端生产地址 ✅

- 前端 release 包 `BASE_URL = https://api.mindtype.cn`（HTTPS）✅
- DNS 已正确解析到生产服务器 `82.156.42.72` ✅
- 旧服务器 `49.235.148.4` 已弃用，前端无残留引用 ✅

---

## 四、构建/打包/版本检查

| 项 | 值 | 结果 |
|----|----|------|
| `bundleName` | `com.youju.app` | ✅ 与 AGC 应用包名一致 |
| `versionCode` | `1000000` | ✅ 整数，首次发版合理 |
| `versionName` | `1.0.0` | ✅ 语义化版本 |
| `targetSdkVersion` | `6.1.1(24)` | ✅ API 24，HarmonyOS 6.1.1 |
| `compatibleSdkVersion` | `6.1.1(24)` | ✅ 与 target 一致 |
| `runtimeOS` | `HarmonyOS` | ✅ |
| `deviceTypes` | `["phone"]` | ✅ 仅声明手机（如需上架平板需补 `tablet`） |
| release 混淆 | `enable: true`，开启顶层/导出符号混淆 + 移除日志 | ✅ |
| 混淆规则文件 | `entry/obfuscation-rules.txt`（合理保留 JSON 字段和路由文件名） | ✅ |

**签名密码**：`build-profile.json5` 中 `keyPassword`/`storePassword` 为加密值（`000000...` 开头的密文），由 DevEco KeyStore 管理工具加密，**非明文硬编码** ✅

---

## 五、资源完整性检查

### 5.1 应用图标 ✅

| 文件 | 尺寸 | 用途 |
|------|------|------|
| `AppScope/resources/base/media/background.png` | 1024×1024 PNG | 分层图背景 |
| `AppScope/resources/base/media/foreground.png` | 1024×1024 PNG | 分层图前景 |
| `AppScope/resources/phone-xxxldpi~sdpi/media/app_icon.png` | 41~216 多密度 | 各密度兜底 |
| `layered_image.json` | 配置正确 | 引用 background + foreground |

> ⚠️ 注意：`background.png` 与 `foreground.png` 字节数完全一致（272454 bytes），说明是同一张图复制了两份。建议后续发新版时区分前景（Logo 主体）和背景（纯色底），目前不影响审核通过。

### 5.2 启动图标

`startWindowIcon: $media:launch_placeholder`（1×1 透明 SVG） — 合规但视觉效果为启动时纯背景色，建议后续优化为应用图标。

### 5.3 深色模式适配 ✅

- `entry/src/main/resources/dark/element/color.json` 完整定义 47 项深色色板
- `HuaweiLoginButton` `supportDarkMode: true` 自动适配
- `EntryAbility.onConfigurationUpdate` 监听系统深色模式切换

### 5.4 多语言资源

- ✅ 中文（base）：默认
- ⚠️ 无 `en_US` 目录 — 若仅上架中国大陆市场可接受；若提交海外市场需补充

---

## 六、代码质量自检

| 项 | 结果 |
|----|------|
| release 包隐藏开发桩 | ✅ `devLoginVisible = BUILD_MODE !== 'release'` 控制 |
| dev 静默登录 | ✅ `validateStartupSession` 中 `BUILD_MODE === 'debug' && msg.includes('登录已过期')` 才走 dev stub，release 不触发 |
| 无 base64 存 DB 反模式 | ✅ 全局 grep 无 `base64` 关键字（DB） |
| 上传走预签名 URL | ✅ `resolveUploadPutUrl(sig)` helper 统一封装 |
| git 状态 | ✅ 干净，最新提交 `8ab0d92` 已 push 到 `origin/main` |
| git remote | ✅ `git@github.com:2697881905/youju.git`（已 rename） |
| ArkTS 严格模式 | ✅ `buildOption.strictMode` 开启 `caseSensitiveCheck` + `useNormalizedOHMUrl` |

---

## 七、💡 AGC 提审信息填写提醒

提交审核时在 AGC 控制台务必确认以下信息：

1. **应用分类**：建议选「社交」或「资讯」（社区内容属性）
2. **审核备注**：填写"使用华为账号一键登录，审核员使用本人华为账号即可"
3. **隐私标签服务**：如实勾选「账号信息」「设备标识」「操作日志」三类，与隐私政策第 1 章一致
4. **应用截图**：至少 3 张真机截图（首页/圈子/详情页等），状态栏不要出现其他 App 通知
5. **分发范围**：中国大陆（如仅国内主体备案）
6. **测试账号**：可留空（华为账号登录无需提供）
7. **版本号**：AGC 显示 `1.0.0 (1000000)` 应与 `app.json5` 一致

---

## 八、已知限制与后续优化建议

| 优先级 | 项 | 说明 |
|--------|----|------|
| 🟡 P1 | 图标分层图同源 | `background.png` 与 `foreground.png` 字节一致，建议区分前景 Logo 主体与背景纯色底，提升视觉识别度 |
| 🟡 P1 | startWindowIcon | 1×1 透明 SVG，启动时仅显示背景色。建议改为应用 Logo |
| 🟢 P2 | 多语言 | 无 `en_US` 资源，仅国内市场可接受 |
| 🟢 P2 | 平板适配 | `deviceTypes: ["phone"]`，未声明支持平板。如未来要适配折叠屏/平板，需补 `tablet` 并做断点布局 |
| 🟢 P2 | mapping 文件保存 | `obfuscation-rules.txt` 中 `-print-namecache` 行未启用，建议发版前启用并保存 mapping 文件，便于线上 crash 反混淆 |

---

## 九、最终结论

**「有据」App 已具备 AGC 上架条件，建议立即提交审核。**

- 🔴 阻断性问题：**0**
- 🟡 待补强项：**1**（审核备注说明华为账号登录）
- 🟢 后续优化项：**5**（图标/startWindowIcon/多语言/平板/mapping）

预计审核时长：首次发版 1-3 工作日。
