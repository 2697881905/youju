-- 有据：评论 / 私信 补充 @提及 映射（供展示态精确跳转）
--
-- 背景：帖子正文早已存 post.mentions（[{name, userId}]），展示时点「@昵称」可精确取
-- userId 跳主页；但评论与私信的模型没有该列，前端只能退化为「按昵称全站搜索」，
-- 重名时会跳到错误的人。这里为两者补上同构的列。
--
-- 两列均为 NULL 允许，加列不影响现有行；历史数据保持 NULL，前端遇到 NULL 时继续走
-- 兜底搜索，行为与现在一致。

ALTER TABLE `Comment`
  ADD COLUMN `mentions` JSON NULL;

ALTER TABLE `Message`
  ADD COLUMN `mentions` JSON NULL;
