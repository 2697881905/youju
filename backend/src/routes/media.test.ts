import express from 'express';
import * as http from 'http';

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

function get(path: string): Promise<{ status: number; location: string | undefined }> {
  return new Promise((resolve, reject) => {
    http.get(baseUrl + path, (res) => {
      res.resume();
      res.on('end', () => resolve({ status: res.statusCode ?? 0, location: res.headers.location }));
    }).on('error', reject);
  });
}

describe('GET /v1/media/:key', () => {
  it('有效 key 只返回无缓存的短签名重定向', async () => {
    const result = await get('/v1/media/posts%2F2026%2F08%2Fok');
    expect(result.status).toBe(302);
    expect(result.location).toBe('https://signed.example/posts/2026/08/ok');
  });

  it('非法 key 不透露 COS 错误', async () => {
    const result = await get('/v1/media/posts%2F..%2Funsafe');
    expect(result.status).toBe(404);
  });
});
