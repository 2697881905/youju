// 城市路由测试（轻量 in-process HTTP，mock prisma）：覆盖 GET /v1/cities 的
// 白名单全量返回 + 圈子/帖子计数聚合映射 + 无计数城市兜底为 0。
import express from 'express';
import * as http from 'http';
import router from './cities';
import { prisma } from '../prisma';

jest.mock('../prisma', () => ({
  prisma: {
    tag: { groupBy: jest.fn() },
    post: { groupBy: jest.fn() },
  },
}));

describe('GET /v1/cities', () => {
  let server: http.Server;

  beforeAll((done) => {
    const app = express();
    app.use('/v1/cities', router);
    server = app.listen(0, () => done());
  });

  afterAll((done) => {
    server.close(() => done());
  });

  test('返回白名单全量城市并映射计数（缺失计为 0）', async () => {
    (prisma.tag.groupBy as jest.Mock).mockResolvedValue([
      { cityCode: 'bj', _count: { _all: 3 } },
    ]);
    (prisma.post.groupBy as jest.Mock).mockResolvedValue([
      { cityCode: 'bj', _count: { _all: 12 } },
      { cityCode: 'sh', _count: { _all: 5 } },
    ]);
    const res = await fetch(`http://127.0.0.1:${(server.address() as import('net').AddressInfo).port}/v1/cities`);
    const body = (await res.json()) as { code: number; data: Array<{ code: string; name: string; province: string; circleCount: number; postCount: number; lng: number; lat: number }> };
    expect(res.status).toBe(200);
    expect(body.code).toBe(0);
    const list = body.data;
    expect(list.length).toBeGreaterThanOrEqual(30);
    const bj = list.find((c) => c.code === 'bj')!;
    expect(bj.circleCount).toBe(3);
    expect(bj.postCount).toBe(12);
    const sh = list.find((c) => c.code === 'sh')!;
    expect(sh.circleCount).toBe(0); // 无圈子计数兜底 0
    expect(sh.postCount).toBe(5);
    // 每项都带省名/名称/坐标（选城页分组 + 地图 marker 用）
    expect(list[0]).toHaveProperty('name');
    expect(list[0]).toHaveProperty('province');
    expect(typeof list[0].lng).toBe('number');
    expect(typeof list[0].lat).toBe('number');
  });
});
