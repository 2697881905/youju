# 有据（youju）

> 真实经验，有据可循 —— HarmonyOS NEXT 原生的真实体验分享社区。

用户发布结构化体验帖（体裁 + 正文 + 图片 + 标签），标签聚合成「圈子」并以星图呈现，
据友之间通过顶帖、收藏、评论、私信互动，通知与未读徽标统一收敛到消息页。

- 包名：`com.youju.app` ｜ 当前版本：**1.0.3**（versionCode `1000003`）
- 线上接口：`https://api.youju.chat/v1` ｜ 分享落地页：`https://youju.chat`
- 阶段：功能开发已完成，处于上架合规与真机回归收尾期（见 `VERSION.md`）
- 许可：Apache-2.0

## 功能地图

| 入口 | 说明 |
| --- | --- |
| 首页 | 推荐 / 关注 / 每日一帖 三段信息流，瀑布流卡片 + 下拉刷新 + 滚动模糊顶栏 |
| 圈子 | 星图视图：标签即行星，按圈子目录分三环公转；点行星降落逛圈子，点 ✦ 星子直达某一篇具体帖子；全屏宇宙画布 |
| 发布 | 文本帖 / 图片帖两条链路，半模态方式面板 + 标签选择 + 发布预览 |
| 消息 | 通知（赞藏 / 新增关注 / 评论三类快捷筛选）+ 私信双分页，未读徽标与红点同源 |
| 我的 | 资料卡、我发布 / 我收藏 / 我赞过 / 我评论、草稿箱、废纸篓、书签收藏夹、分享主页 |
| 其他 | 帖子详情、搜索结果、他人主页、举报中心（管理端）、账号绑定、拉黑管理、隐私与通知设置 |

页面清单见 `entry/src/main/ets/pages`（47 个 `.ets`），跨页共享状态与设计规范见 `docs/feature-index.md`。

## 技术栈

**客户端**（`entry/`）

- ArkTS + ArkUI，Stage 模型；`targetSdkVersion 26.0.0` / `compatibleSdkVersion 6.0.0(20)`
- 顶栏统一走 `@kit.UIDesignKit` 的 `HdsNavigation`（MINI + `stackBuilder` 品牌行 + `bottomBuilder` 分段行 + GRADIENT_BLUR 滚动模糊）
- 视觉走「沉浸光感」：`uiMaterial.ImmersiveMaterial` 由 `deviceInfo.apiAvailable('26.0.0')` **字面量门禁**保护，门禁不通过的低版本设备自动回退到组件自绘的描边 / 毛玻璃 / 实色底，视觉零破坏
- 设计系统自绘：`design/tokens`（color / type / space / radius / shadow / motion / icon）+ `design/components` + `design/motion`
- 依赖：`@ohos/lottie`；测试：`@ohos/hypium` + `@ohos/hamock`

**服务端**（`backend/`）

- Node.js + Express + TypeScript + Prisma + MySQL，API 版本 `v1`
- JWT 鉴权（华为账号登录；debug 构建另有测试登录桩，release 自动隐藏），腾讯云 COS 存媒体，helmet + express-rate-limit 加固
- 目录：`src/routes` → `src/services` → `prisma/schema.prisma`

## 仓库结构

```
entry/        HarmonyOS 应用（ArkTS：pages / components / design / services / utils / models）
backend/      后端 API（Express + Prisma，含部署与校验脚本）
design/       Logo / 图标源文件与设计规格
docs/         设计文档、迁移方案与踩坑记录（见下方索引）
landing/      分享落地页
site/         官网站点
deliverables/ AGC 提审材料、应用市场文案、截图与复盘
scripts/      工程校验脚本（ArkUI 钩子、登录门禁、海报排版、git doctor 等）
```

## 快速开始

**客户端**

1. DevEco Studio 打开本仓库根目录，等待 `oh-package` 依赖同步；
2. 配置本地签名（`File → Project Structure → Signing Configs`，登录华为账号自动签名）——
   仓库只提交 `build-profile.json5.example`，含密钥的材料不入库；
3. 真机或模拟器运行 `entry`。命令行构建：
   `/Applications/DevEco-Studio.app/Contents/tools/node/bin/node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js --mode project -p product=default assembleApp -p buildMode=debug`。

**后端**

```bash
cd backend
npm install
cp .env.example .env        # 填 MySQL / JWT / COS / 华为账号回调等变量
npx prisma generate && npx prisma db push
npm run dev                 # tsx watch，默认端口 3000
```

**本地联调**：把 `entry/src/main/ets/utils/buildMode.ets` 的 `DEBUG` 改为 `true`（后端指向
`http://127.0.0.1:3000`），并为设备建立端口转发 `hdc -t <设备> rport tcp:3000 tcp:3000`。
⚠️ 上架前务必还原为 `false`。

## 工程约定（踩过的坑都写在这里）

- **提交信息**：Conventional Commits + 中文描述，如 `fix(message): 修复消息页未读红点三处不同步——@Builder 值快照/计数口径/全部已读漏清`。
- **系统材质让位**：`useSystemMaterial` 生效时，组件自绘的背景 / 描边 / 阴影必须归零，否则会叠成第二圈；顶栏共享材质须 `applyShadow: false`（`bottomBuilder` 行 `clip=true` 会把材质投影裁成硬边灰带）。
- **ArkUI 刷新陷阱**：`@Builder` 参数是值快照不刷新（红点「点了不变」首因）；`ForEach` 的 key 生成器必须包含会变化的状态字段；跨组件传逐帧动画参数要用标量而非数组 `@Prop`。
- **凭证边界**：`.env`、`agconnect-services.json`、签名材料、`backend/keys/` 全部在 `.gitignore` 内，仓库只留 `*.example`。

## 文档索引

| 文档 | 内容 |
| --- | --- |
| `docs/feature-index.md` | 功能与设计系统索引（改任何页面前先读） |
| `docs/system_design.md` | 搜索功能系统设计与任务分解（含对 PRD 假设的核实修正） |
| `docs/tutorial-titlebar-immersive-light.md` | 顶栏 + 沉浸光感接入教程（模板库、真实案例集、自查清单） |
| `docs/immersive-light-integration.md` | 沉浸光感接入实践与踩坑记录 |
| `docs/nav-migration-design.md` | 顶栏迁入 `HdsNavigation` 的迁移方案 |
| `docs/huawei_login_design.md` | 华为账号登录链路设计（含时序 / 类图） |
| `docs/智感握姿技术分析.md` | 智感握姿（单手操作）能力调研 |
| `docs/git-worktree-policy.md` | 多 worktree 并行开发约定 |
| `docs/pre-submission-audit.md` | 提审前自查清单 |

## License

Apache License 2.0 —— 详见 [LICENSE](LICENSE)。
