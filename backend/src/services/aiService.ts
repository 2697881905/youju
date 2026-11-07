import { env } from '../config/env';
import { AiUnavailableError, SensitiveWordError, ValidationError } from '../utils/errors';
import { sensitiveWordService } from './sensitiveWordService';
import { validateStructuredDocument } from '../utils/structuredDocument';
import { prisma } from '../prisma';
import * as tagService from './tagService';

// ============================================================================
// AI 辅助创作服务（发布页：标题优化 / 正文整理结构化）。
//
// 定位铁律（2026-11-05 产品决策）：AI 只做「原文驱动的整理」，不做内容生成。
//   - structure-draft 只允许把正文已有的事实搬进信息块，禁止新增/推测/夸大；
//   - 禁止生成任何出处或证据——证据只能由作者本人挂（幻觉出处 = 砸「可核验」招牌）；
//   - 输出必须通过 validateStructuredDocument 硬校验（字段白名单/长度上限全继承），
//     并与用户内容同过敏感词闸（UGC 三道防线不因 AI 豁免）。
//
// Provider 抽象：OpenAI 兼容 chat completions（DeepSeek / 火山方舟 / 通义均兼容），
// 换服务商只改 .env 的 AI_API_BASE / AI_API_KEY / AI_MODEL，不动代码。
// ============================================================================

// 各体裁允许的块类型，与前端 structuredBlockTypesForGenre 同源（metric 已退役）。
const GENRE_BLOCK_TYPES: Record<string, string[]> = {
  review: ['insight', 'compare', 'list'],
  pitfall: ['insight', 'steps', 'list'],
  tutorial: ['steps', 'list', 'insight'],
  debate: ['compare', 'insight'],
};

// AI 推断体裁的白名单与推荐骨架：响应带 { document, genre, template }，
// 前端审稿层据此回填体裁分段栏、展示「参考了哪副骨架」。share 是轻量体裁，骨架用通用「一句结论」。
const GENRE_WHITELIST: string[] = ['review', 'pitfall', 'tutorial', 'debate', 'share'];
const GENRE_TEMPLATE: Record<string, string> = {
  review: 'review_score',
  pitfall: 'pitfall_case',
  tutorial: 'tutorial_path',
  debate: 'debate_side',
  share: 'insight',
};

// 长度上限与后端 validateStructuredDocument 的校验口径对齐；AI 输出先截断再校验，
// 避免「模型话多」直接变成用户可见的 400。
const LIMIT_VALUE = 300;
const LIMIT_ITEM = 120;
const LIMIT_SIDE_LABEL = 12;
const LIMIT_SIDE_VALUE = 180;
const LIMIT_TITLE = 30;
const MAX_BLOCKS = 4;
const DRAFT_MIN_CONTENT = 20;

export function aiEnabled(): boolean {
  return env.ai.apiBase.length > 0 && env.ai.apiKey.length > 0 && env.ai.model.length > 0;
}

// —— 每用户每日配额（内存计数）：进程重启清零。定位是防刷兜底，不是计费口径。 ——
const usage = new Map<number, { day: string; count: number }>();

function consumeQuota(userId: number): void {
  // ADMIN_USER_IDS 内的账号豁免日配额：管理员测试/运营操作不受 20 次/日限制
  // （2026-11-07：真机联调连点发布撞 429；普通用户防刷不变）。突刺限流豁免在 rateLimit.aiLimiter。
  if (env.adminUserIds.includes(userId)) {
    return;
  }
  const day: string = new Date().toISOString().slice(0, 10);
  const hit = usage.get(userId);
  const count: number = hit && hit.day === day ? hit.count : 0;
  if (count >= env.ai.dailyLimit) {
    throw new ValidationError('今天的 AI 次数已用完（' + env.ai.dailyLimit + ' 次），明天再来');
  }
  usage.set(userId, { day: day, count: count + 1 });
}

// —— AI 调用统计（2026-11-07）：每成功一次 LLM 调用落一行，采用率按 endpoint×day 聚合 ——
// 定位是「先证明 AI 功能有效」的度量地基：只记成功=只记真实拿到的价值（配额拒绝/上游失败不计）。
// 落库失败静默吞掉——统计永不影响主流程，量级小（20 次/日/人上限），偶发丢失可接受。
// day 与配额 usage Map 同口径（UTC）。管理员调用也落库，查询侧 /v1/admin/ai-stats 按需排除。
export function recordAiCall(endpoint: string, userId: number): void {
  try {
    const day: string = new Date().toISOString().slice(0, 10);
    prisma.aiCallStat.create({ data: { endpoint: endpoint, day: day, userId: userId } }).catch((): void => {
      // 异步失败同样静默：统计不参与任何业务判断
    });
  } catch {
    // 同步异常（客户端异常等）也不影响主流程
  }
}

function stripFence(text: string): string {
  let t: string = text.trim();
  if (t.startsWith('```')) {
    t = t.replace(/^```[a-zA-Z]*\n?/, '').replace(/```\s*$/, '');
  }
  return t.trim();
}

// 取第一个 { 到最后一个 } 的片段：容忍模型在 JSON 前后带少量杂讯。
function extractJson(text: string): Record<string, unknown> {
  const start: number = text.indexOf('{');
  const end: number = text.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw new AiUnavailableError();
  }
  try {
    return JSON.parse(text.slice(start, end + 1)) as Record<string, unknown>;
  } catch {
    throw new AiUnavailableError();
  }
}

interface AiChatMessage {
  role: string;
  content: string;
}

async function chatJson(system: string, user: string, maxTokens: number = 800, temperature: number = 0.3): Promise<string> {
  if (!aiEnabled()) {
    throw new AiUnavailableError();
  }
  const messages: AiChatMessage[] = [
    { role: 'system', content: system },
    { role: 'user', content: user },
  ];
  const controller = new AbortController();
  const timer: ReturnType<typeof setTimeout> = setTimeout((): void => controller.abort(), env.ai.timeoutMs);
  try {
    const resp: Response = await fetch(env.ai.apiBase.replace(/\/+$/, '') + '/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + env.ai.apiKey },
      body: JSON.stringify({ model: env.ai.model, messages: messages, temperature: temperature, max_tokens: maxTokens }),
      signal: controller.signal,
    });
    if (!resp.ok) {
      throw new AiUnavailableError();
    }
    const data = (await resp.json()) as { choices?: Array<{ message?: { content?: string } }> };
    const content: string = data.choices?.[0]?.message?.content ?? '';
    if (content.length === 0) {
      throw new AiUnavailableError();
    }
    return stripFence(content);
  } catch (e) {
    if (e instanceof AiUnavailableError) {
      throw e;
    }
    // 超时 / 网络 / JSON 解析失败统一降级为「AI 暂不可用」，不向外泄露上游细节
    throw new AiUnavailableError();
  } finally {
    clearTimeout(timer);
  }
}

function asText(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function clampText(value: unknown, max: number): string {
  const s: string = asText(value);
  return s.length > max ? s.slice(0, max) : s;
}

// —— P0：正文整理结构化。产出合法 V2/V3 文档草稿，前端灌入审稿层由作者逐块确认。
// genre 允许为空：空则 LLM 从正文自行推断体裁（隐式发布流不再强迫作者先懂「体裁」）；
// 非空则作为作者倾向传入，模型优先尊重、明显不符才推翻。响应扩为 { document, genre, template }。
export async function structureDraft(userId: number, content: string, genre: string): Promise<{ document: Record<string, unknown>; genre: string; template: string }> {
  consumeQuota(userId);
  const body: string = content.trim();
  if (body.length < DRAFT_MIN_CONTENT) {
    throw new ValidationError('正文太短（至少 ' + DRAFT_MIN_CONTENT + ' 字），AI 整理不出有价值的结构');
  }
  const userGenre: string = GENRE_WHITELIST.indexOf(genre) >= 0 ? genre : '';
  const genreLine: string = userGenre.length > 0
    ? '作者在发布页标记的体裁是「' + userGenre + '」，优先尊重；只有正文明显不符时才推翻。'
    : '作者未标记体裁，请从正文内容判断。';
  const system: string = [
    '你是社区「有据」的结构化编辑助手。任务：先判断正文的体裁，再把正文整理成结构化信息块草稿。',
    '体裁候选：review（测评/实测对比）、pitfall（踩坑与正确做法）、tutorial（教程/步骤拆解）、debate（正反观点对照）、share（经验见闻）。',
    genreLine,
    '铁律：',
    '1. 只允许使用正文里已有的事实与表述，禁止新增、推测、夸大任何内容；',
    '2. 禁止生成任何出处、来源、证据——证据只能由作者本人提供；',
    '3. 语言风格与正文保持一致，不写套话；',
    '4. 块数量 2-' + MAX_BLOCKS + ' 个，宁缺毋滥；每条 item 不超过 40 字。',
    '块类型按体裁选用：review 用 insight、compare、list；pitfall 用 insight、steps、list；tutorial 用 steps、list、insight；debate 用 compare、insight；share 用 insight、list。',
    '示例形态：{"type":"insight","value":"一句话结论"}；{"type":"compare","leftLabel":"优点","leftValue":"...","rightLabel":"缺点","rightValue":"..."}；{"type":"steps","items":["步骤一","步骤二"]}；{"type":"list","items":["条目一","条目二"]}。',
    '输出：仅一个 JSON 对象 {"genre":"体裁","blocks":[...]}，不要输出任何解释或 markdown 代码块。',
  ].join('\n');
  const user: string = '体裁倾向：' + (userGenre.length > 0 ? userGenre : '未指定') + '\n正文：' + body.slice(0, 3000);
  const raw: Record<string, unknown> = extractJson(await chatJson(system, user, 1200));
  // 推断体裁必须过白名单：模型幻觉出未知体裁时回退作者标记，再回退 share（最通用的轻量体裁）。
  const inferred: string = asText(raw.genre);
  const finalGenre: string = GENRE_WHITELIST.indexOf(inferred) >= 0 ? inferred
    : (userGenre.length > 0 ? userGenre : 'share');
  const allowed: string[] = GENRE_BLOCK_TYPES[finalGenre] ?? ['insight', 'list'];
  const rawBlocks: unknown[] = Array.isArray(raw.blocks) ? raw.blocks : [];

  // 清洗：类型白名单过滤（未知/已退役的 metric 直接丢弃）+ 键白名单 + 截断 + id 服务端重生成
  const blocks: Array<Record<string, unknown>> = [];
  let seq: number = 0;
  for (const item of rawBlocks) {
    if (typeof item !== 'object' || item === null || Array.isArray(item)) continue;
    const rb = item as Record<string, unknown>;
    const type: string = asText(rb.type);
    if (allowed.indexOf(type) < 0) continue;
    const block: Record<string, unknown> = {
      id: 'ai_' + String(Date.now()) + '_' + String(++seq),
      type: type,
      // 校验器对 8 个文本字段是「存在性」检查（undefined 即拒，空串放行，见 textError），
      // 与前端 createStructuredBlock 恒带全键一致 —— AI 块补齐空串，按类型再覆盖真实值。
      title: '', value: '', unit: '', helper: '',
      leftLabel: '', leftValue: '', rightLabel: '', rightValue: '',
      items: [],
    };
    if (type === 'insight') {
      const value: string = clampText(rb.value, LIMIT_VALUE);
      if (value.length === 0) continue;
      block.value = value;
    } else if (type === 'compare') {
      const leftValue: string = clampText(rb.leftValue, LIMIT_SIDE_VALUE);
      const rightValue: string = clampText(rb.rightValue, LIMIT_SIDE_VALUE);
      if (leftValue.length === 0 && rightValue.length === 0) continue;
      block.leftLabel = clampText(rb.leftLabel, LIMIT_SIDE_LABEL).length > 0 ? clampText(rb.leftLabel, LIMIT_SIDE_LABEL) : 'A';
      block.rightLabel = clampText(rb.rightLabel, LIMIT_SIDE_LABEL).length > 0 ? clampText(rb.rightLabel, LIMIT_SIDE_LABEL) : 'B';
      block.leftValue = leftValue;
      block.rightValue = rightValue;
    } else {
      const items: unknown[] = Array.isArray(rb.items) ? rb.items : [];
      const cleaned: string[] = [];
      for (const it of items) {
        const t: string = clampText(it, LIMIT_ITEM);
        if (t.length > 0) cleaned.push(t);
      }
      if (cleaned.length === 0) continue;
      block.items = cleaned.slice(0, 12);
    }
    blocks.push(block);
    if (blocks.length >= MAX_BLOCKS) break;
  }
  if (blocks.length === 0) {
    throw new AiUnavailableError('AI 没能从正文整理出信息块，请补充更多细节或手动填写');
  }

  // 敏感词闸与用户内容同源：AI 输出不豁免（序列化整块覆盖全部文本字段）
  for (const block of blocks) {
    if (sensitiveWordService.checkText(JSON.stringify(block))) {
      throw new SensitiveWordError('AI 整理的内容未通过安全检查，请修改正文后重试');
    }
  }

  let primary: Record<string, unknown> = blocks[0];
  for (const block of blocks) {
    if (block.type === 'insight') {
      primary = block;
      break;
    }
  }
  const document: Record<string, unknown> = {
    schemaVersion: 3,
    primaryBlockId: primary.id,
    theme: 'editorial',
    blocks: blocks,
  };
  const invalid: string | null = validateStructuredDocument(document);
  if (invalid !== null) {
    throw new AiUnavailableError('AI 整理结果未通过校验，请重试');
  }
  recordAiCall('structure-draft', userId);
  return { document: document, genre: finalGenre, template: GENRE_TEMPLATE[finalGenre] ?? '' };
}

// —— P2：标题 + 正文联合润色。保持原意与段落结构，但表达要有可感知的升级：
// 实测教训——prompt 只说「改语病」时，DeepSeek 对通顺的原稿几乎原样返回（101 字只改 4 字），
// 用户观感就是「正文没变」。因此指令必须是「可见的改进」，并用 normalizeSame + 重试兜底。
// 与 structureDraft 同一铁律：禁止新增/推测任何事实、数字、证据；输出不豁免敏感词闸。
// maxContent 由前端按发布页限制传入（图文说明 300 / 长文 5000），后端钳制到 [200, 5000]。
const POLISH_MIN_KEEP_RATIO = 0.3; // 底线：润色结果不得短于原文 30%（防模型偷懒只回一半）
const POLISH_MAX_TOKENS = 2000;   // 正文可长达数千字，800 token 会截断 JSON

// 归一化后比对是否「原样返回」：剔除空白与标点，只看实义字符序列
function normalizeSame(a: string, b: string): boolean {
  const strip = (s: string): string => s.replace(/[\s，。、；：！？「」『』（）【】,.:;!?'"\-—…·]/g, '');
  return strip(a) === strip(b) && strip(a).length > 0;
}

export async function polishDraft(
  userId: number,
  title: string,
  content: string,
  genre: string,
  maxContent: number
): Promise<{ title: string; content: string }> {
  consumeQuota(userId);
  const body: string = content.trim();
  if (body.length === 0) {
    throw new ValidationError('先写点正文，AI 才有依据润色');
  }
  const requested: number = Number.isFinite(maxContent) ? Math.floor(maxContent) : 0;
  const cap: number = Math.max(200, Math.min(requested > 0 ? requested : 5000, 5000));
  const system: string = [
    '你是社区「有据」的代笔编辑。任务：读懂作者的帖子，然后【用你自己的话把同一件事重新讲一遍】——事实、数字、体验、结论与原文完全一致，但表达整体重写。',
    '硬性要求：不要复用原句的措辞和句式（目数、型号、专有名词除外）；语序重组、句式替换、口语换书面、啰嗦句提炼成利落短句，都是你的手段。',
    '改前：今天用了这个锅觉得还挺不错的，导热挺快的，然后清洗也方便，价格也不贵，总的来说值得买。',
    '改后：一口锅三天用下来，值不值看三点：导热快、好清洗、价格不虚高。这台都占了。',
    '交付标准：润色稿与原稿并排放，读者应一眼看出被重新写过。',
    '铁律：',
    '1. 不改变任何事实、数字、体验或结论，禁止新增、推测、夸大；',
    '2. 禁止生成任何出处、来源、证据——证据只能由作者本人提供；',
    '3. 不堆砌感叹号与夸张词，不写套话；标题不超过 24 个字；',
    '4. 润色后的正文不超过 ' + cap + ' 个字。',
    '输出：仅一个 JSON 对象 {"title":"...","content":"..."}，不要输出任何解释或 markdown 代码块。',
  ].join('\n');
  const user: string = '体裁：' + (genre.length > 0 ? genre : '未指定')
    + '\n当前标题：' + (asText(title).length > 0 ? asText(title) : '（无）')
    + '\n正文：' + body.slice(0, 4000);

  // 两次机会：0.7 温度仍原样返回，则 0.9 再试；依旧原样则如实告知（不硬造差异）
  let raw: Record<string, unknown> = extractJson(await chatJson(system, user, POLISH_MAX_TOKENS, 0.7));
  if (normalizeSame(asText(raw.content), body)) {
    raw = extractJson(await chatJson(system, user, POLISH_MAX_TOKENS, 0.9));
    if (normalizeSame(asText(raw.content), body)) {
      throw new AiUnavailableError('这篇正文已经写得很干净，AI 没找到值得润色的地方');
    }
  }
  const polishedTitle: string = clampText(raw.title, LIMIT_TITLE);
  const polishedContent: string = clampText(raw.content, cap);
  if (polishedTitle.length === 0 || polishedContent.length === 0) {
    throw new AiUnavailableError();
  }
  if (polishedContent.length < body.length * POLISH_MIN_KEEP_RATIO) {
    throw new AiUnavailableError('AI 润色结果过短，请重试');
  }
  if (sensitiveWordService.checkText(polishedTitle + '\n' + polishedContent)) {
    throw new SensitiveWordError('AI 润色的内容未通过安全检查，请手动修改');
  }
  recordAiCall('polish-draft', userId);
  return { title: polishedTitle, content: polishedContent };
}

// —— 标签推荐（2026-11-07）：LLM 只从现有标签白名单里挑，服务端交集兜底 ——
// 标签是检索基建（搜索按 tags 过滤），编造的标签搜不到东西还污染体系。
// 所以铁律是「挑选而非创造」：白名单外的名字一律剔除，挑不出就宁可不给。
export async function suggestTags(userId: number, content: string, genre: string, excludeTags: string[]): Promise<{ tags: string[] }> {
  consumeQuota(userId);
  const body: string = content.trim();
  if (body.length < 10) {
    throw new ValidationError('先写点正文，AI 才有依据推荐标签');
  }
  // 白名单与 GET /v1/tags 同源（tagService.listTags，按 useCount 降序）；截前 60 个防 prompt 膨胀
  const allTags = await tagService.listTags();
  const names: string[] = [];
  for (const t of allTags) {
    if (typeof t.name === 'string' && t.name.length > 0) {
      names.push(t.name);
    }
    if (names.length >= 60) break;
  }
  if (names.length === 0) {
    throw new AiUnavailableError('标签库为空，请手动选择标签');
  }
  const genreLine: string = GENRE_WHITELIST.indexOf(genre) >= 0 ? '（体裁：' + genre + '）' : '';
  const system: string = [
    '你是社区「有据」的标签助手。任务：读完帖子正文，从「可选标签」列表里挑出 2-3 个最能帮帖子被搜到的标签。',
    '铁律：只能从可选标签里挑，禁止创造列表外的新标签；禁止输出列表里与正文无关的标签。',
    '输出：仅一个 JSON 对象 {"tags":["标签1","标签2"]}，不要输出任何解释或 markdown 代码块。',
  ].join('\n');
  const user: string = '可选标签：' + names.join('、') + genreLine + '\n正文：' + body.slice(0, 2000);
  const raw: Record<string, unknown> = extractJson(await chatJson(system, user, 300));
  const picked: unknown[] = Array.isArray(raw.tags) ? raw.tags : [];
  const exclude = new Set<string>(excludeTags);
  const out: string[] = [];
  for (const p of picked) {
    const name: string = asText(p);
    if (name.length === 0 || exclude.has(name) || out.indexOf(name) >= 0) continue;
    if (names.indexOf(name) < 0) continue; // 白名单外一律剔除
    out.push(name);
    if (out.length >= 3) break;
  }
  if (out.length === 0) {
    throw new AiUnavailableError('AI 没有从标签库里挑出合适的标签，可手动选择');
  }
  recordAiCall('suggest-tags', userId);
  return { tags: out };
}

// —— 搜索空结果救援（2026-11-07）：把用户查询改写成「库里搜得到」的短词 ——
// 定位：内容量小阶段关键词命中率低是常态，救援把「搜不到」变成「知道该搜什么」；
// 输出是改写词不是内容生成，不引入事实；内容量上来后空结果自然变少，本功能自然闲置。
export async function searchRescue(userId: number, keyword: string): Promise<{ suggestions: string[] }> {
  consumeQuota(userId);
  const q: string = asText(keyword).slice(0, 50);
  if (q.length === 0) {
    throw new ValidationError('搜索词为空');
  }
  const allTags = await tagService.listTags();
  const names: string[] = [];
  for (const t of allTags) {
    if (typeof t.name === 'string' && t.name.length > 0) {
      names.push(t.name);
    }
    if (names.length >= 60) break;
  }
  const system: string = [
    '你是社区「有据」的搜索助手。用户刚搜过一个词但没有结果。任务：把用户的搜索词改写成 2-3 个更常见的说法或近义词，让内容更容易被搜到。',
    '铁律：只输出改写后的搜索词本身；参考「标签库」里的既有词优先；禁止编造产品型号、品牌或任何事实；每个词不超过 12 个字。',
    '输出：仅一个 JSON 对象 {"suggestions":["词1","词2"]}，不要输出任何解释或 markdown 代码块。',
  ].join('\n');
  const user: string = '标签库：' + (names.length > 0 ? names.join('、') : '（空）') + '\n用户搜索词：' + q;
  const raw: Record<string, unknown> = extractJson(await chatJson(system, user, 300));
  const picked: unknown[] = Array.isArray(raw.suggestions) ? raw.suggestions : [];
  const out: string[] = [];
  for (const p of picked) {
    const w: string = clampText(p, 20);
    if (w.length === 0 || w === q || out.indexOf(w) >= 0) continue;
    out.push(w);
    if (out.length >= 3) break;
  }
  // 敏感词逐个过滤而非整体失败：一个坏词不该连累其他干净建议
  const clean: string[] = out.filter((w: string): boolean => !sensitiveWordService.checkText(w));
  if (clean.length === 0) {
    throw new AiUnavailableError();
  }
  recordAiCall('search-rescue', userId);
  return { suggestions: clean };
}
