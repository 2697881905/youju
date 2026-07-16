import { prisma } from '../prisma';

// 获取所有标签（按使用次数降序）
export async function listTags() {
  return prisma.tag.findMany({ orderBy: { useCount: 'desc' } });
}
