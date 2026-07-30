-- Push Token 表示设备上的推送地址，同一个 token 只能归属一个当前账号。
-- 若历史数据已重复，保留 updatedAt 最新（并以 id 最大兜底）的一条。
DELETE older
FROM PushToken AS older
JOIN PushToken AS newer
  ON older.token = newer.token
 AND (
   older.updatedAt < newer.updatedAt
   OR (older.updatedAt = newer.updatedAt AND older.id < newer.id)
 );

ALTER TABLE PushToken
  DROP INDEX PushToken_userId_token_key,
  ADD UNIQUE INDEX PushToken_token_key (token);
