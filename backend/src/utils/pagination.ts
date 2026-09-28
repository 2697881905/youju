// 分页参数解析工具：把 query 中的任意值归一为安全的正整数。
// 背景：此前各列表路由直接 `Number(req.query.page)`，当传入非数字（如 ?page=abc）会得到
// NaN 并透传给 Prisma 的 skip/take，触发 PrismaClientValidationError → 表现为 500。
// 这里统一兜底为「非有限或 < 1 取默认值，并向 max 收敛」，避免非法入参造成 5xx。
export function parsePage(raw: unknown, def = 1, max = 10000): number {
  const n = Math.floor(Number(raw));
  return Number.isFinite(n) && n >= 1 ? Math.min(n, max) : def;
}

export function parseLimit(raw: unknown, def = 20, max = 50): number {
  const n = Math.floor(Number(raw));
  return Number.isFinite(n) && n >= 1 ? Math.min(n, max) : def;
}
