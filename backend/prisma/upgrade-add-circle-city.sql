-- 有据：圈子同城维（星图子模式「降落地球」）
-- Tag.cityCode：NULL=全球兴趣圈（现状全部）；有值=同城圈，挂靠 SUPPORTED_CITIES 白名单城市。
-- Post.cityCode：发帖可选城市（同城内容池），本期只落列不改查询。
ALTER TABLE `Tag`
  ADD COLUMN `cityCode` VARCHAR(20) NULL;

ALTER TABLE `Post`
  ADD COLUMN `cityCode` VARCHAR(20) NULL;

-- 城市圈列表查询形态：cityCode 等值 + 活跃度排序。
CREATE INDEX `Tag_cityCode_idx` ON `Tag`(`cityCode`);
