import { env } from '../config/env';

// 运营通知服务（飞书自定义机器人 Webhook）
// 设计：与 huaweiPush 一致 —— 未配置 / 发送失败时静默降级，绝不阻断主流程。
// 使用方式：在群设置中添加「自定义机器人」拿到 Webhook URL，填入环境变量 OPS_WEBHOOK_URL。
// 支持飞书「自定义机器人 Webhook」的消息格式（interactive 卡片）。

// 举报原因 → 中文标签（与前端 ReportDialog 选项文案对齐）
const REASON_LABELS: Record<string, string> = {
  political: '政治敏感',
  pornographic: '色情低俗',
  personal_attack: '人身攻击',
  gender_war: '性别对立',
  advertisement: '广告导流',
  spam: '垃圾信息',
  other: '其他',
};

export interface ReportOpsPayload {
  reportId: number;
  targetType: 'post' | 'comment' | 'user';
  targetId: number;
  reason: string;
  description?: string | null;
  // 目标辅助信息（尽力而为，可为空）
  targetTitle?: string;
  reportCount?: number; // 该目标累计举报数（递增后）
  autoTakenDown?: boolean; // 是否已达阈值自动下架
}

// 是否已配置运营通知 Webhook。
export function isOpsWebhookConfigured(): boolean {
  return env.opsWebhookUrl.trim() !== '';
}

// 目标类型 → 中文标签
function targetTypeLabel(type: ReportOpsPayload['targetType']): string {
  switch (type) {
    case 'post':
      return '帖子';
    case 'comment':
      return '评论';
    case 'user':
      return '用户';
    default:
      return type;
  }
}

function reasonLabel(reason: string): string {
  return REASON_LABELS[reason] ?? reason;
}

// 构建飞书自定义机器人 interactive 卡片消息体
function buildFeishuCard(payload: ReportOpsPayload): string {
  const typeLabel = targetTypeLabel(payload.targetType);
  const titleText =
    payload.targetType === 'post'
      ? `《${payload.targetTitle ?? `帖子 #${payload.targetId}`}》`
      : `#${payload.targetId}`;
  const description = payload.description?.trim();
  const countInfo = payload.autoTakenDown
    ? `（累计 ${payload.reportCount} 次，已达阈值已自动下架）`
    : payload.reportCount && payload.reportCount > 0
      ? `（累计 ${payload.reportCount} 次）`
      : '';
  const descLine = description
    ? `\n- **补充说明**：${description.slice(0, 200)}`
    : '\n- **补充说明**：无';

  const content = [
    `**有据 · 收到新举报**`,
    `- **举报内容**：${typeLabel} ${titleText}`,
    `- **举报理由**：${reasonLabel(payload.reason)}`,
    descLine,
    `- **累计举报数**：${payload.reportCount ?? '—'}${payload.autoTakenDown ? '（已达阈值，已自动下架）' : ''}`,
    `- **时间**：${new Date().toLocaleString('zh-CN', { hour12: false })}`,
  ].join('\n');

  return JSON.stringify({
    msg_type: 'interactive',
    card: {
      config: { wide_screen_mode: true },
      header: {
        title: { tag: 'plain_text', content: `有据 · 新举报提醒（${typeLabel}）` },
        template: payload.autoTakenDown ? 'red' : 'orange',
      },
      elements: [
        { tag: 'div', text: { tag: 'lark_md', content } },
        {
          tag: 'note',
          elements: [
            {
              tag: 'plain_text',
              content: `举报 ID ${payload.reportId} · 请在管理后台处理`,
            },
          ],
        },
      ],
    },
  });
}

// 推送一条新举报给运营者。未配置 / 失败时吞掉错误，调用方无需 catch。
export async function notifyNewReport(payload: ReportOpsPayload): Promise<void> {
  const webhookUrl = env.opsWebhookUrl.trim();
  if (webhookUrl === '') return; // 未配置 → 静默跳过

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 5000); // 5s 超时，防卡住事件循环
  try {
    const resp = await fetch(webhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: buildFeishuCard(payload),
      signal: controller.signal,
    });
    if (!resp.ok) {
      const text = await resp.text();
      console.warn(`[opsNotifier] 飞书机器人推送失败: ${resp.status} ${text.slice(0, 200)}`);
    }
  } catch (e: any) {
    // 超时（abort）/网络错误：仅记录，不影响举报主流程
    console.warn(`[opsNotifier] 飞书机器人推送异常: ${e?.message ?? e}`);
  } finally {
    clearTimeout(timer);
  }
}