import {
  listCollections, createCollection, updateCollection, deleteCollection,
  getCollection, addPost, removePost,
} from './collectionService';
import { prisma } from '../prisma';

// 合集服务单测：Prisma 全替身，验证增删条目、计数维护与归属校验。
jest.mock('../prisma', () => ({
  prisma: {
    collection: {
      findMany: jest.fn().mockResolvedValue([]),
      findUnique: jest.fn(),
      count: jest.fn().mockResolvedValue(0),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    collectionPost: {
      findMany: jest.fn().mockResolvedValue([]),
      findUnique: jest.fn().mockResolvedValue(null),
      count: jest.fn().mockResolvedValue(0),
      create: jest.fn(),
      deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
    },
    post: { findFirst: jest.fn() },
    $transaction: jest.fn(async (arg: any) => {
      if (typeof arg === 'function') {
        return arg(prisma);
      }
      return Promise.all(arg);
    }),
  },
}));

const mockedFindMany = prisma.collection.findMany as jest.Mock;
const mockedFindUnique = prisma.collection.findUnique as jest.Mock;
const mockedCount = prisma.collection.count as jest.Mock;
const mockedCreate = prisma.collection.create as jest.Mock;
const mockedUpdate = prisma.collection.update as jest.Mock;
const mockedCpFindMany = prisma.collectionPost.findMany as jest.Mock;
const mockedCpFindUnique = prisma.collectionPost.findUnique as jest.Mock;
const mockedCpCount = prisma.collectionPost.count as jest.Mock;
const mockedCpCreate = prisma.collectionPost.create as jest.Mock;
const mockedCpDeleteMany = prisma.collectionPost.deleteMany as jest.Mock;
const mockedPostFindFirst = prisma.post.findFirst as jest.Mock;

describe('collectionService - 基础 CRUD', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedCount.mockResolvedValue(0);
    mockedFindUnique.mockResolvedValue({ id: 1, authorId: 7, title: '连载', postCount: 0 });
    mockedCreate.mockResolvedValue({ id: 1, authorId: 7, title: '连载', description: null });
  });

  it('创建合集：标题/简介规范化落库', async () => {
    const res = await createCollection(7, '  连载  ', '  说明  ');
    expect(mockedCreate).toHaveBeenCalledWith({
      data: { authorId: 7, title: '连载', description: '说明' },
    });
    expect(res.postCount).toBe(0);
  });

  it('创建合集：空标题拒绝', async () => {
    await expect(createCollection(7, '   ', '')).rejects.toThrow('合集标题');
    expect(mockedCreate).not.toHaveBeenCalled();
  });

  it('创建合集：数量上限拒绝', async () => {
    mockedCount.mockResolvedValue(20);
    await expect(createCollection(7, '连载', '')).rejects.toThrow('已达上限');
    expect(mockedCreate).not.toHaveBeenCalled();
  });

  it('编辑/删除：非作者拒绝', async () => {
    mockedFindUnique.mockResolvedValue({ id: 1, authorId: 8, title: '连载', postCount: 0 });
    await expect(updateCollection(7, 1, '新标题', '')).rejects.toThrow('只能编辑自己的合集');
    await expect(deleteCollection(7, 1)).rejects.toThrow('只能编辑自己的合集');
  });

  it('列表：空返回空数组，不查封面', async () => {
    mockedFindMany.mockResolvedValue([]);
    const res = await listCollections(7);
    expect(res).toEqual([]);
    expect(mockedCpFindMany).not.toHaveBeenCalled();
  });

  it('列表：含首帖封面与计数', async () => {
    mockedFindMany.mockResolvedValue([{
      id: 1, authorId: 7, title: '连载', description: null, postCount: 2,
      createdAt: new Date(), updatedAt: new Date(),
    }]);
    mockedCpFindMany.mockResolvedValue([{
      collectionId: 1,
      post: { id: 10, title: '第一篇', images: ['img1'], coverImage: null, genre: 'tutorial' },
    }]);
    const res = await listCollections(7);
    expect(res[0].cover).toEqual({ postId: 10, title: '第一篇', image: 'img1', genre: 'tutorial' });
    expect(res[0].postCount).toBe(2);
  });

  it('详情：分页 + 有序返回', async () => {
    mockedFindUnique.mockResolvedValue({
      id: 1, authorId: 7, title: '连载', description: null, postCount: 1,
    });
    mockedCpFindMany.mockResolvedValue([{
      post: { id: 10, user: { id: 7, nickname: 'u' } },
      addedAt: new Date(),
    }]);
    mockedCpCount.mockResolvedValue(1);
    const res = await getCollection(1, 2, 10);
    expect(res.pagination).toEqual({ page: 2, limit: 10, total: 1 });
    expect(res.list[0].id).toBe(10);
  });
});

describe('collectionService - 加帖/移除', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedFindUnique.mockResolvedValue({ id: 1, authorId: 7, title: '连载', postCount: 0 });
    mockedCpCount.mockResolvedValue(0);
    mockedCpFindUnique.mockResolvedValue(null);
    mockedPostFindFirst.mockResolvedValue({ id: 10 });
    mockedCpCreate.mockResolvedValue({});
    mockedUpdate.mockResolvedValue({});
    mockedCpDeleteMany.mockResolvedValue({ count: 1 });
  });

  it('加帖：合法帖子落库并递增计数', async () => {
    await addPost(7, 1, 10);
    expect(mockedCpCreate).toHaveBeenCalledWith({ data: { collectionId: 1, postId: 10 } });
    expect(mockedUpdate).toHaveBeenCalledWith({
      where: { id: 1 }, data: { postCount: { increment: 1 } },
    });
  });

  it('加帖：帖子非本人/未发布 → 拒绝', async () => {
    mockedPostFindFirst.mockResolvedValue(null);
    await expect(addPost(7, 1, 10)).rejects.toThrow('不属于你');
    expect(mockedCpCreate).not.toHaveBeenCalled();
  });

  it('加帖：帖子已在其他合集 → 拒绝', async () => {
    mockedCpFindUnique.mockResolvedValue({ id: 5, collectionId: 2, postId: 10 });
    await expect(addPost(7, 1, 10)).rejects.toThrow('已加入其他合集');
    expect(mockedCpCreate).not.toHaveBeenCalled();
  });

  it('加帖：单合集条目上限拒绝', async () => {
    mockedCpCount.mockResolvedValue(100);
    await expect(addPost(7, 1, 10)).rejects.toThrow('最多 100 篇');
    expect(mockedCpCreate).not.toHaveBeenCalled();
  });

  it('移除：删条目并递减计数', async () => {
    await removePost(7, 1, 10);
    expect(mockedCpDeleteMany).toHaveBeenCalledWith({ where: { collectionId: 1, postId: 10 } });
    expect(mockedUpdate).toHaveBeenCalledWith({
      where: { id: 1 }, data: { postCount: { decrement: 1 } },
    });
  });

  it('移除：条目不存在时幂等（不动计数）', async () => {
    mockedCpDeleteMany.mockResolvedValue({ count: 0 });
    await removePost(7, 1, 10);
    expect(mockedUpdate).not.toHaveBeenCalled();
  });
});
