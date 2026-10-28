// 圈子总览接口测试：覆盖 scope 过滤参数、匿名/登录两种视图、未读与 digest 聚合。
// 参考 cities.test.ts 的轻量 in-process HTTP + mock prisma 风格。
import express from 'express';
import * as http from 'http';
import jwt from 'jsonwebtoken';
import router from './tags';
import { prisma } from '../prisma';
import { env } from '../config/env';

jest.mock('../prisma', () => ({
  prisma: {
    tag: { findMany: jest.fn() },
    post: { findMany: jest.fn() },
    userFollowTag: { findMany: jest.fn() },
    userTagPref: { findMany: jest.fn() },
    userTagRead: { findMany: jest.fn() },
    user: { findUnique: jest.fn() },
    privacySettings: { findMany: jest.fn().mockResolvedValue([]) },
    blocklist: { findMany: jest.fn().mockResolvedValue([]) },
    follow: { findMany: jest.fn().mockResolvedValue([]) },
  },
}));

interface OverviewItem {
  name: string;
  joined: boolean;
  weight: number;
  unread: number;
  active7d: boolean;
  memberCount: number;
  latestPosts: Array<{ id: number; title: string }>;
}

interface DigestItem {
  postId: number;
  circleName: string;
}

interface OverviewBody {
  code: number;
  data: { circles: OverviewItem[]; digest: DigestItem[] };
  message?: string;
}

const TAGS = [
  {
    id: 1, name: '手机数码', emoji: '📱', category: '消费选购', description: '手机真实体验',
    useCount: 5, followCount: 12, activeScore: 2, cityCode: null, createdAt: new Date(),
  },
  {
    id: 2, name: '装修避坑', emoji: '🏠', category: '动手改造', description: '装修经验',
    useCount: 2, followCount: 6, activeScore: 1, cityCode: null, createdAt: new Date(),
  },
  {
    id: 3, name: '北京同城', emoji: '📍', category: '同城', description: '北京同城圈',
    useCount: 1, followCount: 3, activeScore: 1, cityCode: 'bj', createdAt: new Date(),
  },
];

function post(id: number, title: string, tag: string, minutesAgo: number) {
  return {
    id,
    title,
    upCount: id * 3,
    createdAt: new Date(Date.now() - minutesAgo * 60000),
    tags: [tag],
    user: { nickname: '作者' + id },
  };
}

describe('GET /v1/tags/overview', () => {
  let server: http.Server;
  let base: string;

  beforeAll((done) => {
    const app = express();
    app.use('/v1/tags', router);
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
    (prisma.userFollowTag.findMany as jest.Mock).mockResolvedValue([]);
    (prisma.userTagPref.findMany as jest.Mock).mockResolvedValue([]);
    (prisma.userTagRead.findMany as jest.Mock).mockResolvedValue([]);
    (prisma.post.findMany as jest.Mock).mockResolvedValue([]);
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({ status: 1, deletedAt: null });
  });

  test('匿名 scope=main：排除同城圈，返回圈子聚合与去重 digest', async () => {
    // mock 里刻意混入同城圈，验证 scope=main 在服务层把它过滤掉。
    (prisma.tag.findMany as jest.Mock).mockResolvedValue([TAGS[0], TAGS[1], TAGS[2]]);
    (prisma.post.findMany as jest.Mock).mockResolvedValue([
      post(11, '手机一周体验', '手机数码', 10),
      post(12, '装修踩坑记录', '装修避坑', 60),
      post(13, '手机第二篇', '手机数码', 120),
    ]);

    const res = await fetch(`${base}/v1/tags/overview?scope=main`);
    const body = (await res.json()) as OverviewBody;

    expect(res.status).toBe(200);
    expect(body.code).toBe(0);
    expect(body.data.circles).toHaveLength(2);
    expect(body.data.circles.some((c) => c.name === '北京同城')).toBe(false);
    const phone = body.data.circles.find((c) => c.name === '手机数码')!;
    expect(phone.memberCount).toBe(12);
    expect(phone.joined).toBe(false);
    expect(phone.weight).toBe(2);
    expect(phone.unread).toBe(0); // 匿名不返回用户态
    expect(phone.active7d).toBe(true);
    expect(phone.latestPosts.map((p) => p.id)).toEqual([11, 13]);
    // 同一圈子只进一条 digest
    expect(body.data.digest.map((d) => d.circleName)).toEqual(['手机数码', '装修避坑']);
  });

  test('登录后返回 joined/weight/unread，并优先已加入圈子的 digest', async () => {
    (prisma.tag.findMany as jest.Mock).mockResolvedValue([TAGS[0], TAGS[1]]);
    (prisma.userFollowTag.findMany as jest.Mock).mockResolvedValue([{ tagName: '手机数码' }]);
    (prisma.userTagPref.findMany as jest.Mock).mockResolvedValue([{ tagName: '手机数码', weight: 1 }]);
    (prisma.userTagRead.findMany as jest.Mock).mockResolvedValue([
      { tagName: '手机数码', lastReadAt: new Date(Date.now() - 60 * 60000) },
    ]);
    (prisma.post.findMany as jest.Mock).mockResolvedValue([
      post(21, '装修新帖', '装修避坑', 5),
      post(22, '手机新帖', '手机数码', 15),
      post(23, '手机旧帖', '手机数码', 120),
    ]);

    const token = jwt.sign({ userId: 7 }, env.jwtSecret);
    const res = await fetch(`${base}/v1/tags/overview?scope=main`, {
      headers: { authorization: `Bearer ${token}` },
    });
    const body = (await res.json()) as OverviewBody;

    expect(res.status).toBe(200);
    const phone = body.data.circles.find((c) => c.name === '手机数码')!;
    expect(phone.joined).toBe(true);
    expect(phone.weight).toBe(1);
    expect(phone.unread).toBe(1); // 60 分钟前已读，之后只有 22 一条
    expect(body.data.digest[0].circleName).toBe('手机数码');
  });

  test('scope=main 保留已加入的同城圈（计数与已加入列表一致）', async () => {
    (prisma.tag.findMany as jest.Mock).mockResolvedValue([TAGS[0], TAGS[2]]);
    (prisma.userFollowTag.findMany as jest.Mock).mockResolvedValue([{ tagName: '北京同城' }]);
    const token = jwt.sign({ userId: 8 }, env.jwtSecret);
    const res = await fetch(`${base}/v1/tags/overview?scope=main`, {
      headers: { authorization: `Bearer ${token}` },
    });
    const body = (await res.json()) as OverviewBody;
    expect(res.status).toBe(200);
    const city = body.data.circles.find((c) => c.name === '北京同城');
    expect(city).toBeDefined();
    expect(city!.joined).toBe(true);
  });

  test('scope=city 缺少 cityCode 返回 400', async () => {
    const res = await fetch(`${base}/v1/tags/overview?scope=city`);
    const body = (await res.json()) as OverviewBody;
    expect(res.status).toBe(400);
    expect(body.code).toBe(400);
  });

  test('scope=city 按 cityCode 查询同城圈', async () => {
    (prisma.tag.findMany as jest.Mock).mockResolvedValue([TAGS[2]]);
    const res = await fetch(`${base}/v1/tags/overview?scope=city&cityCode=bj`);
    const body = (await res.json()) as OverviewBody;
    expect(res.status).toBe(200);
    expect(body.data.circles[0].name).toBe('北京同城');
    expect((prisma.tag.findMany as jest.Mock).mock.calls[0][0].where.cityCode).toBe('bj');
  });

  test('name 精确查询单圈（详情页元信息）', async () => {
    (prisma.tag.findMany as jest.Mock).mockResolvedValue([TAGS[2]]);
    const res = await fetch(`${base}/v1/tags/overview?scope=all&name=${encodeURIComponent('北京同城')}`);
    const body = (await res.json()) as OverviewBody;
    expect(res.status).toBe(200);
    expect(body.data.circles[0].name).toBe('北京同城');
    expect((prisma.tag.findMany as jest.Mock).mock.calls[0][0].where.name).toBe('北京同城');
  });
});
