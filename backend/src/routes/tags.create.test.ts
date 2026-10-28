// 创建 / 删除圈子链路：与 tags.overview.test.ts 同款轻量 in-process HTTP + mock prisma。
import express from 'express';
import * as http from 'http';
import jwt from 'jsonwebtoken';
import router from './tags';
import { prisma } from '../prisma';
import { env } from '../config/env';
import { sensitiveWordService } from '../services/sensitiveWordService';
import { errorHandler } from '../middleware/errorHandler';

jest.mock('../prisma', () => ({
  prisma: {
    tag: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    userFollowTag: { create: jest.fn(), deleteMany: jest.fn() },
    userTagPref: { deleteMany: jest.fn() },
    userTagRead: { deleteMany: jest.fn() },
    post: { count: jest.fn() },
    user: { findUnique: jest.fn() },
    $transaction: jest.fn(),
  },
}));

interface ApiBody {
  code: number;
  data: { name?: string; creatorId?: number | null } | null;
  message?: string;
}

const USER_ID: number = 7;

function tokenOf(userId: number = USER_ID): string {
  return jwt.sign({ userId }, env.jwtSecret);
}

function postJson(path: string, payload: object, userId: number = USER_ID) {
  return fetch(`${base}${path}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${tokenOf(userId)}`,
    },
    body: JSON.stringify(payload),
  });
}

function deleteReq(path: string, userId: number = USER_ID) {
  return fetch(`${base}${path}`, {
    method: 'DELETE',
    headers: { authorization: `Bearer ${tokenOf(userId)}` },
  });
}

let server: http.Server;
let base: string;

const VALID = { name: '露营装备', category: '兴趣休闲', description: '轻量化露营经验' };

describe('POST /v1/tags 创建圈子', () => {
  beforeAll((done) => {
    const app = express();
    app.use(express.json());
    app.use('/v1/tags', router);
    // service 层抛出的 ValidationError / ForbiddenError / NotFoundError 由全局错误处理映射成 JSON。
    app.use(errorHandler);
    server = app.listen(0, () => {
      base = `http://127.0.0.1:${(server.address() as import('net').AddressInfo).port}`;
      done();
    });
  });

  afterAll((done) => {
    server.close(() => done());
  });

  beforeEach(() => {
    jest.clearAllMocks();
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({ status: 1, deletedAt: null });
    (prisma.tag.findUnique as jest.Mock).mockResolvedValue(null);
    (prisma.tag.create as jest.Mock).mockImplementation(async (args: { data: object }) => ({
      id: 99, useCount: 0, followCount: 0, activeScore: 0, cityCode: null, createdAt: new Date(),
      ...args.data,
    }));
    (prisma.tag.update as jest.Mock).mockResolvedValue({});
    (prisma.userFollowTag.create as jest.Mock).mockResolvedValue({});
    (prisma.$transaction as jest.Mock).mockImplementation(async (arg: unknown) => {
      if (typeof arg === 'function') {
        return (arg as (tx: unknown) => Promise<unknown>)(prisma);
      }
      return Promise.all(arg as Promise<unknown>[]);
    });
  });

  test('成功创建：写入 creatorId，并在同一事务里自动加入', async () => {
    const res = await postJson('/v1/tags', VALID);
    const body = (await res.json()) as ApiBody;

    expect(res.status).toBe(200);
    expect(body.code).toBe(0);
    expect(body.data?.name).toBe('露营装备');
    expect(body.data?.creatorId).toBe(USER_ID);
    expect(prisma.tag.create).toHaveBeenCalledWith({
      data: {
        name: '露营装备',
        category: '兴趣休闲',
        description: '轻量化露营经验',
        emoji: '🌟',
        cityCode: null,
        creatorId: USER_ID,
      },
    });
    expect(prisma.userFollowTag.create).toHaveBeenCalledWith({
      data: { userId: USER_ID, tagName: '露营装备' },
    });
    expect(prisma.tag.update).toHaveBeenCalledWith({
      where: { name: '露营装备' },
      data: { followCount: { increment: 1 } },
    });
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
  });

  test('未登录返回 401', async () => {
    const res = await fetch(`${base}/v1/tags`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(VALID),
    });
    expect(res.status).toBe(401);
  });

  test('重名返回「已有同名圈子」', async () => {
    (prisma.tag.findUnique as jest.Mock).mockResolvedValue({ name: '露营装备' });
    const res = await postJson('/v1/tags', VALID);
    const body = (await res.json()) as ApiBody;
    expect(res.status).toBe(400);
    expect(body.message).toBe('已有同名圈子');
    expect(prisma.tag.create).not.toHaveBeenCalled();
  });

  test('并发重名（P2002）同样映射为「已有同名圈子」', async () => {
    (prisma.$transaction as jest.Mock).mockRejectedValue({ code: 'P2002' });
    const res = await postJson('/v1/tags', VALID);
    const body = (await res.json()) as ApiBody;
    expect(res.status).toBe(400);
    expect(body.message).toBe('已有同名圈子');
  });

  test('名字长度不在 2~8 字内返回 400', async () => {
    const res = await postJson('/v1/tags', { ...VALID, name: '一二三四五六七八九' });
    expect(res.status).toBe(400);
    expect(prisma.tag.create).not.toHaveBeenCalled();
  });

  test('分类不在白名单返回 400', async () => {
    const res = await postJson('/v1/tags', { ...VALID, category: '玄学' });
    expect(res.status).toBe(400);
    expect(prisma.tag.create).not.toHaveBeenCalled();
  });

  test('「同城」分类缺少城市返回 400（防止孤儿圈）', async () => {
    const res = await postJson('/v1/tags', { ...VALID, category: '同城' });
    const body = (await res.json()) as ApiBody;
    expect(res.status).toBe(400);
    expect(body.message).toBe('同城圈子需要指定城市');
  });

  test('简介为空返回 400', async () => {
    const res = await postJson('/v1/tags', { ...VALID, description: '   ' });
    expect(res.status).toBe(400);
    expect(prisma.tag.create).not.toHaveBeenCalled();
  });

  test('命中敏感词返回 400', async () => {
    const spy = jest.spyOn(sensitiveWordService, 'checkText').mockReturnValue(true);
    const res = await postJson('/v1/tags', VALID);
    const body = (await res.json()) as ApiBody;
    expect(res.status).toBe(400);
    expect(body.message).toBe('名称或简介含敏感词');
    spy.mockRestore();
  });
});

describe('DELETE /v1/tags/:name 删除自建圈子', () => {
  beforeAll((done) => {
    const app = express();
    app.use(express.json());
    app.use('/v1/tags', router);
    app.use(errorHandler);
    server = app.listen(0, () => {
      base = `http://127.0.0.1:${(server.address() as import('net').AddressInfo).port}`;
      done();
    });
  });

  afterAll((done) => {
    server.close(() => done());
  });

  beforeEach(() => {
    jest.clearAllMocks();
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({ status: 1, deletedAt: null });
    (prisma.post.count as jest.Mock).mockResolvedValue(0);
    (prisma.userFollowTag.deleteMany as jest.Mock).mockResolvedValue({ count: 1 });
    (prisma.userTagPref.deleteMany as jest.Mock).mockResolvedValue({ count: 0 });
    (prisma.userTagRead.deleteMany as jest.Mock).mockResolvedValue({ count: 1 });
    (prisma.tag.delete as jest.Mock).mockResolvedValue({});
    (prisma.$transaction as jest.Mock).mockImplementation(async (arg: unknown) => {
      if (typeof arg === 'function') {
        return (arg as (tx: unknown) => Promise<unknown>)(prisma);
      }
      return Promise.all(arg as Promise<unknown>[]);
    });
  });

  test('创建者可删除自己的空圈，关联行一并清理', async () => {
    (prisma.tag.findUnique as jest.Mock).mockResolvedValue({ name: '露营装备', creatorId: USER_ID });
    const res = await deleteReq('/v1/tags/' + encodeURIComponent('露营装备'));
    const body = (await res.json()) as ApiBody;

    expect(res.status).toBe(200);
    expect(body.code).toBe(0);
    expect(prisma.userFollowTag.deleteMany).toHaveBeenCalledWith({ where: { tagName: '露营装备' } });
    expect(prisma.userTagPref.deleteMany).toHaveBeenCalledWith({ where: { tagName: '露营装备' } });
    expect(prisma.userTagRead.deleteMany).toHaveBeenCalledWith({ where: { tagName: '露营装备' } });
    expect(prisma.tag.delete).toHaveBeenCalledWith({ where: { name: '露营装备' } });
  });

  test('非创建者返回 403', async () => {
    (prisma.tag.findUnique as jest.Mock).mockResolvedValue({ name: '露营装备', creatorId: 8 });
    const res = await deleteReq('/v1/tags/' + encodeURIComponent('露营装备'));
    const body = (await res.json()) as ApiBody;
    expect(res.status).toBe(403);
    expect(body.message).toBe('仅创建者可以删除该圈子');
    expect(prisma.tag.delete).not.toHaveBeenCalled();
  });

  test('预置圈（creatorId 为 null）不可删除', async () => {
    (prisma.tag.findUnique as jest.Mock).mockResolvedValue({ name: '手机数码', creatorId: null });
    const res = await deleteReq('/v1/tags/' + encodeURIComponent('手机数码'));
    expect(res.status).toBe(403);
    expect(prisma.tag.delete).not.toHaveBeenCalled();
  });

  test('圈子里已有帖子返回 400', async () => {
    (prisma.tag.findUnique as jest.Mock).mockResolvedValue({ name: '露营装备', creatorId: USER_ID });
    (prisma.post.count as jest.Mock).mockResolvedValue(2);
    const res = await deleteReq('/v1/tags/' + encodeURIComponent('露营装备'));
    const body = (await res.json()) as ApiBody;
    expect(res.status).toBe(400);
    expect(body.message).toBe('圈子里已有帖子，不能删除');
    expect(prisma.tag.delete).not.toHaveBeenCalled();
  });

  test('圈子不存在返回 404', async () => {
    (prisma.tag.findUnique as jest.Mock).mockResolvedValue(null);
    const res = await deleteReq('/v1/tags/' + encodeURIComponent('不存在'));
    expect(res.status).toBe(404);
  });
});
