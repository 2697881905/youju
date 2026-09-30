import express from 'express';
import * as http from 'http';

const mockHttpsGet = jest.fn();

jest.mock('https', () => ({
  get: mockHttpsGet,
}));

jest.mock('../services/uploadService', () => ({
  isValidMediaKey: (key: string): boolean => key === 'posts/2026/08/ok' || key === 'video/2026/08/ok',
  getCosViewUrl: (key: string): string => 'https://signed.example/' + key,
  getCosPlayUrl: (key: string): string => 'https://signed.example/' + key + '?play=1',
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

// 读取 JSON 响应体（/v1/media/sign 用）
function getJson(path: string): Promise<{ status: number; body: any }> {
  return new Promise((resolve, reject) => {
    http.get({
      hostname: '127.0.0.1',
      port: Number(new URL(baseUrl).port),
      path,
      headers: { Connection: 'close' },
    }, (res) => {
      let raw = '';
      res.on('data', (chunk) => { raw += String(chunk); });
      res.on('end', () => {
        let body: any = null;
        try {
          body = raw.length > 0 ? JSON.parse(raw) : null;
        } catch (e) {
          body = null;
        }
        resolve({ status: res.statusCode ?? 0, body });
      });
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

describe('GET /v1/media/sign', () => {
  beforeEach(() => {
    mockHttpsGet.mockClear();
  });

  it('有效视频 key：返回直读签名 URL（不经过字节流代理）', async () => {
    const result = await getJson('/v1/media/sign?key=video%2F2026%2F08%2Fok');
    expect(result.status).toBe(200);
    expect(result.body.code).toBe(0);
    expect(result.body.data.url).toContain('signed.example/video/2026/08/ok');
    expect(mockHttpsGet).not.toHaveBeenCalled();
  });

  it('非法 key：404 且不透传 COS 错误', async () => {
    const result = await getJson('/v1/media/sign?key=video%2F..%2Funsafe');
    expect(result.status).toBe(404);
    expect(result.body.code).toBe(404);
  });

  it('缺 key：404', async () => {
    const result = await getJson('/v1/media/sign');
    expect(result.status).toBe(404);
  });
});