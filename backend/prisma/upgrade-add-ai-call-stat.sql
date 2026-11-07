-- 有据：AI 调用统计表（2026-11-07）
-- 每成功一次 LLM 调用落一行：endpoint×day 聚合即采用率，定位是「先证明 AI 功能有效」的度量地基。
-- 只记成功（拿到真实价值的调用）；管理员调用也落库，查询侧按 ADMIN_USER_IDS 排除。
-- 与配额的内存 Map 区别：本表持久，进程重启/重新部署不丢，跨发布周期可测。
-- 配套 schema.prisma 的 model AiCallStat；回滚用 downgrade-add-ai-call-stat.sql。
CREATE TABLE `AiCallStat` (
  `id` INTEGER NOT NULL AUTO_INCREMENT,
  `endpoint` VARCHAR(32) NOT NULL,
  `day` CHAR(10) NOT NULL,
  `userId` INTEGER NOT NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

  INDEX `AiCallStat_endpoint_day_idx`(`endpoint`, `day`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
