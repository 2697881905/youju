// 上线前全链路 E2E（临时脚本，跑完删除）：API 真实调用 + Prisma DB 断言
// 用法：npx tsx e2e-qa.mts main   |   npx tsx e2e-qa.mts admin
import { PrismaClient } from '@prisma/client';
import * as fs from 'node:fs';

const prisma = new PrismaClient();
const BASE = 'http://127.0.0.1:3000';
const CTX_FILE = '/tmp/e2e-qa-ctx.json';
const results: { name: string; pass: boolean; detail?: string }[] = [];

function rec(name: string, pass: boolean, detail?: string): void {
  results.push({ name, pass, detail });
  console.log(`${pass ? 'PASS' : 'FAIL'}  ${name}${detail ? '  | ' + detail : ''}`);
}

interface ApiResp { status: number; json: any; }
async function api(method: string, path: string, token?: string, body?: unknown): Promise<ApiResp> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(BASE + path, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json: any = null;
  try { json = JSON.parse(text); } catch { json = { raw: text.slice(0, 120) }; }
  return { status: res.status, json };
}
const data = (r: ApiResp) => r.json?.data;

async function mainPhase(): Promise<void> {
  const suffix = String(Date.now()).slice(-7);
  const openIdA = `e2e-qa-a-${suffix}`;
  const openIdB = `e2e-qa-b-${suffix}`;

  // ---- 认证 ----
  const h = await api('GET', '/health');
  rec('健康检查 /health', h.status === 200 && h.json?.ok === true);

  const la = await api('POST', '/v1/auth/login', undefined, { openId: openIdA, nickname: 'QA甲' });
  rec('登录 A（开放登录，本地）', la.status === 200 && !!data(la)?.token && Number(data(la)?.user?.id) > 0);
  A = { id: Number(data(la)?.user?.id), token: String(data(la)?.token) };

  const lb = await api('POST', '/v1/auth/login', undefined, { openId: openIdB, nickname: 'QA乙' });
  B = { id: Number(data(lb)?.user?.id), token: String(data(lb)?.token) };
  rec('登录 B', lb.status === 200 && B.id > 0 && B.token.length > 20);

  const me = await api('GET', '/v1/auth/me', A.token);
  rec('GET /auth/me 回读 A 资料', me.status === 200 && Number(data(me)?.id) === A.id);

  const noAuth = await api('GET', '/v1/posts/following');
  rec('未登录访问 /posts/following → 401（code=401）', noAuth.status === 401 && Number(noAuth.json?.code) === 401);

  const badLogin = await api('POST', '/v1/auth/login', undefined, { nickname: '没有openId' });
  rec('登录缺 openId → 400', badLogin.status === 400);

  // ---- 发帖 ----
  const cp = await api('POST', '/v1/posts', A.token, {
    title: `QA 全链路验证帖 ${suffix}`, genre: 'share',
    content: 'E2E 自动化测试内容，含关键词：黑洞洞的实验室。', publishMode: 'text',
  });
  const postId = Number(data(cp)?.id);
  rec('A 发长文帖（text 模式）', cp.status === 200 && postId > 0);
  const postRow = postId > 0 ? await prisma.post.findUnique({ where: { id: postId } }) : null;
  rec('DB: Post 落库（author/content/status=1/未删）',
    !!postRow && postRow.userId === A.id && (postRow.content ?? '').includes('实验室') &&
    postRow.status === 1 && postRow.deletedAt === null);

  const cpEmpty = await api('POST', '/v1/posts', A.token, { title: 'x', genre: 'share' });
  rec('边界：无正文发帖仍 200（content 可选）', cpEmpty.status === 200 && Number(data(cpEmpty)?.id) > 0);
  const cpLong = await api('POST', '/v1/posts', A.token, {
    title: '长文边界', genre: 'share', content: '啊'.repeat(5001), publishMode: 'text',
  });
  rec('边界：长文 5001 字 → 400', cpLong.status === 400);
  const cpOk5000 = await api('POST', '/v1/posts', A.token, {
    title: '长文 5000 边界', genre: 'share', content: '啊'.repeat(5000), publishMode: 'text',
  });
  rec('边界：长文 5000 字 → 200', cpOk5000.status === 200);
  const cpBadGenre = await api('POST', '/v1/posts', A.token, { title: 'x', genre: 'nope' });
  rec('边界：体裁非法 → 400', cpBadGenre.status === 400);
  const cpXss = await api('POST', '/v1/posts', A.token, {
    title: `<script>alert(1)</script> 注入测试 ${suffix}`, genre: 'share', publishMode: 'text',
  });
  rec('边界：XSS 标题被接受为纯文本（前端 Text 渲染不执行）', cpXss.status === 200);

  // ---- 列表 / 详情 ----
  const feed = await api('GET', '/v1/posts?page=1&limit=20&sort=latest', B.token);
  const feedIds: number[] = (data(feed)?.items ?? data(feed)?.list ?? []).map((x: any) => Number(x.id));
  rec('B 拉帖子列表包含 A 的新帖', feed.status === 200 && feedIds.includes(postId));
  const d1 = await api('GET', `/v1/posts/${postId}`, B.token);
  const d2 = await api('GET', `/v1/posts/${postId}`, B.token);
  const view1 = Number(data(d1)?.viewCount ?? data(d1)?.views ?? -1);
  const view2 = Number(data(d2)?.viewCount ?? data(d2)?.views ?? -1);
  rec('B 读详情（可访问）', d1.status === 200 && Number(data(d1)?.id) === postId);
  rec('详情浏览计数随访问递增', view2 === view1 + 1, `view ${view1} -> ${view2}`);

  // ---- 点赞 ----
  const up1 = await api('POST', `/v1/posts/${postId}/up`, B.token);
  const upCount1 = Number(data(up1)?.upCount ?? -1);
  const upRow = await prisma.up.findUnique({ where: { userId_postId: { userId: B.id, postId } } });
  rec('B 点赞 → DB Up 行落库', up1.status === 200 && !!upRow);
  const up2 = await api('POST', `/v1/posts/${postId}/up`, B.token);
  rec('重复点赞幂等（upCount 不变）', up2.status === 200 && Number(data(up2)?.upCount ?? -1) === upCount1);
  const unUp = await api('DELETE', `/v1/posts/${postId}/up`, B.token);
  const upRowGone = await prisma.up.findUnique({ where: { userId_postId: { userId: B.id, postId } } });
  rec('取消点赞 → DB Up 行删除', unUp.status === 200 && !upRowGone);
  await api('POST', `/v1/posts/${postId}/up`, B.token); // 恢复点赞，供后续统计

  // ---- 收藏 + 收藏夹（含分页缺陷复现）----
  const bk = await api('POST', `/v1/posts/${postId}/bookmark`, B.token);
  const bkRow = await prisma.bookmark.findUnique({ where: { userId_postId: { userId: B.id, postId } } });
  rec('B 收藏 → DB Bookmark 行落库', bk.status === 200 && !!bkRow);
  const post2 = await api('POST', '/v1/posts', A.token, {
    title: `QA 第二帖 ${suffix}`, genre: 'review', publishMode: 'text',
  });
  const postId2 = Number(data(post2)?.id);
  await api('POST', `/v1/posts/${postId2}/bookmark`, B.token);
  const folder = await api('POST', '/v1/bookmark-folders', B.token, { name: 'QA夹' });
  const folderId = Number(data(folder)?.id);
  rec('B 建收藏夹', folder.status === 200 && folderId > 0);
  await api('PATCH', `/v1/posts/${postId}/bookmark`, B.token, { folderId });
  await api('PATCH', `/v1/posts/${postId2}/bookmark`, B.token, { folderId });
  const fp = await api('GET', `/v1/bookmark-folders/${folderId}/posts?page=2&limit=1`, B.token);
  const fpItems = (data(fp)?.items ?? data(fp)?.posts ?? []).length;
  rec('收藏夹分页：page=2&limit=1 应返回 0 条（缺陷复现=返回 2 条）',
    fpItems === 0, `实际返回 ${fpItems} 条 → 路由未透传分页参数`);
  const unBk = await api('DELETE', `/v1/posts/${postId2}/bookmark`, B.token);
  const bkGone = await prisma.bookmark.findUnique({ where: { userId_postId: { userId: B.id, postId: postId2 } } });
  rec('B 取消收藏 → DB Bookmark 行删除', unBk.status === 200 && !bkGone);

  // ---- 评论 ----
  const c1 = await api('POST', `/v1/posts/${postId}/comments`, B.token, { content: 'QA评论：写得很清楚。' });
  const commentId = Number(data(c1)?.id);
  const cRow = commentId > 0 ? await prisma.comment.findUnique({ where: { id: commentId } }) : null;
  rec('B 评论 A 帖 → DB Comment 落库', c1.status === 200 && !!cRow && cRow.userId === B.id && cRow.postId === postId);
  const cEmpty = await api('POST', `/v1/posts/${postId}/comments`, B.token, { content: '   ' });
  rec('边界：空白评论 → 400', cEmpty.status === 400);
  const cLong = await api('POST', `/v1/posts/${postId}/comments`, B.token, { content: '哈'.repeat(2001) });
  rec('边界：评论 2001 字 → 400', cLong.status === 400);
  const cReply = await api('POST', `/v1/posts/${postId}/comments`, A.token, { content: 'QA 楼中楼回复', parentId: commentId });
  rec('A 楼中楼回复（parentId）', cReply.status === 200 && Number(data(cReply)?.parentId) === commentId);
  const cUp = await api('POST', `/v1/comments/${commentId}/up`, A.token);
  const cUpRow = await prisma.commentUp.findUnique({ where: { userId_commentId: { userId: A.id, commentId } } });
  rec('A 顶 B 评论 → DB CommentUp 落库', cUp.status === 200 && !!cUpRow);
  const cl = await api('GET', `/v1/posts/${postId}/comments`, B.token);
  const threads: any[] = data(cl)?.list ?? [];
  const mainC = threads.find((t) => Number(t.id) === commentId);
  rec('评论列表为线程结构（主楼含楼中楼回复）',
    cl.status === 200 && threads.length === 1 && (mainC?.replies ?? []).length === 1,
    `list=${threads.length}`);

  // ---- 关注 ----
  const fo = await api('POST', `/v1/users/${B.id}/follow`, A.token);
  const foRow = await prisma.follow.findUnique({
    where: { followerId_followingId: { followerId: A.id, followingId: B.id } },
  });
  rec('A 关注 B → DB Follow 落库', fo.status === 200 && !!foRow);
  const foDup = await api('POST', `/v1/users/${B.id}/follow`, A.token);
  rec('重复关注幂等（200/无新增行）',
    foDup.status === 200 && (await prisma.follow.count({ where: { followerId: A.id, followingId: B.id } })) === 1);
  const followers = await api('GET', `/v1/users/${B.id}/followers`, B.token);
  const following = await api('GET', `/v1/users/${A.id}/following`, B.token);
  rec('B 粉丝列表含 A；A 关注列表含 B',
    followers.status === 200 && following.status === 200 &&
    JSON.stringify(data(followers)).includes(`"id":${A.id}`) &&
    JSON.stringify(data(following)).includes(`"id":${B.id}`));

  // ---- 举报 ----
  const rp = await api('POST', `/v1/posts/${postId}/report`, B.token, { reason: 'spam' });
  const rpRow = await prisma.report.findFirst({ where: { reporterId: B.id, targetType: 'post', targetId: postId } });
  rec('B 举报帖子 → DB Report 落库（pending）', rp.status === 200 && !!rpRow && rpRow.status === 'pending');
  const rpDup = await api('POST', `/v1/posts/${postId}/report`, B.token, { reason: 'spam' });
  rec('重复举报 → 409 幂等拦截', rpDup.status === 409);
  const rpBad = await api('POST', `/v1/posts/${postId}/report`, B.token, { reason: '不存在的原因' });
  rec('非法举报理由 → 400', rpBad.status === 400);
  const rpUser = await api('POST', `/v1/users/${A.id}/report`, B.token, { reason: 'other', description: 'QA 用户举报' });
  rec('B 举报用户（other+描述）→ 200', rpUser.status === 200);

  // ---- 私信 ----
  const dm = await api('POST', '/v1/messages', A.token, { receiverId: B.id, content: 'QA 私信你好' });
  const dmId = Number(data(dm)?.id);
  rec('A → B 发私信', dm.status === 200 && dmId > 0);
  const dmSelf = await api('POST', '/v1/messages', A.token, { receiverId: A.id, content: '发给自己' });
  rec('边界：给自己发私信被拒（4xx）', dmSelf.status >= 400 && dmSelf.status < 500, `status=${dmSelf.status}`);
  const conv = await api('GET', '/v1/messages/conversations', B.token);
  const convList: any[] = data(conv)?.list ?? [];
  rec('B 会话列表含与 A 的会话（peer 指向 A）',
    conv.status === 200 && convList.some((c) => Number(c.peer?.id) === A.id));
  const unread = await api('GET', '/v1/messages/unread', B.token);
  rec('B 未读私信数 ≥ 1', unread.status === 200 && JSON.stringify(data(unread)).match(/[1-9]/) !== null);
  const hist = await api('GET', `/v1/messages/${A.id}`, B.token);
  rec('B 拉 A 的历史消息', hist.status === 200 && JSON.stringify(data(hist)).includes('QA 私信你好'));
  const read = await api('POST', `/v1/messages/${A.id}/read`, B.token);
  const unread2 = await api('GET', '/v1/messages/unread', B.token);
  rec('B 标记已读 → 未读清零', read.status === 200 &&
    !JSON.stringify(data(unread2)).match(/[1-9]/));
  const recall = await api('POST', `/v1/messages/${dmId}/recall`, A.token);
  const msgRow = dmId > 0 ? await prisma.message.findUnique({ where: { id: dmId } }) : null;
  rec('A 撤回私信 → DB recalledAt 置位', recall.status === 200 && !!msgRow && (msgRow as any).recalledAt !== null);

  // ---- 通知 ----
  const noti = await api('GET', '/v1/notifications', B.token);
  const notiList: any[] = data(noti)?.list ?? [];
  rec('B 收到 follow 通知（A 关注动作产生）',
    noti.status === 200 && notiList.some((n) => n.type === 'follow' && Number(n.actorId) === A.id));
  const unreadCount = await api('GET', '/v1/notifications/unread-count', B.token);
  rec('B 通知未读数 ≥ 1', unreadCount.status === 200 &&
    Number(data(unreadCount)?.count ?? data(unreadCount)?.unread ?? 0) >= 1);
  const readAll = await api('POST', '/v1/notifications/read-all', B.token);
  const unreadCount2 = await api('GET', '/v1/notifications/unread-count', B.token);
  rec('read-all → 未读数归零', readAll.status === 200 &&
    Number(data(unreadCount2)?.count ?? data(unreadCount2)?.unread ?? 0) === 0);

  // ---- 搜索 / 标签 ----
  const sh = await api('POST', '/v1/search/history', A.token, { keyword: 'QA 全链路' });
  const shRow = await prisma.searchHistory.findFirst({ where: { userId: A.id, keyword: 'QA 全链路' } });
  rec('搜索历史落库', sh.status === 200 && !!shRow);
  const ks = await api('GET', `/v1/posts?keyword=${encodeURIComponent('全链路')}`, A.token);
  rec('关键词搜帖命中', ks.status === 200 && JSON.stringify(data(ks)).includes('全链路'));
  const sg = await api('GET', '/v1/search/suggest?keyword=全链路');
  rec('搜索联想（匿名可用）', sg.status === 200);
  const tg = await api('GET', '/v1/tags', A.token);
  const firstTag: string = (data(tg)?.items ?? data(tg) ?? [])[0]?.name ?? '';
  rec('标签列表非空（种子已导入）', tg.status === 200 && firstTag.length > 0, `首个标签=${firstTag}`);
  if (firstTag.length > 0) {
    const tf = await api('POST', `/v1/tags/${encodeURIComponent(firstTag)}/follow`, A.token);
    const tfRow = await prisma.userFollowTag.findFirst({ where: { userId: A.id, tagName: firstTag } });
    rec('A 关注标签 → DB UserFollowTag 落库', tf.status === 200 && !!tfRow);
    const ft = await api('GET', '/v1/auth/me/followed-tags', A.token);
    rec('me/followed-tags 回读', ft.status === 200 && JSON.stringify(data(ft)).includes(firstTag));
  }

  // ---- 隐私 / 通知偏好 / 拉黑 / 导出 ----
  const pv1 = await api('GET', '/v1/me/privacy', A.token);
  const pv2 = await api('PUT', '/v1/me/privacy', A.token, { dmFromStrangers: false });
  const pvRow = await prisma.privacySettings.findFirst({ where: { userId: A.id } });
  rec('隐私设置 GET/PUT → DB 行存在', pv1.status === 200 && pv2.status === 200 && !!pvRow);
  const np1 = await api('GET', '/v1/me/notification-prefs', A.token);
  const np2 = await api('PUT', '/v1/me/notification-prefs', A.token, { likeEnabled: false });
  const npRow = await prisma.notificationPreference.findUnique({ where: { userId: A.id } });
  rec('通知偏好 GET/PUT → DB 行存在', np1.status === 200 && np2.status === 200 && !!npRow);
  const bl = await api('POST', `/v1/me/block/${B.id}`, A.token);
  const blRow = await prisma.blocklist.findUnique({ where: { userId_blockedId: { userId: A.id, blockedId: B.id } } });
  rec('A 拉黑 B → DB Blocklist 落库', bl.status === 200 && !!blRow);
  const blList = await api('GET', '/v1/me/blocklist', A.token);
  rec('拉黑名单回读含 B', blList.status === 200 && JSON.stringify(data(blList)).includes(`"id":${B.id}`));
  const ex = await api('GET', '/v1/me/export', A.token);
  rec('数据导出（GDPR 式）', ex.status === 200);

  // ---- 越权 / 不存在 ----
  const xPut = await api('PUT', `/v1/posts/${postId}`, B.token, { title: 'B 想改 A 的帖', genre: 'share' });
  rec('越权：B 改 A 的帖 → 403/404', xPut.status === 403 || xPut.status === 404, `status=${xPut.status}`);
  const xDel = await api('DELETE', `/v1/posts/${postId}`, B.token);
  rec('越权：B 删 A 的帖 → 403/404', xDel.status === 403 || xDel.status === 404, `status=${xDel.status}`);
  const x404 = await api('GET', '/v1/posts/99999999', B.token);
  rec('边界：不存在帖子 → 404', x404.status === 404);
  const c404 = await api('POST', '/v1/posts/99999999/comments', B.token, { content: 'x' });
  rec('边界：评论不存在帖子 → 404', c404.status === 404);
  const dm404 = await api('POST', '/v1/messages', A.token, { receiverId: 99999999, content: 'x' });
  rec('边界：私信不存在用户 → 4xx', dm404.status >= 400 && dm404.status < 500, `status=${dm404.status}`);

  // ---- 收尾（还原可见状态）----
  await api('DELETE', `/v1/me/block/${B.id}`, A.token);
  await api('DELETE', `/v1/users/${B.id}/follow`, A.token);

  fs.writeFileSync(CTX_FILE, JSON.stringify({ aId: A.id, aToken: A.token, openIdA, postId }));
}

async function adminPhase(): Promise<void> {
  const ctx = JSON.parse(fs.readFileSync(CTX_FILE, 'utf8'));
  const la = await api('POST', '/v1/auth/login', undefined, { openId: ctx.openIdA, nickname: 'QA甲' });
  A = { id: Number(data(la)?.user?.id), token: String(data(la)?.token) };
  const lb = await api('POST', '/v1/auth/login', undefined, { openId: `${ctx.openIdA}-b2`, nickname: 'QA丙' });
  B = { id: Number(data(lb)?.user?.id), token: String(data(lb)?.token) };

  const me = await api('GET', '/v1/auth/me', A.token);
  rec('A 的 login/me 响应带 isAdmin=true（ADMIN_USER_IDS 生效）', data(me)?.isAdmin === true);

  const pendingA = await api('GET', '/v1/admin/posts/pending', A.token);
  rec('管理员拉待审核列表 → 200', pendingA.status === 200);
  const reportsA = await api('GET', '/v1/admin/reports', A.token);
  rec('管理员拉举报列表 → 200', reportsA.status === 200);
  const pendingB = await api('GET', '/v1/admin/posts/pending', B.token);
  rec('普通用户拉管理列表 → 403', pendingB.status === 403);
  const banB = await api('POST', `/v1/admin/users/${B.id}/ban`, A.token, {});
  rec('管理员封禁普通用户 → 200', banB.status === 200);
  const bMe = await api('GET', '/v1/auth/me', B.token);
  rec('被封用户访问 → 401/403（token 失效）', bMe.status === 401 || bMe.status === 403);
  const unbanB = await api('POST', `/v1/admin/users/${B.id}/unban`, A.token, {});
  rec('管理员解封 → 200', unbanB.status === 200);
  const bMe2 = await api('GET', '/v1/auth/me', B.token);
  rec('解封后恢复访问 → 200', bMe2.status === 200);
}

let A = { id: 0, token: '' };
let B = { id: 0, token: '' };
const fs = await import('node:fs');

const mode: string = process.argv[2] ?? 'main';
if (mode === 'admin') {
  await adminPhase();
} else {
  await mainPhase();
}
const failed = results.filter((r) => !r.pass);
console.log(`\n==== ${mode.toUpperCase()} 阶段：${results.length - failed.length}/${results.length} 通过 ====`);
for (const f of failed) {
  console.log(`FAIL -> ${f.name}${f.detail ? ' | ' + f.detail : ''}`);
}
await prisma.$disconnect();
process.exit(failed.length === 0 ? 0 : 1);
