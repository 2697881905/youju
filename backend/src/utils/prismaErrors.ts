// Prisma 错误判定工具。
// P2002 = 唯一约束冲突。幂等写（顶/收藏/关注/拉黑/不喜欢）在并发或重复提交时会命中，
// 业务语义统一是「已存在 → 视为成功」。抽到此处，避免各 service 逐处硬编码错误码字符串。
export function isUniqueViolation(e: unknown): boolean {
  return (e as { code?: string } | null | undefined)?.code === 'P2002';
}
