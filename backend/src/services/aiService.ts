import { env } from '../config/env';
import { AiUnavailableError, SensitiveWordError, ValidationError } from '../utils/errors';
import { sensitiveWordService } from './sensitiveWordService';
import { validateStructuredDocument } from '../utils/structuredDocument';

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
  const day: string = new Date().toISOString().slice(0, 10);
  const hit = usage.get(userId);
  const count: number = hit && hit.day === day ? hit.count : 0;
  if (count >= env.ai.dailyLimit) {
    throw new ValidationError('今天的 AI 次数已用完（' + env.ai.dailyLimit + ' 次），明天再来');
  }
  usage.set(userId, { day: day, count: count + 1 });
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

// —— P1：标题优化。更具体、有信息量、突出可核验细节；禁止标题党与编造。 ——
export async function polishTitle(userId: number, title: string, content: string, _genre: string): Promise<{ title: string }> {
  consumeQuota(userId);
  const body: string = content.trim();
  if (body.length === 0) {
    throw new ValidationError('先写点正文，AI 才有依据优化标题');
  }
  const system: string = [
    '你是社区「有据」的标题编辑。基于帖子正文优化标题：更具体、有信息量，突出一个可核验的细节或数字。',
    '禁止标题党、禁止编造正文没有的事实、禁止堆砌感叹号与夸张词，不超过 24 个字。',
    '输出：仅一个 JSON 对象 {"title":"..."}，不要输出任何解释或 markdown 代码块。',
  ].join('\n');
  const user: string = '当前标题：' + (asText(title).length > 0 ? asText(title) : '（无）') + '\n正文：' + body.slice(0, 2000);
  const raw: Record<string, unknown> = extractJson(await chatJson(system, user));
  let polished: string = clampText(raw.title, LIMIT_TITLE);
  if (polished.length === 0) {
    throw new AiUnavailableError();
  }
  if (sensitiveWordService.checkText(polished)) {
    throw new SensitiveWordError('AI 优化的标题未通过安全检查，请手动修改标题');
  }
  return { title: polished };
}

// —— P0：正文整理结构化。产出合法 V2/V3 文档草稿，前端灌入 StructuredComposer 由作者逐块确认。 ——
export async function structureDraft(userId: number, content: string, genre: string): Promise<{ document: Record<string, unknown> }> {
  consumeQuota(userId);
  const body: string = content.trim();
  if (body.length < DRAFT_MIN_CONTENT) {
    throw new ValidationError('正文太短（至少 ' + DRAFT_MIN_CONTENT + ' 字），AI 整理不出有价值的结构');
  }
  const allowed: string[] = GENRE_BLOCK_TYPES[genre] ?? ['insight', 'list'];
  const typeHints: string[] = [];
  for (const type of allowed) {
    if (type === 'insight') typeHints.push('{"type":"insight","value":"一句话结论"}');
    else if (type === 'compare') typeHints.push('{"type":"compare","leftLabel":"优点","leftValue":"...","rightLabel":"缺点","rightValue":"..."}');
    else typeHints.push('{"type":"' + type + '","items":["条目一","条目二"]}');
  }
  const system: string = [
    '你是社区「有据」的结构化编辑助手。任务：把作者已写的正文整理成结构化信息块草稿。',
    '铁律：',
    '1. 只允许使用正文里已有的事实与表述，禁止新增、推测、夸大任何内容；',
    '2. 禁止生成任何出处、来源、证据——证据只能由作者本人提供；',
    '3. 语言风格与正文保持一致，不写套话；',
    '4. 块数量 2-' + MAX_BLOCKS + ' 个，宁缺毋滥；每条 item 不超过 40 字。',
    '可用块类型（只能用这些）：' + allowed.join('、') + '。',
    '示例形态：' + typeHints.join('；'),
    '输出：仅一个 JSON 对象 {"blocks":[...]}，不要输出任何解释或 markdown 代码块。',
  ].join('\n');
  const user: string = '体裁：' + (genre.length > 0 ? genre : '未指定') + '\n正文：' + body.slice(0, 3000);
  const raw: Record<string, unknown> = extractJson(await chatJson(system, user));
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
  return { document: document };
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
  return { title: polishedTitle, content: polishedContent };
}
