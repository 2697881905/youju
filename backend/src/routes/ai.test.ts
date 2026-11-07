// AI 辅助创作路由/服务测试。真实 HTTP + JWT + mock fetch + mock sensitiveWordService，
// 与 comments.test.ts 的 mock 风格一致；不依赖真实 LLM 上游。
process.env.NODE_ENV = 'test';

jest.mock('../services/sensitiveWordService', () => ({
  sensitiveWordService: {
    checkText: jest.fn(),
    isLoaded: jest.fn().mockReturnValue(true),
  },
}));

// auth 中间件在鉴权后会查一次 user（注销/封禁校验），必须 mock，否则真实 Prisma
// 因无 DATABASE_URL 抛错 → 被 auth 自己的 catch 转成 500「鉴权失败」。
// aiCallStat/tag：recordAiCall 与 suggest-tags/search-rescue 的落库、白名单查询走 mock。
jest.mock('../prisma', () => ({
  prisma: {
    user: { findUnique: jest.fn() },
    aiCallStat: { create: jest.fn().mockResolvedValue({}) },
    tag: { findMany: jest.fn().mockResolvedValue([]) },
  },
}));

import express from 'express';
import http from 'http';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { prisma } from '../prisma';
import aiRouter from './ai';
import { errorHandler } from '../middleware/errorHandler';
import { sensitiveWordService } from '../services/sensitiveWordService';

const mockPrisma = prisma as any;

const mockCheckText = sensitiveWordService.checkText as jest.Mock;

const TEST_USER_ID = 1;

function authHeader(userId: number = TEST_USER_ID): Record<string, string> {
  const token: string = jwt.sign({ userId }, env.jwtSecret);
  return { Authorization: 'Bearer ' + token };
}

let server: http.Server;
let baseUrl: string;

beforeAll((done) => {
  // 注入测试凭证：aiEnabled() 依赖 env.ai 三项；测试不发真实请求（fetch 被替换）。
  // jwtSecret 同理：worktree 无 backend/.env，env.jwtSecret 为空会让 sign/verify 直接抛错。
  env.jwtSecret = 'test-secret';
  env.ai.apiBase = 'https://ai.test/v1';
  env.ai.apiKey = 'test-key';
  env.ai.model = 'test-model';
  const app = express();
  app.use(express.json());
  app.use('/v1/ai', aiRouter);
  // 必须挂全局 errorHandler：业务错误（ValidationError/SensitiveWordError/AiUnavailableError）
  // 经 asyncHandler 抛出后由它转成 JSON 响应，否则 express 默认 finalhandler 回 HTML
  app.use(errorHandler);
  server = app.listen(0, () => {
    const addr = server.address();
    const port = typeof addr === 'object' && addr ? addr.port : 0;
    baseUrl = `http://127.0.0.1:${port}`;
    done();
  });
});

afterAll((done) => {
  server.close(() => done());
});

beforeEach(() => {
  jest.clearAllMocks();
  mockPrisma.user.findUnique.mockResolvedValue({ deletedAt: null, status: 1 });
  mockCheckText.mockReturnValue(false);
});

function req(
  method: string,
  path: string,
  body?: unknown,
  headers: Record<string, string> = {}
): Promise<{ status: number; json: any }> {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : undefined;
    const reqHeaders: Record<string, string> = { 'Content-Type': 'application/json', ...headers };
    const r = http.request(
      `${baseUrl}${path}`,
      { method, headers: reqHeaders },
      (res) => {
        let raw = '';
        res.on('data', (chunk) => (raw += chunk));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode ?? 0, json: raw ? JSON.parse(raw) : null });
          } catch {
            resolve({ status: res.statusCode ?? 0, json: null });
          }
        });
      }
    );
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

// mock 一个 OpenAI 兼容的 chat completions 响应
function mockChatContent(content: string): void {
  (globalThis as any).fetch = jest.fn().mockResolvedValue({
    ok: true,
    status: 200,
    json: async () => ({ choices: [{ message: { content } }] }),
  });
}

describe('GET /v1/ai/status', () => {
  it('凭证齐全 → enabled:true；清空凭证 → enabled:false', async () => {
    const enabled = await req('GET', '/v1/ai/status');
    expect(enabled.status).toBe(200);
    expect(enabled.json.data.enabled).toBe(true);

    const saved = env.ai.apiKey;
    env.ai.apiKey = '';
    const disabled = await req('GET', '/v1/ai/status');
    expect(disabled.json.data.enabled).toBe(false);
    env.ai.apiKey = saved;
  });
});

describe('POST /v1/ai/polish-draft', () => {
  const LONG_BODY = '这三周我每天记录这台手机的亮屏时间，平均 8.4 小时，超出官方标称；缺点是 20W 充电回血慢，出门必须带充电宝，体验上有明显取舍。';

  it('缺 Authorization → 401', async () => {
    const res = await req('POST', '/v1/ai/polish-draft', { title: 't', content: '正文内容' });
    expect(res.status).toBe(401);
  });

  it('正文为空 → 400', async () => {
    const res = await req('POST', '/v1/ai/polish-draft', { title: 't', content: '   ' }, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.message).toContain('先写点正文');
  });

  it('happy path → 200 + 标题与正文都返回', async () => {
    mockChatContent('{"title":"续航实测：8.4 小时亮屏","content":"三周实测亮屏平均 8.4 小时，超出官方标称；20W 充电回血偏慢，出门需带充电宝。"}');
    const res = await req('POST', '/v1/ai/polish-draft', { title: '随便写写', content: LONG_BODY, genre: 'review', maxContent: 5000 }, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.data.title).toBe('续航实测：8.4 小时亮屏');
    expect(res.json.data.content.length).toBeGreaterThan(0);
  });

  it('maxContent 上限生效：超长润色结果被钳制', async () => {
    const longPolished = '很'.repeat(600);
    mockChatContent(JSON.stringify({ title: '好标题', content: longPolished }));
    const res = await req('POST', '/v1/ai/polish-draft', { title: 't', content: LONG_BODY, maxContent: 300 }, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.data.content.length).toBeLessThanOrEqual(300);
  });

  it('润色结果过短（低于原文 30%）→ 503', async () => {
    mockChatContent('{"title":"短","content":"太短了"}');
    const res = await req('POST', '/v1/ai/polish-draft', { title: 't', content: LONG_BODY }, authHeader());
    expect(res.status).toBe(503);
    expect(res.json.message).toContain('过短');
  });

  it('上游非法 JSON → 503', async () => {
    mockChatContent('我做不到');
    const res = await req('POST', '/v1/ai/polish-draft', { title: 't', content: LONG_BODY }, authHeader());
    expect(res.status).toBe(503);
  });

  it('润色内容命中敏感词 → 400', async () => {
    mockChatContent('{"title":"好标题","content":"这句含违禁词。这句含违禁词。这句含违禁词。这句含违禁词。这句含违禁词。"}');
    mockCheckText.mockReturnValue(true);
    const res = await req('POST', '/v1/ai/polish-draft', { title: 't', content: LONG_BODY }, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.message).toContain('安全检查');
  });
});

describe('POST /v1/ai/structure-draft', () => {
  it('正文太短 → 400', async () => {
    const res = await req('POST', '/v1/ai/structure-draft', { content: '太短了', genre: 'review' }, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.message).toContain('正文太短');
  });

  it('happy path：过滤已退役的 metric 与未知类型，主视觉指向 insight，响应带推断体裁与骨架', async () => {
    mockChatContent(JSON.stringify({
      genre: 'review',
      blocks: [
        { type: 'insight', value: '续航是最大惊喜' },
        { type: 'metric', value: '4.8', unit: '分' },
        { type: 'mystery', value: '未知类型应被丢弃' },
        { type: 'compare', leftLabel: '优点', leftValue: '亮屏久', rightLabel: '缺点', rightValue: '充电慢' },
      ],
    }));
    const res = await req('POST', '/v1/ai/structure-draft', {
      content: '这三周我每天记录这台手机的亮屏时间，平均 8.4 小时，超出官方标称；缺点是 20W 充电回血慢。',
      genre: 'review',
    }, authHeader());
    expect(res.status).toBe(200);
    const document = res.json.data.document;
    expect(document.schemaVersion).toBe(3);
    expect(document.theme).toBe('editorial');
    expect(document.blocks).toHaveLength(2);
    expect(document.blocks[0].type).toBe('insight');
    expect(document.blocks[0].id).toBe(document.primaryBlockId);
    expect(document.blocks[1].type).toBe('compare');
    // id 由服务端重生成，杜绝模型伪造
    expect(document.blocks[0].id).toMatch(/^ai_\d+_\d+$/);
    expect(res.json.data.genre).toBe('review');
    expect(res.json.data.template).toBe('review_score');
  });

  it('作者未传 genre：LLM 推断体裁生效，模板按推断体裁回表', async () => {
    mockChatContent(JSON.stringify({
      genre: 'tutorial',
      blocks: [
        { type: 'steps', items: ['下载固件', '刷入系统'] },
        { type: 'insight', value: '先备份再动手' },
      ],
    }));
    const res = await req('POST', '/v1/ai/structure-draft', {
      content: '给旧手机刷轻量系统前先备份数据，下载对应固件，然后进入开发者模式逐步操作。',
    }, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.data.genre).toBe('tutorial');
    expect(res.json.data.template).toBe('tutorial_path');
    expect(res.json.data.document.blocks).toHaveLength(2);
  });

  it('模型返回未知 genre → 回退作者标记的体裁，块类型按回退体裁过滤', async () => {
    mockChatContent(JSON.stringify({
      genre: 'essay',
      blocks: [
        { type: 'insight', value: '结论有效' },
        { type: 'steps', items: ['步骤不该出现在 review'] },
      ],
    }));
    const res = await req('POST', '/v1/ai/structure-draft', {
      content: '这段正文足够长，用来验证未知体裁回退到作者标记体裁后的块类型过滤逻辑。',
      genre: 'review',
    }, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.data.genre).toBe('review');
    // steps 不在 review 的可用类型里 → 被丢弃
    expect(res.json.data.document.blocks).toHaveLength(1);
    expect(res.json.data.document.blocks[0].type).toBe('insight');
  });

  it('AI 返回空 blocks → 503 + 可理解文案', async () => {
    mockChatContent('{"genre":"review","blocks":[]}');
    const res = await req('POST', '/v1/ai/structure-draft', {
      content: '这段正文足够长，但是模型返回了空的块列表，服务应当给出可理解的失败提示。',
      genre: 'review',
    }, authHeader());
    expect(res.status).toBe(503);
    expect(res.json.message).toContain('没能从正文整理出信息块');
  });

  it('整理结果命中敏感词 → 400（AI 输出不豁免）', async () => {
    mockChatContent('{"genre":"review","blocks":[{"type":"insight","value":"含违禁词的结论"}]}');
    mockCheckText.mockReturnValue(true);
    const res = await req('POST', '/v1/ai/structure-draft', {
      content: '这段正文足够长，用来通过最短长度检查，内容本身并不重要。',
      genre: 'review',
    }, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.message).toContain('安全检查');
  });
});

describe('POST /v1/ai/suggest-tags', () => {
  const LONG_BODY = '这三周我每天记录这台手机的亮屏时间，平均 8.4 小时，超出官方标称，充电回血慢是明显短板。';

  it('缺 Authorization → 401', async () => {
    const res = await req('POST', '/v1/ai/suggest-tags', { content: LONG_BODY });
    expect(res.status).toBe(401);
  });

  it('正文太短 → 400', async () => {
    const res = await req('POST', '/v1/ai/suggest-tags', { content: '太短了' }, authHeader());
    expect(res.status).toBe(400);
    expect(res.json.message).toContain('先写点正文');
  });

  it('happy path：白名单外的编造标签被剔除，成功后落一条 aiCallStat', async () => {
    mockPrisma.tag.findMany.mockResolvedValue([{ name: '数码选购' }, { name: '手机' }]);
    mockChatContent('{"tags":["数码选购","手机","编造的新标签"]}');
    const res = await req('POST', '/v1/ai/suggest-tags', { content: LONG_BODY, genre: 'review' }, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.data.tags).toEqual(['数码选购', '手机']);
    expect(mockPrisma.aiCallStat.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ endpoint: 'suggest-tags' }) })
    );
  });

  it('excludeTags 生效：已选标签不重复推荐', async () => {
    mockPrisma.tag.findMany.mockResolvedValue([{ name: '数码选购' }, { name: '手机' }]);
    mockChatContent('{"tags":["数码选购","手机"]}');
    const res = await req('POST', '/v1/ai/suggest-tags', { content: LONG_BODY, excludeTags: ['手机'] }, authHeader());
    expect(res.status).toBe(200);
    expect(res.json.data.tags).toEqual(['数码选购']);
  });

  it('LLM 全在白名单外 → 503（宁可不给，不编造）', async () => {
    mockPrisma.tag.findMany.mockResolvedValue([{ name: '数码选购' }]);
    mockChatContent('{"tags":["完全无关","胡编乱造"]}');
    const res = await req('POST', '/v1/ai/suggest-tags', { content: LONG_BODY }, authHeader());
    expect(res.status).toBe(503);
    expect(res.json.message).toContain('挑出合适的标签');
  });
});

describe('POST /v1/ai/search-rescue', () => {
  // 独立 userId：consumeQuota 同文件内跨用例累积，避免挤占 user 1 的 20 次/日测试预算
  const RESCUE_USER = 98;

  it('缺 Authorization → 401', async () => {
    const res = await req('POST', '/v1/ai/search-rescue', { keyword: '续航' });
    expect(res.status).toBe(401);
  });

  it('keyword 为空 → 400', async () => {
    const res = await req('POST', '/v1/ai/search-rescue', { keyword: '   ' }, authHeader(RESCUE_USER));
    expect(res.status).toBe(400);
  });

  it('happy path：改写词返回，成功后落一条 aiCallStat', async () => {
    mockChatContent('{"suggestions":["手机续航","电池实测"]}');
    const res = await req('POST', '/v1/ai/search-rescue', { keyword: '电池不太行' }, authHeader(RESCUE_USER));
    expect(res.status).toBe(200);
    expect(res.json.data.suggestions).toEqual(['手机续航', '电池实测']);
    expect(mockPrisma.aiCallStat.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ endpoint: 'search-rescue' }) })
    );
  });

  it('超长改写词被钳制到 20 字内', async () => {
    mockChatContent(JSON.stringify({ suggestions: ['很'.repeat(30)] }));
    const res = await req('POST', '/v1/ai/search-rescue', { keyword: '一个查询词' }, authHeader(RESCUE_USER));
    expect(res.status).toBe(200);
    expect(res.json.data.suggestions[0].length).toBeLessThanOrEqual(20);
  });

  it('敏感词逐个过滤：坏词剔除、好词保留；全坏 → 503', async () => {
    mockChatContent('{"suggestions":["好建议","坏建议一"]}');
    mockCheckText.mockImplementation((t: string) => t.startsWith('坏建议'));
    const keep = await req('POST', '/v1/ai/search-rescue', { keyword: '查询词' }, authHeader(RESCUE_USER));
    expect(keep.status).toBe(200);
    expect(keep.json.data.suggestions).toEqual(['好建议']);

    mockChatContent('{"suggestions":["坏建议一","坏建议二"]}');
    const drop = await req('POST', '/v1/ai/search-rescue', { keyword: '查询词' }, authHeader(RESCUE_USER));
    expect(drop.status).toBe(503);
  });
});

describe('AI 配额与管理员豁免', () => {
  // 独立 userId：consumeQuota 是模块级内存计数，与 TEST_USER_ID=1 的既有用例互不污染
  const QUOTA_USER = 99;
  const savedDailyLimit = env.ai.dailyLimit;

  afterAll(() => {
    env.ai.dailyLimit = savedDailyLimit;
    env.adminUserIds = [];
  });

  it('非管理员超日配额 → 400 已用完', async () => {
    env.ai.dailyLimit = 1;
    env.adminUserIds = [];
    mockChatContent('{"genre":"review","blocks":[{"type":"insight","value":"续航实测 8.4 小时"}]}');
    const body = { content: '这三周我每天记录亮屏时间，平均 8.4 小时。', genre: 'review' };
    const first = await req('POST', '/v1/ai/structure-draft', body, authHeader(QUOTA_USER));
    expect(first.status).toBe(200);
    const second = await req('POST', '/v1/ai/structure-draft', body, authHeader(QUOTA_USER));
    expect(second.status).toBe(400);
    expect(second.json.message).toContain('已用完');
  });

  it('管理员（ADMIN_USER_IDS）豁免日配额：同账号连续调用不受 20 次/日限制', async () => {
    env.ai.dailyLimit = 1;
    env.adminUserIds = [QUOTA_USER];
    const body = { content: '这三周我每天记录亮屏时间，平均 8.4 小时。', genre: 'review' };
    for (let i = 0; i < 3; i++) {
      mockChatContent('{"genre":"review","blocks":[{"type":"insight","value":"续航实测 ' + i + ' 小时"}]}');
      const res = await req('POST', '/v1/ai/structure-draft', body, authHeader(QUOTA_USER));
      expect(res.status).toBe(200);
    }
  });
});
