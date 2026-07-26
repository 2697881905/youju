# Changelog

## [0.1.0] - 2026-07-27（pre-release / 内测）

### 安全 / 合规
- `GET /v1/auth/me` 改用 Prisma `select` 字段白名单返回，剔除 `openId` / `unionID` 等华为账号标识（PII），避免泄露。
- `PUT /v1/upload/local` 在生产环境（`env.isProduction`）不再挂载，杜绝匿名写盘 / 存储滥用 / DoS；开发期 local 模式上传保留。
- 腾讯云 COS `GET` 预签名有效期由 1 年（31536000s）缩短为 30 天（2592000s），缓解删除 / 注销后图片仍可达的撤回留痕风险。
- 全局错误处理在生产环境对含内部线索（prisma / sql / stack / jwt 等）的 4xx 消息归一化为通用提示，避免泄露实现细节；开发环境仍原样透传便于调试。
- `build-profile.json5` 中 keystore 明文密码移出仓库，改为 `${env.BBB_RELEASE_STORE_PASSWORD}` 环境变量占位，并新增 `.example` 模板。

### 工程 / 发布
- 补充 `VERSION.md` 与 `CHANGELOG.md` 发布文档。
- 补充隐私政策字段的数据库回滚脚本 `backend/prisma/downgrade-add-privacy-consent.sql`。
- `backend/package.json` 的 Prisma 脚本由 `migrate dev` 统一为 `db push`（与项目"禁 migrate dev、用 db push 建表"约定一致）。
