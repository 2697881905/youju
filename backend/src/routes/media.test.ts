import express from 'express';
import * as http from 'http';

const mockHttpsGet = jest.fn();

jest.mock('https', () => ({
  get: mockHttpsGet,
}));

jest.mock('../services/uploadService', () => ({
  isValidMediaKey: (key: string): boolean => key === 'posts/2026/08/ok',
  getCosViewUrl: (key: string): string => 'https://signed.example/' + key,
}));

import mediaRouter from './media';

let server: http.Server;
let baseUrl: string;

beforeAll((done) => {
  const app = express();
  app.use('/v1/media', mediaRouter);
  server = app.listen(0, () => {
    const address = server.address();
    const port = typeof address === 'object' && address ? address.port : 0;
    baseUrl = 'http://127.0.0.1:' + String(port);
    done();
  });
});

afterAll((done) => {
  server.close(() => done());
});

function get(path: string): Promise<{ status: number; type: string | undefined; location: string | undefined }> {
  return new Promise((resolve, reject) => {
    http.get({
      hostname: '127.0.0.1',
      port: Number(new URL(baseUrl).port),
      path,
      headers: { Connection: 'close' },
    }, (res) => {
      res.resume();
      res.on('end', () => resolve({
        status: res.statusCode ?? 0,
        type: res.headers['content-type'],
        location: res.headers.location,
      }));
    }).on('error', reject);
  });
}

describe('GET /v1/media/:key', () => {
  beforeEach(() => {
    mockHttpsGet.mockClear();
    // 默认上游连接失败（快速触发 error 回调）→ 路由应兜底 502 而非 500
    mockHttpsGet.mockReturnValue({
      on: (ev: string, h: () => void): void => {
        if (ev === 'error') {
          setTimeout(h, 10);
        }
      },
    });
  });

  it('有效 key：进入 COS 代理分支，上游异常时兜底 502 而非 500', async () => {
    const result = await get('/v1/media/posts%2F2026%2F08%2Fok');
    expect(result.status).toBe(502);
    expect(mockHttpsGet).toHaveBeenCalled();
  });

  it('未编码多级 key 同样命中（真机 Image 直出路径）', async () => {
    const result = await get('/v1/media/posts/2026/08/ok');
    expect(result.status).toBe(502);
    expect(mockHttpsGet).toHaveBeenCalled();
  });

  it('非法 key 不透露 COS 错误', async () => {
    const result = await get('/v1/media/posts%2F..%2Funsafe');
    expect(result.status).toBe(404);
    expect(mockHttpsGet).not.toHaveBeenCalled();
  });
});