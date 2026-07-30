-- 回滚只恢复旧约束；升级时被清理的重复归属记录无法恢复。
ALTER TABLE PushToken
  DROP INDEX PushToken_token_key,
  ADD UNIQUE INDEX PushToken_userId_token_key (userId, token);
